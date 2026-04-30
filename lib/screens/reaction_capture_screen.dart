import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import '../models/choreography.dart';
import 'preview_screen.dart';

/// Reaction mode: plays an existing video while recording the user's reaction
/// via camera. Produces a PiP composite — the original video plays full-screen
/// with the reaction in a small corner overlay.
class ReactionCaptureScreen extends StatefulWidget {
  final String sourceVideoPath;
  final String? sourceVideoName;
  const ReactionCaptureScreen({super.key, required this.sourceVideoPath, this.sourceVideoName});

  @override
  State<ReactionCaptureScreen> createState() => _ReactionCaptureScreenState();
}

enum _Phase { loading, ready, recording, finishing }

class _ReactionCaptureScreenState extends State<ReactionCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  VideoPlayerController? _videoController;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  _Phase _phase = _Phase.loading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    // Init video player for source
    final vp = VideoPlayerController.file(File(widget.sourceVideoPath));
    await vp.initialize();
    _videoController = vp;

    // Init camera (front-facing for reactions)
    _cameras = await availableCameras();
    _cameraIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
    if (_cameraIndex < 0) _cameraIndex = 0;

    if (_cameras.isNotEmpty) {
      final cam = CameraController(_cameras[_cameraIndex], ResolutionPreset.medium, enableAudio: true);
      await cam.initialize();
      _cameraController = cam;
    }

    if (mounted) setState(() => _phase = _Phase.ready);
  }

  Future<void> _startRecording() async {
    final cam = _cameraController;
    final vp = _videoController;
    if (cam == null || vp == null) return;

    try {
      await cam.startVideoRecording();
      await vp.seekTo(Duration.zero);
      await vp.play();
      setState(() => _phase = _Phase.recording);

      // Auto-stop when source video ends
      vp.addListener(_checkVideoEnd);
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.ready);
    }
  }

  void _checkVideoEnd() {
    final vp = _videoController;
    if (vp == null) return;
    if (vp.value.position >= vp.value.duration) {
      vp.removeListener(_checkVideoEnd);
      _stopRecording();
    }
  }

  Future<void> _stopRecording() async {
    final cam = _cameraController;
    final vp = _videoController;
    if (cam == null || !cam.value.isRecordingVideo) return;

    await vp?.pause();
    final file = await cam.stopVideoRecording();

    setState(() => _phase = _Phase.finishing);

    // Create a choreography with the source video + reaction as PiP
    const uuid = Uuid();
    final sourceDurationMs = _videoController!.value.duration.inMilliseconds;
    final clip = Clip(
      id: uuid.v4(),
      path: widget.sourceVideoPath,
      startMs: 0,
      sourceDurationMs: sourceDurationMs,
      name: widget.sourceVideoName ?? 'Reaction',
      effects: ClipEffects(
        pipPath: file.path,
        pipPosition: PipPosition.bottomRight,
      ),
    );

    final choreo = Choreography(
      clips: [clip],
      name: 'Reaction: ${widget.sourceVideoName ?? "Video"}',
    );

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PreviewScreen(choreography: choreo)),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Source video (full screen)
          if (_videoController?.value.isInitialized == true)
            Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            ),
          // Camera preview (PiP corner)
          if (_cameraController?.value.isInitialized == true)
            Positioned(
              bottom: 120,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 120,
                  height: 160,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _phase == _Phase.recording ? '🔴 Recording reaction...' : '🎬 Reaction Mode',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildControls(),
              ),
            ),
          ),
          if (_phase == _Phase.finishing || _phase == _Phase.loading)
            const ColoredBox(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    if (_phase == _Phase.recording) {
      return Center(
        child: GestureDetector(
          onTap: _stopRecording,
          child: Container(
            width: 78,
            height: 78,
            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
            child: const Icon(Icons.stop, color: Colors.white, size: 40),
          ),
        ),
      );
    }
    if (_phase == _Phase.ready) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Press record — video plays while you react',
            style: TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: _startRecording,
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.redAccent, width: 5),
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return const SizedBox();
  }
}
