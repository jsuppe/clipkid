import 'dart:math';
import 'package:flutter/rendering.dart';
import '../models/choreography.dart';

/// Returns a [CustomClipper<Path>] that reveals the incoming clip
/// according to [type] and [progress] (0.0 → 1.0).
/// Used to clip the primary (incoming) layer during a transition.
CustomClipper<Path>? clipperForTransition(
  TransitionType type,
  double progress,
  Size size,
) {
  switch (type) {
    case TransitionType.none:
      return null;
    case TransitionType.fade:
      // Fade uses opacity, not clipping.
      return null;
    case TransitionType.slideLeft:
      return _SlideClipper(progress: progress, direction: _SlideDir.left);
    case TransitionType.slideRight:
      return _SlideClipper(progress: progress, direction: _SlideDir.right);
    case TransitionType.slideUp:
      return _SlideClipper(progress: progress, direction: _SlideDir.up);
    case TransitionType.slideDown:
      return _SlideClipper(progress: progress, direction: _SlideDir.down);
    case TransitionType.wipe:
      return _WipeClipper(progress: progress);
    case TransitionType.zoom:
      return _ZoomClipper(progress: progress);
    case TransitionType.circleClose:
      return _CircleClipper(progress: progress);
  }
}

/// Offset for the outgoing (secondary) clip during slide transitions.
Offset slideOutOffset(TransitionType type, double progress, Size size) {
  switch (type) {
    case TransitionType.slideLeft:
      return Offset(-size.width * progress, 0);
    case TransitionType.slideRight:
      return Offset(size.width * progress, 0);
    case TransitionType.slideUp:
      return Offset(0, -size.height * progress);
    case TransitionType.slideDown:
      return Offset(0, size.height * progress);
    default:
      return Offset.zero;
  }
}

/// Offset for the incoming (primary) clip during slide transitions.
Offset slideInOffset(TransitionType type, double progress, Size size) {
  switch (type) {
    case TransitionType.slideLeft:
      return Offset(size.width * (1 - progress), 0);
    case TransitionType.slideRight:
      return Offset(-size.width * (1 - progress), 0);
    case TransitionType.slideUp:
      return Offset(0, size.height * (1 - progress));
    case TransitionType.slideDown:
      return Offset(0, -size.height * (1 - progress));
    default:
      return Offset.zero;
  }
}

// ---------------------------------------------------------------------------
// Clippers
// ---------------------------------------------------------------------------

enum _SlideDir { left, right, up, down }

class _SlideClipper extends CustomClipper<Path> {
  final double progress;
  final _SlideDir direction;
  _SlideClipper({required this.progress, required this.direction});

  @override
  Path getClip(Size size) {
    // The incoming clip is fully visible — clipping is handled via offset.
    return Path()..addRect(Offset.zero & size);
  }

  @override
  bool shouldReclip(covariant _SlideClipper old) => old.progress != progress;
}

class _WipeClipper extends CustomClipper<Path> {
  final double progress;
  _WipeClipper({required this.progress});

  @override
  Path getClip(Size size) {
    return Path()..addRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
  }

  @override
  bool shouldReclip(covariant _WipeClipper old) => old.progress != progress;
}

class _ZoomClipper extends CustomClipper<Path> {
  final double progress;
  _ZoomClipper({required this.progress});

  @override
  Path getClip(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxRadius = sqrt(cx * cx + cy * cy);
    final radius = maxRadius * progress;
    return Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
  }

  @override
  bool shouldReclip(covariant _ZoomClipper old) => old.progress != progress;
}

class _CircleClipper extends CustomClipper<Path> {
  final double progress;
  _CircleClipper({required this.progress});

  @override
  Path getClip(Size size) {
    // Circle close: starts fully open, closes to center.
    // For the incoming clip we invert — it expands from center.
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxRadius = sqrt(cx * cx + cy * cy);
    final radius = maxRadius * progress;
    return Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
  }

  @override
  bool shouldReclip(covariant _CircleClipper old) => old.progress != progress;
}
