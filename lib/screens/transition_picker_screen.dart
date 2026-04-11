import 'package:flutter/material.dart';
import '../models/choreography.dart';

/// Bottom sheet for picking a transition between two clips.
/// 8 visual preset cards with mini animations.
class TransitionPickerSheet extends StatefulWidget {
  final Transition current;
  final String fromClipName;
  final String toClipName;

  const TransitionPickerSheet({
    super.key,
    required this.current,
    required this.fromClipName,
    required this.toClipName,
  });

  /// Shows the picker and returns the new transition, or null if cancelled.
  static Future<Transition?> show(
    BuildContext context, {
    required Transition current,
    required String fromClipName,
    required String toClipName,
  }) {
    return showModalBottomSheet<Transition>(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => TransitionPickerSheet(
        current: current,
        fromClipName: fromClipName,
        toClipName: toClipName,
      ),
    );
  }

  @override
  State<TransitionPickerSheet> createState() => _TransitionPickerSheetState();
}

class _TransitionPickerSheetState extends State<TransitionPickerSheet>
    with TickerProviderStateMixin {
  late TransitionType _selected;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _selected = widget.current.type;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Transition',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      Transition(
                        type: _selected,
                        durationMs: _selected.defaultDurationMs,
                      ),
                    );
                  },
                  child: const Text(
                    'DONE',
                    style: TextStyle(
                      color: Colors.yellow,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Between "${widget.fromClipName}" → "${widget.toClipName}"',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            // Grid of transition cards
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 0.9,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: TransitionType.values
                  .map((t) => _TransitionCard(
                        type: t,
                        selected: _selected == t,
                        animation: _controller,
                        onTap: () => setState(() => _selected = t),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TransitionCard extends StatelessWidget {
  final TransitionType type;
  final bool selected;
  final Animation<double> animation;
  final VoidCallback onTap;

  const _TransitionCard({
    required this.type,
    required this.selected,
    required this.animation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.yellow : Colors.transparent,
            width: 3,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (ctx, _) => _TransitionPreview(
                    type: type,
                    progress: animation.value,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                type.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini animated preview of a transition — two solid color blocks
/// ("clip A" and "clip B") swapping using the transition effect.
class _TransitionPreview extends StatelessWidget {
  final TransitionType type;
  final double progress; // 0..1

  const _TransitionPreview({required this.type, required this.progress});

  // Loop the progress with a hold at each end so kids see both states.
  double get _phase {
    // 0..0.3 = fully A, 0.3..0.6 = transitioning, 0.6..1.0 = fully B
    if (progress < 0.3) return 0;
    if (progress > 0.6) return 1;
    return (progress - 0.3) / 0.3;
  }

  @override
  Widget build(BuildContext context) {
    const clipA = Color(0xFF4CAF50); // green
    const clipB = Color(0xFF2196F3); // blue
    final p = _phase;

    switch (type) {
      case TransitionType.none:
        return Container(color: p < 0.5 ? clipA : clipB);

      case TransitionType.fade:
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: clipA),
            Opacity(opacity: p, child: Container(color: clipB)),
          ],
        );

      case TransitionType.slideLeft:
      case TransitionType.slideRight:
      case TransitionType.slideUp:
      case TransitionType.slideDown:
        Offset offset;
        switch (type) {
          case TransitionType.slideLeft:
            offset = Offset(1.0 - p, 0);
            break;
          case TransitionType.slideRight:
            offset = Offset(-(1.0 - p), 0);
            break;
          case TransitionType.slideUp:
            offset = Offset(0, 1.0 - p);
            break;
          case TransitionType.slideDown:
            offset = Offset(0, -(1.0 - p));
            break;
          default:
            offset = Offset.zero;
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: clipA),
            FractionalTranslation(
              translation: offset,
              child: Container(color: clipB),
            ),
          ],
        );

      case TransitionType.wipe:
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: clipA),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: p,
                heightFactor: 1,
                child: Container(color: clipB),
              ),
            ),
          ],
        );

      case TransitionType.zoom:
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: clipA),
            Center(
              child: Transform.scale(
                scale: p * 2,
                child: Container(
                  color: clipB,
                  width: 100,
                  height: 100,
                ),
              ),
            ),
          ],
        );

      case TransitionType.circleClose:
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: clipB),
            ClipPath(
              clipper: _CircleClipper(progress: 1 - p),
              child: Container(color: clipA),
            ),
          ],
        );
    }
  }
}

class _CircleClipper extends CustomClipper<Path> {
  final double progress;
  _CircleClipper({required this.progress});

  @override
  Path getClip(Size size) {
    final maxRadius = size.longestSide;
    final path = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: maxRadius * progress,
      ));
    return path;
  }

  @override
  bool shouldReclip(covariant _CircleClipper oldClipper) =>
      oldClipper.progress != progress;
}
