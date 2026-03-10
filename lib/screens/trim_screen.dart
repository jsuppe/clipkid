import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/choreography.dart';

/// Screen for trimming a single clip with multi-segment support
class TrimScreen extends StatefulWidget {
  final Clip clip;

  const TrimScreen({super.key, required this.clip});

  @override
  State<TrimScreen> createState() => _TrimScreenState();
}

class _TrimScreenState extends State<TrimScreen> {
  late VideoPlayerController _controller;
  late List<ClipTrim> _segments;
  int? _markingStartMs; // When user is marking a new segment
  bool _isPlaying = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize with existing segments or create one from trim
    if (widget.clip.segments.isNotEmpty) {
      _segments = List.from(widget.clip.segments);
    } else {
      _segments = [widget.clip.trim];
    }
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(File(widget.clip.path));
    await _controller.initialize();
    _controller.addListener(_onVideoProgress);
    setState(() {
      _initialized = true;
    });
  }

  void _onVideoProgress() {
    if (!mounted) return;
    
    // Skip non-kept sections during playback
    if (_isPlaying && _segments.isNotEmpty) {
      final currentMs = _controller.value.position.inMilliseconds;
      
      // Check if we're in a kept segment
      bool inKeptSegment = false;
      ClipTrim? currentSegment;
      for (final segment in _segments) {
        if (currentMs >= segment.inPointMs && currentMs < segment.outPointMs) {
          inKeptSegment = true;
          currentSegment = segment;
          break;
        }
      }
      
      if (!inKeptSegment) {
        // Find the next segment to jump to
        final sortedSegments = List<ClipTrim>.from(_segments)
          ..sort((a, b) => a.inPointMs.compareTo(b.inPointMs));
        
        ClipTrim? nextSegment;
        for (final segment in sortedSegments) {
          if (segment.inPointMs > currentMs) {
            nextSegment = segment;
            break;
          }
        }
        
        if (nextSegment != null) {
          // Jump to next segment
          _controller.seekTo(Duration(milliseconds: nextSegment.inPointMs));
        } else {
          // No more segments - loop to first segment
          _controller.seekTo(Duration(milliseconds: sortedSegments.first.inPointMs));
        }
      } else if (currentSegment != null && currentMs >= currentSegment.outPointMs - 50) {
        // Near end of current segment - preemptively check for next
        final sortedSegments = List<ClipTrim>.from(_segments)
          ..sort((a, b) => a.inPointMs.compareTo(b.inPointMs));
        
        final currentIndex = sortedSegments.indexOf(currentSegment);
        if (currentIndex < sortedSegments.length - 1) {
          // Jump to next segment
          _controller.seekTo(Duration(milliseconds: sortedSegments[currentIndex + 1].inPointMs));
        } else {
          // Loop to first segment
          _controller.seekTo(Duration(milliseconds: sortedSegments.first.inPointMs));
        }
      }
    }
    
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _controller.pause();
    } else {
      // Start from first segment if not in any segment
      if (_segments.isNotEmpty) {
        final currentMs = _controller.value.position.inMilliseconds;
        bool inKeptSegment = _segments.any(
          (s) => currentMs >= s.inPointMs && currentMs < s.outPointMs
        );
        if (!inKeptSegment) {
          final sortedSegments = List<ClipTrim>.from(_segments)
            ..sort((a, b) => a.inPointMs.compareTo(b.inPointMs));
          _controller.seekTo(Duration(milliseconds: sortedSegments.first.inPointMs));
        }
      }
      _controller.play();
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _markStart() {
    final currentMs = _controller.value.position.inMilliseconds;
    setState(() {
      _markingStartMs = currentMs;
    });
  }

  void _markEnd() {
    if (_markingStartMs == null) {
      return; // Can't mark end without start
    }

    final currentMs = _controller.value.position.inMilliseconds;
    final startMs = _markingStartMs!;
    
    if (currentMs <= startMs + 200) {
      return; // End must be after start
    }

    // Create new segment
    final newSegment = ClipTrim(
      inPointMs: startMs,
      outPointMs: currentMs,
    );

    setState(() {
      _segments.add(newSegment);
      _segments.sort((a, b) => a.inPointMs.compareTo(b.inPointMs));
      _markingStartMs = null;
    });
  }

  void _deleteSegment(int index) {
    if (_segments.length <= 1) {
      return; // Need at least one segment
    }

    setState(() {
      _segments.removeAt(index);
    });
  }

  void _clearAndStartFresh() {
    setState(() {
      _segments = [ClipTrim(inPointMs: 0, outPointMs: widget.clip.sourceDurationMs)];
      _markingStartMs = null;
    });
  }

  void _save() {
    // Sort segments by start time and return
    final sortedSegments = List<ClipTrim>.from(_segments)
      ..sort((a, b) => a.inPointMs.compareTo(b.inPointMs));
    Navigator.pop(context, sortedSegments);
  }

  String _formatTime(int ms) {
    final seconds = (ms / 1000).floor();
    final minutes = (seconds / 60).floor();
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  int get _totalKeptMs => _segments.fold(0, (sum, s) => sum + s.durationMs);
  int get _totalDiscardedMs => widget.clip.sourceDurationMs - _totalKeptMs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('Select Parts to Keep'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Done', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Video preview
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),

                // Stats bar
                Container(
                  color: Colors.grey[900],
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_segments.length} segment${_segments.length == 1 ? '' : 's'}',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      Row(
                        children: [
                          Text(
                            'Keep: ${_formatTime(_totalKeptMs)}',
                            style: TextStyle(color: Colors.green[400]),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Cut: ${_formatTime(_totalDiscardedMs)}',
                            style: TextStyle(color: Colors.red[400]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Timeline scrubber with segments
                _buildScrubber(),

                // Segment list
                if (_segments.isNotEmpty)
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _segments.length,
                      itemBuilder: (context, index) => _buildSegmentChip(index),
                    ),
                  ),

                // Controls
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Marking status
                      if (_markingStartMs != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Text(
                            '▶ Start marked at ${_formatTime(_markingStartMs!)} — play to end point and tap "Mark End"',
                            style: const TextStyle(color: Colors.green),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // Main controls row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Mark Start
                          ElevatedButton.icon(
                            onPressed: _markStart,
                            icon: const Icon(Icons.flag, size: 18),
                            label: const Text('Mark Start'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),

                          // Play/Pause
                          IconButton(
                            onPressed: _togglePlayPause,
                            icon: Icon(
                              _isPlaying ? Icons.pause_circle : Icons.play_circle,
                              size: 56,
                              color: Colors.white,
                            ),
                          ),

                          // Mark End
                          ElevatedButton.icon(
                            onPressed: _markingStartMs != null ? _markEnd : null,
                            icon: const Icon(Icons.flag, size: 18),
                            label: const Text('Mark End'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _markingStartMs != null ? Colors.red[700] : Colors.grey[700],
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Clear button
                      TextButton(
                        onPressed: _clearAndStartFresh,
                        child: Text(
                          'Clear all & start fresh',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSegmentChip(int index) {
    final segment = _segments[index];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Chip(
        backgroundColor: Colors.blue[800],
        deleteIcon: Icon(Icons.close, size: 16, color: Colors.white70),
        onDeleted: _segments.length > 1 ? () => _deleteSegment(index) : null,
        label: Text(
          '${_formatTime(segment.inPointMs)} → ${_formatTime(segment.outPointMs)}',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildScrubber() {
    if (!_initialized) return const SizedBox.shrink();

    final totalMs = widget.clip.sourceDurationMs;
    final currentMs = _controller.value.position.inMilliseconds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final currentPos = (currentMs / totalMs) * width;

          return GestureDetector(
            onTapDown: (details) {
              final tapMs = (details.localPosition.dx / width * totalMs).round();
              _controller.seekTo(Duration(milliseconds: tapMs.clamp(0, totalMs)));
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  // Discarded regions (darker)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  // Kept segments (highlighted)
                  ..._segments.map((segment) {
                    final inPos = (segment.inPointMs / totalMs) * width;
                    final outPos = (segment.outPointMs / totalMs) * width;
                    return Positioned(
                      left: inPos,
                      width: outPos - inPos,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.4),
                          border: Border.symmetric(
                            vertical: BorderSide(color: Colors.green, width: 2),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Marking in progress (yellow)
                  if (_markingStartMs != null)
                    Positioned(
                      left: (_markingStartMs! / totalMs) * width,
                      width: (currentMs > _markingStartMs!) 
                          ? ((currentMs - _markingStartMs!) / totalMs) * width 
                          : 2,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.yellow.withValues(alpha: 0.4),
                          border: const Border(
                            left: BorderSide(color: Colors.yellow, width: 3),
                          ),
                        ),
                      ),
                    ),

                  // Current position playhead
                  Positioned(
                    left: currentPos - 1.5,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 3,
                      color: Colors.white,
                    ),
                  ),

                  // Time label
                  Positioned(
                    right: 8,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_formatTime(currentMs)} / ${_formatTime(totalMs)}',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
