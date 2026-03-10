import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/choreography.dart';

/// Preview player that renders the choreography
class VideoPreview extends StatefulWidget {
  final Choreography choreography;
  final ValueChanged<int>? onPositionChanged;
  final int? seekToMs;

  const VideoPreview({
    super.key,
    required this.choreography,
    this.onPositionChanged,
    this.seekToMs,
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
  
  /// Whether the current clip is playing the stabilized version
  bool get isPlayingStabilized {
    if (_currentClipIndex < 0 || 
        _currentClipIndex >= widget.choreography.clips.length) {
      return false;
    }
    final clip = widget.choreography.clips[_currentClipIndex];
    return clip.effects.stabilize && clip.processedPath != null;
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
              child: VideoPlayer(_controller!),
            ),
          ),
          // Stabilized indicator
          if (isPlayingStabilized)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
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
            ),
        ],
      ),
    );
  }
}
