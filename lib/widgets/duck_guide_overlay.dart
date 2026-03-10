import 'package:flutter/material.dart';
import '../models/duck_guide.dart';

/// The duck guide overlay - shows as a chat bubble or minimized icon
class DuckGuideOverlay extends StatelessWidget {
  final DuckGuide guide;
  final VoidCallback? onDismiss;
  final VoidCallback? onResume;
  final void Function(String value)? onReply;
  final VoidCallback? onExport;
  final VoidCallback? onStabilizeAll;

  const DuckGuideOverlay({
    super.key,
    required this.guide,
    this.onDismiss,
    this.onResume,
    this.onReply,
    this.onExport,
    this.onStabilizeAll,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show anything if not started or completed
    if (guide.state == GuideState.notStarted) {
      return const SizedBox.shrink();
    }

    // Show minimized duck if dismissed
    if (guide.state == GuideState.dismissed) {
      return _MinimizedDuck(onTap: onResume);
    }

    // Show completed message briefly then hide
    if (guide.state == GuideState.completed) {
      return _ExpandedBubble(
        message: guide.currentMessage,
        onDismiss: onDismiss,
        onReply: onReply,
        showDismiss: false,
      );
    }

    // Show the full bubble
    return _ExpandedBubble(
      message: guide.currentMessage,
      onDismiss: onDismiss,
      onReply: (value) {
        // Handle special actions
        if (value == 'export') {
          onExport?.call();
        } else if (value == 'yes' && guide.currentStep == GuideStep.polish) {
          onStabilizeAll?.call();
          onReply?.call(value);
        } else {
          onReply?.call(value);
        }
      },
      showDismiss: guide.state == GuideState.active || guide.state == GuideState.offered,
    );
  }
}

/// The minimized duck icon in the corner
class _MinimizedDuck extends StatelessWidget {
  final VoidCallback? onTap;

  const _MinimizedDuck({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber[300],
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            '🐥',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}

/// The expanded chat bubble with duck
class _ExpandedBubble extends StatelessWidget {
  final DuckMessage message;
  final VoidCallback? onDismiss;
  final void Function(String value)? onReply;
  final bool showDismiss;

  const _ExpandedBubble({
    required this.message,
    this.onDismiss,
    this.onReply,
    this.showDismiss = true,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 8,
      right: 8,
      top: 8,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[900]?.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber[300]!, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Duck avatar, message, and dismiss in one row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Duck avatar (smaller)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.amber[300],
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('🐥', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Message text
                    Expanded(
                      child: Text(
                        message.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ),
                    // Dismiss X button
                    if (showDismiss)
                      GestureDetector(
                        onTap: onDismiss,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.close,
                            color: Colors.grey[500],
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
                
                // Quick reply buttons
                if (message.replies != null && message.replies!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: message.replies!.map((reply) {
                      return _QuickReplyButton(
                        reply: reply,
                        onTap: () => onReply?.call(reply.value),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A quick reply button
class _QuickReplyButton extends StatelessWidget {
  final QuickReply reply;
  final VoidCallback? onTap;

  const _QuickReplyButton({
    required this.reply,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber[300],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            reply.emoji != null ? '${reply.emoji} ${reply.label}' : reply.label,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
