import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import '../models/choreography.dart';
import '../models/duck_mission.dart';
import '../services/capture_audio.dart';
import 'preview_screen.dart';

/// Freeform capture driven by a [DuckMission]. Unlike the template capture,
/// there are no fixed slots — the kid records as many clips as they want
/// and taps "Done" when finished. The duck's mission prompt stays on
/// screen throughout.
class MissionCaptureScreen extends StatefulWidget {
  final DuckMission mission;
  const MissionCaptureScreen({super.key, required this.mission});

  @override
  State<MissionCaptureScreen> createState() => _MissionCaptureScreenState();
}

enum _Phase { loading, ready, counting, recording, reviewing, finishing, noCamera }

class _MissionCaptureScreenState extends State<MissionCaptureScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  int _cameraIndex = 0;

  final List<String> _recordedPaths = [];
  final List<int> _recordedDurationsMs = [];

  _Phase _phase = _Phase.loading;
  int _countdown = 0;
  int _elapsedMs = 0;
  Timer? _countdownTimer;
  Timer? _recordTimer;
  String? _lastRecordedPath;
  VideoPlayerController? _reviewController;

  int get _maxMs => widget.mission.maxSecondsPerClip * 1000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initCameras();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initController(_cameras[_cameraIndex]);
    }
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _phase = _Phase.noCamera);
        return;
      }
      _cameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_cameraIndex < 0) _cameraIndex = 0;
      await _initController(_cameras[_cameraIndex]);
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.noCamera);
    }
  }

  Future<void> _initController(CameraDescription cam) async {
    final c = CameraController(cam, ResolutionPreset.high, enableAudio: true);
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _phase = _Phase.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.noCamera);
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _phase != _Phase.ready) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _controller?.dispose();
    setState(() => _controller = null);
    await _initController(_cameras[_cameraIndex]);
  }

  void _startCountdown() {
    if (_phase != _Phase.ready || _controller == null) return;
    setState(() {
      _phase = _Phase.counting;
      _countdown = 3;
    });
    CaptureAudio.beep();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown <= 1) {
        CaptureAudio.go();
        t.cancel();
        await _startRecording();
      } else {
        setState(() => _countdown--);
        CaptureAudio.beep();
      }
    });
  }

  Future<void> _startRecording() async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.startVideoRecording();
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.ready);
      return;
    }
    setState(() {
      _phase = _Phase.recording;
      _elapsedMs = 0;
    });
    const tick = Duration(milliseconds: 100);
    _recordTimer = Timer.periodic(tick, (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = _elapsedMs + tick.inMilliseconds;
      if (next >= _maxMs) {
        t.cancel();
        await _stopRecording();
      } else {
        setState(() => _elapsedMs = next);
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final c = _controller;
    if (c == null || !c.value.isRecordingVideo) return;
    CaptureAudio.done();
    try {
      final file = await c.stopVideoRecording();
      _lastRecordedPath = file.path;
      await _prepareReview(file.path);
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.ready);
    }
  }

  Future<void> _prepareReview(String path) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      final vp = VideoPlayerController.file(File(path));
      await vp.initialize();
      await vp.setLooping(true);
      await vp.play();
      if (!mounted) {
        await vp.dispose();
        return;
      }
      setState(() {
        _reviewController = vp;
        _phase = _Phase.reviewing;
      });
    } catch (_) {
      // Preview failed but clip exists — show review without playback
      if (mounted) setState(() => _phase = _Phase.reviewing);
    }
  }

  Future<void> _retake() async {
    await _reviewController?.pause();
    await _reviewController?.dispose();
    _reviewController = null;
    if (_lastRecordedPath != null) {
      try {
        await File(_lastRecordedPath!).delete();
      } catch (_) {}
    }
    _lastRecordedPath = null;
    if (mounted) setState(() {
      _phase = _Phase.ready;
      _elapsedMs = 0;
    });
  }

  Future<void> _keepClip() async {
    if (_lastRecordedPath == null) return;
    _recordedPaths.add(_lastRecordedPath!);
    _recordedDurationsMs.add(_elapsedMs > 0 ? _elapsedMs : _maxMs);
    await _reviewController?.pause();
    await _reviewController?.dispose();
    _reviewController = null;
    _lastRecordedPath = null;
    if (mounted) setState(() {
      _phase = _Phase.ready;
      _elapsedMs = 0;
    });
  }

  Future<void> _finish() async {
    if (_recordedPaths.isEmpty) return;
    setState(() => _phase = _Phase.finishing);

    const uuid = Uuid();
    final clips = <Clip>[];
    int timelineStart = 0;
    for (int i = 0; i < _recordedPaths.length; i++) {
      final dur = _recordedDurationsMs[i];
      clips.add(Clip(
        id: uuid.v4(),
        path: _recordedPaths[i],
        startMs: timelineStart,
        sourceDurationMs: dur,
        name: 'Clip ${i + 1}',
        outgoingTransition: i < _recordedPaths.length - 1
            ? const Transition(type: TransitionType.fade, durationMs: 400)
            : const Transition(),
      ));
      timelineStart += dur;
    }

    final choreo = Choreography(
      clips: clips,
      name: '${widget.mission.emoji} ${widget.mission.title}',
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
    SystemChrome.setPreferredOrientations([]);
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _recordTimer?.cancel();
    _controller?.dispose();
    _reviewController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          _buildTopBar(),
          _buildBottomBar(),
          if (_phase == _Phase.counting) _buildCountdownOverlay(),
          if (_phase == _Phase.finishing)
            const ColoredBox(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    if (_phase == _Phase.noCamera) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🦆', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'Duck needs your camera!',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Open your phone\'s Settings, find ClipKid, and turn on Camera and Microphone permissions.',
                style: TextStyle(color: Colors.white70, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initCameras,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_phase == _Phase.reviewing && _reviewController != null) {
      final vp = _reviewController!;
      return Center(
        child: AspectRatio(
          aspectRatio: vp.value.aspectRatio,
          child: VideoPlayer(vp),
        ),
      );
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio,
        child: CameraPreview(c),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _circleButton(
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(widget.mission.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(
                            '${_recordedPaths.length} clips',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            'max ${widget.mission.maxSecondsPerClip}s each',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _circleButton(
                    icon: Icons.cameraswitch,
                    onTap: _cameras.length >= 2 ? _flipCamera : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Duck mission bubble
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🦆', style: TextStyle(fontSize: 30)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.mission.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.mission.prompt,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildBottomControls(),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    switch (_phase) {
      case _Phase.reviewing:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _pillButton(label: 'Retake', icon: Icons.refresh, color: Colors.grey[800]!, onTap: _retake),
            _pillButton(label: 'Keep', icon: Icons.check, color: Colors.orange, onTap: _keepClip),
          ],
        );
      case _Phase.recording:
        final remainingMs = (_maxMs - _elapsedMs).clamp(0, _maxMs);
        final progress = _elapsedMs / _maxMs;
        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.redAccent),
              ),
            ),
            const SizedBox(height: 10),
            Text('${(remainingMs / 1000).ceil()}s left', style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                child: const Icon(Icons.stop, color: Colors.white, size: 40),
              ),
            ),
          ],
        );
      case _Phase.ready:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Done button (only if at least 1 clip)
            if (_recordedPaths.isNotEmpty)
              _pillButton(
                label: 'Done (${_recordedPaths.length})',
                icon: Icons.movie,
                color: Colors.green,
                onTap: _finish,
              ),
            // Record button
            GestureDetector(
              onTap: _startCountdown,
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.orange, width: 5),
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
            // Spacer to keep record centered when Done is showing
            if (_recordedPaths.isNotEmpty)
              const SizedBox(width: 100),
          ],
        );
      case _Phase.loading:
      case _Phase.counting:
      case _Phase.finishing:
      case _Phase.noCamera:
        return const SizedBox(height: 86);
    }
  }

  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Text(
        '$_countdown',
        style: const TextStyle(fontSize: 180, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _circleButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: Icon(icon, color: onTap == null ? Colors.white38 : Colors.white, size: 22),
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
