import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models/choreography.dart';
import '../models/template.dart';
import '../services/capture_audio.dart';
import 'preview_screen.dart';

/// Guided capture flow: walks the kid through each template slot, showing
/// the slot's prompt and recording a clip capped at [TemplateSlot.maxSeconds].
/// When the last slot is captured, instantiates a [Choreography] from the
/// template and pops it to the caller.
class CaptureTemplateScreen extends StatefulWidget {
  final Template template;
  const CaptureTemplateScreen({super.key, required this.template});

  @override
  State<CaptureTemplateScreen> createState() => _CaptureTemplateScreenState();
}

enum _Phase { loading, ready, counting, recording, reviewing, finishing, noCamera }

class _CaptureTemplateScreenState extends State<CaptureTemplateScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  int _cameraIndex = 0;

  int _slotIndex = 0;
  final List<String> _recordedPaths = [];
  final List<int> _recordedDurationsMs = [];

  _Phase _phase = _Phase.loading;
  int _countdown = 0; // 3..2..1
  int _elapsedMs = 0; // during recording
  Timer? _countdownTimer;
  Timer? _recordTimer;
  String? _lastRecordedPath;
  VideoPlayerController? _reviewController;

  TemplateSlot get _slot => widget.template.slots[_slotIndex];
  int get _maxMs => _slot.maxSeconds * 1000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Lock to portrait during capture to prevent warped preview
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
      // Prefer back camera
      _cameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_cameraIndex < 0) _cameraIndex = 0;
      await _initController(_cameras[_cameraIndex]);
    } catch (e) {
      if (mounted) setState(() => _phase = _Phase.noCamera);
    }
  }

  Future<void> _initController(CameraDescription cam) async {
    final c = CameraController(
      cam,
      ResolutionPreset.high,
      enableAudio: true,
    );
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
        t.cancel();
        CaptureAudio.go();
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
        await _stopRecording(auto: true);
      } else {
        setState(() => _elapsedMs = next);
      }
    });
  }

  Future<void> _stopRecording({bool auto = false}) async {
    _recordTimer?.cancel();
    final c = _controller;
    if (c == null || !c.value.isRecordingVideo) return;
    CaptureAudio.done();
    try {
      final file = await c.stopVideoRecording();
      _lastRecordedPath = file.path;
      await _prepareReview(file.path);
    } catch (e) {
      // Recording failed — reset to ready so user can try again
      if (mounted) setState(() => _phase = _Phase.ready);
    }
  }

  Future<void> _prepareReview(String path) async {
    // Small delay to let the file finish writing to disk
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
      // Preview failed but clip was recorded — go to review without playback
      if (mounted) {
        setState(() {
          _phase = _Phase.reviewing;
        });
      }
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
    if (mounted) {
      setState(() {
        _phase = _Phase.ready;
        _elapsedMs = 0;
      });
    }
  }

  Future<void> _acceptAndAdvance() async {
    if (_lastRecordedPath == null) return;
    _recordedPaths.add(_lastRecordedPath!);
    _recordedDurationsMs.add(_elapsedMs > 0 ? _elapsedMs : _maxMs);
    await _reviewController?.pause();
    await _reviewController?.dispose();
    _reviewController = null;
    _lastRecordedPath = null;

    if (_slotIndex + 1 >= widget.template.slots.length) {
      // Done — instantiate and push to preview.
      setState(() => _phase = _Phase.finishing);
      final choreo = widget.template.instantiate(
        clipPaths: _recordedPaths,
        clipDurationsMs: _recordedDurationsMs,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PreviewScreen(choreography: choreo)),
      );
      // When returning from preview, go back to home.
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        setState(() {
          _slotIndex++;
          _phase = _Phase.ready;
          _elapsedMs = 0;
        });
      }
    }
  }

  @override
  void dispose() {
    // Restore orientation
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
                  backgroundColor: widget.template.accentColor,
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
    final total = widget.template.slots.length;
    final accent = widget.template.accentColor;
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
                          Text(
                            '${widget.template.emoji} ',
                            style: const TextStyle(fontSize: 18),
                          ),
                          Text(
                            'Shot ${_slotIndex + 1} / $total',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'max ${_slot.maxSeconds}s',
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
              // Duck prompt bubble
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.9),
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
                            _slot.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _slot.hint,
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
            _pillButton(
              label: 'Retake',
              icon: Icons.refresh,
              color: Colors.grey[800]!,
              onTap: _retake,
            ),
            _pillButton(
              label: _slotIndex + 1 >= widget.template.slots.length
                  ? 'Make video 🎬'
                  : 'Next →',
              icon: Icons.check,
              color: widget.template.accentColor,
              onTap: _acceptAndAdvance,
            ),
          ],
        );
      case _Phase.recording:
        final remainingMs = (_maxMs - _elapsedMs).clamp(0, _maxMs);
        final progress = _elapsedMs / _maxMs;
        return Column(
          children: [
            // Progress bar
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
            Text(
              '${(remainingMs / 1000).ceil()}s left',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _stopRecording(auto: false),
              child: Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stop, color: Colors.white, size: 40),
              ),
            ),
          ],
        );
      case _Phase.ready:
        return Center(
          child: GestureDetector(
            onTap: _startCountdown,
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: widget.template.accentColor, width: 5),
              ),
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
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
        style: const TextStyle(
          fontSize: 180,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _circleButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: onTap == null ? Colors.white38 : Colors.white,
          size: 22,
        ),
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
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
