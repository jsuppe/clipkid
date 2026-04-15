import 'package:flutter/material.dart';
import '../models/choreography.dart';

/// Visual timeline showing clips in sequence with drag-to-reorder
class TimelineView extends StatefulWidget {
  final Choreography choreography;
  final int currentPositionMs;
  final ValueChanged<int>? onSeek;
  final ValueChanged<int>? onClipTap;
  final void Function(int oldIndex, int newIndex)? onReorder;
  // Called when the transition dot between clip[index] and clip[index+1] is tapped.
  final ValueChanged<int>? onTransitionTap;
  final int? selectedClipIndex;

  const TimelineView({
    super.key,
    required this.choreography,
    required this.currentPositionMs,
    this.onSeek,
    this.onClipTap,
    this.onReorder,
    this.onTransitionTap,
    this.selectedClipIndex,
  });

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  int? _hoverTargetIndex;

  // Fixed color palette for clips - visually distinct colors
  static const List<Color> _clipColors = [
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFFE91E63), // Pink
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFFF5722), // Deep Orange
  ];

  Color _getClipColor(int index) {
    return _clipColors[index % _clipColors.length];
  }

  String _formatTime(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m${seconds}s';
    }
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.choreography.clips.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'Add videos to start',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final totalDuration = widget.choreography.totalDurationMs;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final playheadPosition = totalDuration > 0
                ? (widget.currentPositionMs / totalDuration) * width
                : 0.0;

            return GestureDetector(
              onTapDown: (details) {
                if (widget.onSeek != null && totalDuration > 0) {
                  final seekMs =
                      (details.localPosition.dx / width * totalDuration).round();
                  widget.onSeek!(seekMs.clamp(0, totalDuration));
                }
              },
              child: Stack(
                children: [
                  // Time ticks at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 20,
                    child: _buildTimeTicks(width, totalDuration),
                  ),
                  // Clips area (above time ticks)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: 20,
                    child: Row(
                      children: _buildClipsRow(width, totalDuration),
                    ),
                  ),
                  // Transition dots at clip boundaries
                  ..._buildTransitionDots(width, totalDuration),
                  // Playhead (full height)
                  Positioned(
                    left: playheadPosition.clamp(0, width - 2),
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        width: 2,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimeTicks(double width, int totalDuration) {
    if (totalDuration <= 0) return const SizedBox.shrink();

    // Determine tick interval based on duration
    // For short videos: every 5 seconds
    // For medium: every 10 seconds
    // For long: every 30 seconds
    int tickIntervalMs;
    if (totalDuration < 30000) {
      tickIntervalMs = 5000;
    } else if (totalDuration < 120000) {
      tickIntervalMs = 10000;
    } else if (totalDuration < 300000) {
      tickIntervalMs = 30000;
    } else {
      tickIntervalMs = 60000;
    }

    final ticks = <Widget>[];
    for (int ms = 0; ms <= totalDuration; ms += tickIntervalMs) {
      final x = (ms / totalDuration) * width;
      ticks.add(
        Positioned(
          left: x - 1,
          top: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 1,
                height: 6,
                color: Colors.grey[600],
              ),
              Text(
                _formatTime(ms),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(children: ticks);
  }

  List<Widget> _buildTransitionDots(double width, int totalDuration) {
    if (widget.choreography.clips.length < 2 || totalDuration <= 0) return [];
    final dots = <Widget>[];
    int cumulativeMs = 0;
    for (int i = 0; i < widget.choreography.clips.length - 1; i++) {
      cumulativeMs += widget.choreography.clips[i].durationMs;
      final x = (cumulativeMs / totalDuration) * width;
      final transition = widget.choreography.clips[i].outgoingTransition;
      dots.add(
        Positioned(
          left: x - 14,
          top: 18,
          child: GestureDetector(
            onTap: () => widget.onTransitionTap?.call(i),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: transition.isNone
                    ? Colors.grey[800]
                    : Colors.yellow.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: transition.isNone ? Colors.grey[600]! : Colors.yellow,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
              child: Center(
                child: Text(
                  transition.isNone ? '+' : transition.type.displayName.split(' ').last,
                  style: TextStyle(
                    color: transition.isNone ? Colors.grey[400] : Colors.black,
                    fontSize: transition.isNone ? 20 : 14,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return dots;
  }

  List<Widget> _buildClipsRow(double width, int totalDuration) {
    final clips = widget.choreography.clips;
    final widgets = <Widget>[];

    for (int index = 0; index < clips.length; index++) {
      final clip = clips[index];
      // Width proportional to clip duration
      final clipWidth = (clip.durationMs / totalDuration) * width;
      
      widgets.add(_buildDraggableClip(index, clip, clipWidth.clamp(40, double.infinity)));
    }

    return widgets;
  }

  Widget _buildDraggableClip(int index, Clip clip, double clipWidth) {
    final isSelected = widget.selectedClipIndex == index;

    return LongPressDraggable<int>(
      data: index,
      delay: const Duration(milliseconds: 200),
      onDragEnd: (_) => setState(() {
        _hoverTargetIndex = null;
      }),
      onDraggableCanceled: (_, __) => setState(() {
        _hoverTargetIndex = null;
      }),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: clipWidth.clamp(60, 150),
          height: 60,
          decoration: BoxDecoration(
            color: _getClipColor(index).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Text(
              clip.name ?? 'Clip ${index + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildClipContainer(index, clip, clipWidth, isSelected),
      ),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) {
          final fromIndex = details.data;
          if (fromIndex == index) return false;
          setState(() => _hoverTargetIndex = index);
          return true;
        },
        onLeave: (_) => setState(() => _hoverTargetIndex = null),
        onAcceptWithDetails: (details) {
          final fromIndex = details.data;
          setState(() => _hoverTargetIndex = null);
          widget.onReorder?.call(fromIndex, index);
        },
        builder: (context, candidateData, rejectedData) {
          final isDropTarget = _hoverTargetIndex == index;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onClipTap?.call(index),
            child: Stack(
              children: [
                _buildClipContainer(index, clip, clipWidth, isSelected),
                // Drop indicator overlay
                if (isDropTarget)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildClipContainer(int index, Clip clip, double clipWidth, bool isSelected) {
    final color = _getClipColor(index);
    final hasSegments = clip.segments.length > 1;
    
    return Container(
      width: clipWidth,
      height: 80,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        border: Border(
          left: BorderSide(color: Colors.grey[700]!, width: 1),
          right: index == widget.choreography.clips.length - 1
              ? BorderSide(color: Colors.grey[700]!, width: 1)
              : BorderSide.none,
        ),
      ),
      child: Stack(
        children: [
          // Main clip bar
          Positioned(
            left: 4,
            right: 4,
            top: 4,
            bottom: 24, // Leave room for duration label
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    // Clip number
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Clip name
                    Expanded(
                      child: Text(
                        clip.name ?? 'Clip',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Status icons
                    if (clip.isTrimmed)
                      const Icon(Icons.content_cut, size: 12, color: Colors.white70),
                    if (hasSegments)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Text(
                          '${clip.segments.length}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (clip.effects.stabilize)
                      Icon(
                        clip.processedPath != null ? Icons.check_circle : Icons.pending,
                        size: 12,
                        color: clip.processedPath != null ? Colors.green[300] : Colors.orange[300],
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Duration label at bottom
          Positioned(
            left: 4,
            bottom: 4,
            child: Text(
              _formatTime(clip.durationMs),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
