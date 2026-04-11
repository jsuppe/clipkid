import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui show Clip;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/choreography.dart';
import 'text_overlay_style.dart';

/// Preview player that renders the choreography
class VideoPreview extends StatefulWidget {
  final Choreography choreography;
  final ValueChanged<int>? onPositionChanged;
  final int? seekToMs;
  // Called when an overlay on the current clip is moved, resized, or deleted.
  // Parent updates the choreography and passes it back in.
  final void Function(int clipIndex, ClipEffects newEffects)? onClipEffectsChanged;

  const VideoPreview({
    super.key,
    required this.choreography,
    this.onPositionChanged,
    this.seekToMs,
    this.onClipEffectsChanged,
  });

  @override
  State<VideoPreview> createState() => VideoPreviewState();
}

class VideoPreviewState extends State<VideoPreview> {
  VideoPlayerController? _controller;
  int _currentClipIndex = -1;
  int _globalPositionMs = 0;
  Timer? _positionTimer;
  bool _isPlaying = false;
  int? _selectedOverlayIndex; // which text overlay on the current clip is selected

  @override
  void initState() {
    super.initState();
    if (widget.choreography.clips.isNotEmpty) {
      _loadClip(0);
    }
  }

  @override
  void didUpdateWidget(VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle external seek
    if (widget.seekToMs != null && widget.seekToMs != oldWidget.seekToMs) {
      seekTo(widget.seekToMs!);
    }
    
    // Handle choreography changes
    if (widget.choreography.clips.length != oldWidget.choreography.clips.length) {
      if (widget.choreography.clips.isNotEmpty && _currentClipIndex < 0) {
        _loadClip(0);
      }
    }
    
    // Reload current clip if its playback path changed (e.g., after processing)
    if (_currentClipIndex >= 0 && 
        _currentClipIndex < widget.choreography.clips.length &&
        _currentClipIndex < oldWidget.choreography.clips.length) {
      final newPath = widget.choreography.clips[_currentClipIndex].playbackPath;
      final oldPath = oldWidget.choreography.clips[_currentClipIndex].playbackPath;
      if (newPath != oldPath) {
        _loadClip(_currentClipIndex);
      }
    }
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadClip(int index) async {
    if (index < 0 || index >= widget.choreography.clips.length) return;

    final clip = widget.choreography.clips[index];
    final oldController = _controller;

    final newController = VideoPlayerController.file(File(clip.playbackPath));
    await newController.initialize();

    newController.addListener(_onVideoProgress);

    if (mounted) {
      setState(() {
        _controller = newController;
        _currentClipIndex = index;
      });

      if (_isPlaying) {
        await newController.play();
      }
    }

    await oldController?.dispose();
  }

  void _onVideoProgress() {
    if (_controller == null || !mounted) return;

    final clip = widget.choreography.clips[_currentClipIndex];
    final localPositionMs = _controller!.value.position.inMilliseconds;
    final newGlobalPosition = clip.startMs + localPositionMs;

    if (newGlobalPosition != _globalPositionMs) {
      _globalPositionMs = newGlobalPosition;
      widget.onPositionChanged?.call(_globalPositionMs);
    }

    // Check if clip ended and move to next
    if (_controller!.value.position >= _controller!.value.duration) {
      if (_currentClipIndex < widget.choreography.clips.length - 1) {
        _loadClip(_currentClipIndex + 1);
      } else {
        // End of choreography
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  /// Seek to a global position in the choreography
  Future<void> seekTo(int globalMs) async {
    // Find which clip contains this position
    for (int i = 0; i < widget.choreography.clips.length; i++) {
      final clip = widget.choreography.clips[i];
      if (globalMs >= clip.startMs && globalMs < clip.endMs) {
        if (i != _currentClipIndex) {
          await _loadClip(i);
        }
        final localMs = globalMs - clip.startMs;
        await _controller?.seekTo(Duration(milliseconds: localMs));
        _globalPositionMs = globalMs;
        widget.onPositionChanged?.call(_globalPositionMs);
        return;
      }
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_controller == null) return;

    if (_isPlaying) {
      await _controller!.pause();
    } else {
      // If at end, restart from beginning
      if (_currentClipIndex == widget.choreography.clips.length - 1 &&
          _controller!.value.position >= _controller!.value.duration) {
        await seekTo(0);
      }
      await _controller!.play();
    }

    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  bool get isPlaying => _isPlaying;

  /// Pause playback
  Future<void> pause() async {
    if (_controller != null && _isPlaying) {
      await _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
    }
  }
  
  /// Whether the current clip is playing the stabilized version
  bool get isPlayingStabilized {
    if (_currentClipIndex < 0 || 
        _currentClipIndex >= widget.choreography.clips.length) {
      return false;
    }
    final clip = widget.choreography.clips[_currentClipIndex];
    return clip.effects.stabilize && clip.processedPath != null;
  }

  /// Whether the current clip is playing the styled version
  bool get isPlayingStyled {
    if (_currentClipIndex < 0 || 
        _currentClipIndex >= widget.choreography.clips.length) {
      return false;
    }
    final clip = widget.choreography.clips[_currentClipIndex];
    return clip.effects.styled && clip.processedPath != null;
  }

  /// Get the style name if styled
  String? get currentStyleName {
    if (_currentClipIndex < 0 || 
        _currentClipIndex >= widget.choreography.clips.length) {
      return null;
    }
    return widget.choreography.clips[_currentClipIndex].effects.styleName;
  }

  /// Whether a given text overlay should be visible at [_globalPositionMs]
  /// based on its timing rule.
  bool _isOverlayVisible(TextOverlay overlay, Clip clip) {
    final clipStart = clip.startMs;
    final clipEnd = clipStart + clip.durationMs;
    final position = _globalPositionMs;
    if (position < clipStart || position > clipEnd) return false;
    final positionInClip = position - clipStart;
    switch (overlay.timing) {
      case OverlayTiming.wholeClip:
        return true;
      case OverlayTiming.firstTwoSeconds:
        return positionInClip <= 2000;
      case OverlayTiming.lastTwoSeconds:
        return positionInClip >= clip.durationMs - 2000;
    }
  }

  Widget _buildOverlayLayer(Clip clip) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          // Tap empty area to deselect
          behavior: HitTestBehavior.translucent,
          onTap: () => setState(() => _selectedOverlayIndex = null),
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (var i = 0; i < clip.effects.textOverlays.length; i++)
                if (_isOverlayVisible(clip.effects.textOverlays[i], clip))
                  _buildDraggableOverlay(
                    clip: clip,
                    overlayIndex: i,
                    videoSize: constraints.biggest,
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraggableOverlay({
    required Clip clip,
    required int overlayIndex,
    required Size videoSize,
  }) {
    final overlay = clip.effects.textOverlays[overlayIndex];
    final selected = _selectedOverlayIndex == overlayIndex;
    // Base font size scales with video width for consistency across aspect ratios.
    final baseFontSize = (videoSize.width / 12).clamp(14.0, 60.0) * overlay.scale;

    return Positioned(
      left: overlay.x * videoSize.width,
      top: overlay.y * videoSize.height,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _selectedOverlayIndex = overlayIndex),
          onPanUpdate: (details) {
            if (widget.onClipEffectsChanged == null) return;
            final newX = (overlay.x + details.delta.dx / videoSize.width).clamp(0.05, 0.95);
            final newY = (overlay.y + details.delta.dy / videoSize.height).clamp(0.05, 0.95);
            final newOverlays = List<TextOverlay>.from(clip.effects.textOverlays);
            newOverlays[overlayIndex] = overlay.copyWith(x: newX, y: newY);
            widget.onClipEffectsChanged!(
              _currentClipIndex,
              clip.effects.copyWith(textOverlays: newOverlays),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: selected
                ? BoxDecoration(
                    border: Border.all(color: Colors.yellow, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
            child: Stack(
              clipBehavior: ui.Clip.none,
              children: [
                StyledOverlayText(
                  text: overlay.text,
                  style: overlay.style,
                  baseFontSize: baseFontSize,
                ),
                if (selected)
                  Positioned(
                    top: -10,
                    right: -10,
                    child: GestureDetector(
                      onTap: () {
                        if (widget.onClipEffectsChanged == null) return;
                        final newOverlays = List<TextOverlay>.from(clip.effects.textOverlays)
                          ..removeAt(overlayIndex);
                        widget.onClipEffectsChanged!(
                          _currentClipIndex,
                          clip.effects.copyWith(textOverlays: newOverlays),
                        );
                        setState(() => _selectedOverlayIndex = null);
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Add videos to preview',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoPlayer(_controller!),
                  // Text overlay layer for the current clip
                  if (_currentClipIndex >= 0 &&
                      _currentClipIndex < widget.choreography.clips.length)
                    _buildOverlayLayer(
                      widget.choreography.clips[_currentClipIndex],
                    ),
                ],
              ),
            ),
          ),
          // Effect badges
          Positioned(
            top: 8,
            left: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Styled indicator
                if (isPlayingStyled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.palette, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          currentStyleName ?? 'Styled',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Stabilized indicator
                if (isPlayingStabilized)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_fix_high, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Stabilized',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
