import 'package:flutter/material.dart';
import '../models/choreography.dart';

/// Visual timeline showing clips in sequence with drag-to-reorder
class TimelineView extends StatefulWidget {
  final Choreography choreography;
  final int currentPositionMs;
  final ValueChanged<int>? onSeek;
  final ValueChanged<int>? onClipTap;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final int? selectedClipIndex;

  const TimelineView({
    super.key,
    required this.choreography,
    required this.currentPositionMs,
    this.onSeek,
    this.onClipTap,
    this.onReorder,
    this.selectedClipIndex,
  });

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  int? _draggedIndex;
  int? _hoverTargetIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.choreography.clips.isEmpty) {
      return Container(
        height: 80,
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
        height: 80,
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
                  // Clips row with drop indicators
                  Row(
                    children: _buildClipsRow(width, totalDuration),
                  ),
                  // Playhead
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

  List<Widget> _buildClipsRow(double width, int totalDuration) {
    final clips = widget.choreography.clips;
    // Reserve space for drop indicators - edge zones are larger for easier touch targeting
    final dropZoneWidth = 12.0;
    final edgeDropZoneWidth = 32.0; // Larger for first/last positions
    final numMiddleDropZones = clips.length > 1 ? clips.length - 1 : 0;
    final totalDropSpace = (edgeDropZoneWidth * 2) + (numMiddleDropZones * dropZoneWidth);
    final totalMargins = clips.length * 8.0;
    final availableWidth = width - totalMargins - totalDropSpace;
    
    final widgets = <Widget>[];

    // Drop zone at beginning (insert at index 0) - larger for easier targeting
    widgets.add(_buildDropIndicator(0, edgeDropZoneWidth, isEdge: true));

    for (int index = 0; index < clips.length; index++) {
      final clip = clips[index];
      final clipWidth = (clip.durationMs / totalDuration) * availableWidth;
      
      widgets.add(_buildDraggableClip(index, clip, clipWidth.clamp(40, double.infinity)));
      
      // Drop zone after this clip (insert at index + 1)
      // Last one is edge (larger), others are normal
      final isLastZone = index == clips.length - 1;
      widgets.add(_buildDropIndicator(
        index + 1, 
        isLastZone ? edgeDropZoneWidth : dropZoneWidth,
        isEdge: isLastZone,
      ));
    }

    return widgets;
  }

  Widget _buildDropIndicator(int targetIndex, double baseWidth, {bool isEdge = false}) {
    final isHovering = _hoverTargetIndex == targetIndex;
    final isDragging = _draggedIndex != null;
    
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        final fromIndex = details.data;
        // Can't drop at same position or adjacent (no change)
        if (fromIndex == targetIndex || fromIndex == targetIndex - 1) {
          return false;
        }
        setState(() => _hoverTargetIndex = targetIndex);
        return true;
      },
      onLeave: (_) {
        setState(() => _hoverTargetIndex = null);
      },
      onAcceptWithDetails: (details) {
        final fromIndex = details.data;
        var toIndex = targetIndex;
        
        // Adjust for the removal of the dragged item
        if (fromIndex < toIndex) {
          toIndex--;
        }
        
        setState(() => _hoverTargetIndex = null);
        widget.onReorder?.call(fromIndex, toIndex);
      },
      builder: (context, candidateData, rejectedData) {
        // Edge zones show arrows when dragging to hint at drop targets
        Widget? hintWidget;
        if (isHovering) {
          hintWidget = const Icon(Icons.add, color: Colors.white, size: 16);
        } else if (isDragging && isEdge) {
          // Show directional hint on edge zones
          hintWidget = Icon(
            targetIndex == 0 ? Icons.first_page : Icons.last_page,
            color: Colors.white54,
            size: 16,
          );
        }
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: isHovering ? 32 : baseWidth,
          height: 72,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isHovering 
                ? Colors.blue 
                : (isDragging ? Colors.blue.withValues(alpha: isEdge ? 0.5 : 0.3) : Colors.transparent),
            borderRadius: BorderRadius.circular(4),
          ),
          child: hintWidget != null ? Center(child: hintWidget) : null,
        );
      },
    );
  }

  Widget _buildDraggableClip(int index, Clip clip, double clipWidth) {
    final isSelected = widget.selectedClipIndex == index;
    final isDragging = _draggedIndex == index;

    return LongPressDraggable<int>(
      data: index,
      delay: const Duration(milliseconds: 200),
      onDragStarted: () => setState(() => _draggedIndex = index),
      onDragEnd: (_) => setState(() {
        _draggedIndex = null;
        _hoverTargetIndex = null;
      }),
      onDraggableCanceled: (_, __) => setState(() {
        _draggedIndex = null;
        _hoverTargetIndex = null;
      }),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: clipWidth,
          height: 72,
          decoration: BoxDecoration(
            color: _clipColor(clip.id).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Text(
              clip.name ?? 'Clip',
              style: const TextStyle(color: Colors.white, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildClipContainer(clip, clipWidth, isSelected, showIcons: false),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onClipTap?.call(index),
        child: _buildClipContainer(clip, clipWidth, isSelected, showIcons: true),
      ),
    );
  }

  Widget _buildClipContainer(Clip clip, double clipWidth, bool isSelected, {required bool showIcons}) {
    return Container(
      width: clipWidth,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _clipColor(clip.id),
        borderRadius: BorderRadius.circular(4),
        border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                clip.name ?? 'Clip',
                style: const TextStyle(color: Colors.white, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showIcons) ...[
              if (clip.isTrimmed)
                const Icon(Icons.content_cut, size: 12, color: Colors.white70),
              if (clip.effects.stabilize)
                Icon(
                  clip.processedPath != null ? Icons.check_circle : Icons.pending,
                  size: 12,
                  color: clip.processedPath != null ? Colors.green[300] : Colors.orange[300],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Color _clipColor(String id) {
    final hash = id.hashCode;
    final hue = (hash % 360).abs().toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.4).toColor();
  }
}
