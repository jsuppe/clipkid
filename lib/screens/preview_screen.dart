import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/choreography.dart';
import '../rendering/scene_renderer.dart';
import '../services/export_service.dart';
import 'editor_screen.dart';

/// Full-screen preview of a completed capture. Shows the choreography
/// rendered via [SceneRenderer] with 3 actions: Redo, Polish, Share.
class PreviewScreen extends StatefulWidget {
  final Choreography choreography;
  const PreviewScreen({super.key, required this.choreography});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final GlobalKey<SceneRendererState> _rendererKey = GlobalKey();
  int _positionMs = 0;
  bool _isExporting = false;
  double _exportProgress = 0.0;
  String _exportStatus = '';

  @override
  void initState() {
    super.initState();
    // Auto-play on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rendererKey.currentState?.togglePlayPause();
    });
  }

  void _onPositionChanged(int ms) {
    if (mounted) setState(() => _positionMs = ms);
  }

  void _redo() {
    Navigator.pop(context); // back to capture
  }

  void _polish() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(initialChoreography: widget.choreography),
      ),
    );
  }

  void _share() async {
    // One-tap export with default settings, then share sheet.
    await _rendererKey.currentState?.pause();
    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
      _exportStatus = 'Exporting...';
    });

    try {
      final outputPath = await ExportService.exportToMp4(
        widget.choreography,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _exportProgress = progress;
              _exportStatus = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() => _isExporting = false);
        if (outputPath != null) {
          await Share.shareXFiles([XFile(outputPath)]);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.choreography.totalDurationMs;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          GestureDetector(
            onTap: () {
              _rendererKey.currentState?.togglePlayPause();
              setState(() {});
            },
            child: SceneRenderer(
              key: _rendererKey,
              choreography: widget.choreography,
              onPositionChanged: _onPositionChanged,
              readOnly: true,
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _circleButton(Icons.close, () => Navigator.pop(context)),
                    const Spacer(),
                    // Progress
                    Text(
                      '${_formatMs(_positionMs)} / ${_formatMs(total)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Progress bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 100,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: total > 0 ? _positionMs / total : 0,
                  minHeight: 4,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
          ),

          // Export overlay
          if (_isExporting)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(value: _exportProgress > 0 ? _exportProgress : null, color: Colors.white),
                    const SizedBox(height: 16),
                    Text(_exportStatus, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
            ),

          // Bottom bar
          if (!_isExporting)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _actionButton(Icons.refresh, 'Redo', Colors.grey[800]!, _redo),
                    _actionButton(Icons.edit, 'Polish', Colors.deepPurple, _polish),
                    _actionButton(Icons.share, 'Share', Colors.blue, _share),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String _formatMs(int ms) {
    final s = (ms / 1000).floor();
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m}:${sec.toString().padLeft(2, '0')}';
  }
}
