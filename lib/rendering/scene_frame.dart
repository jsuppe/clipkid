import '../models/choreography.dart';

/// Describes exactly what should be rendered at a given point in time.
/// Produced by [SceneEvaluator], consumed by [SceneRenderer].
class SceneFrame {
  /// Primary (current) video layer — always present when clips exist.
  final VideoLayer? primary;

  /// Secondary video layer — only present during a transition.
  final VideoLayer? secondary;

  /// Active transition between secondary (outgoing) → primary (incoming).
  final TransitionState? transition;

  /// Text overlays visible at this moment.
  final List<ActiveTextOverlay> textOverlays;

  /// Sticker overlays visible at this moment.
  final List<ActiveSticker> stickers;

  /// Global timeline position in ms.
  final int timeMs;

  /// Total duration of the choreography in ms.
  final int totalDurationMs;

  const SceneFrame({
    this.primary,
    this.secondary,
    this.transition,
    this.textOverlays = const [],
    this.stickers = const [],
    required this.timeMs,
    required this.totalDurationMs,
  });

  bool get hasTransition => transition != null && secondary != null;
  bool get isEmpty => primary == null;
}

/// A video layer to render — points to a clip and its local playback position.
class VideoLayer {
  /// Index into Choreography.clips.
  final int clipIndex;

  /// Local playback position within the clip's source file (ms).
  final int localPositionMs;

  /// The clip model (for accessing path, effects, etc).
  final Clip clip;

  /// Opacity (0.0–1.0). Used during fade transitions.
  final double opacity;

  /// Filter to apply.
  final VideoFilter filter;

  const VideoLayer({
    required this.clipIndex,
    required this.localPositionMs,
    required this.clip,
    this.opacity = 1.0,
    this.filter = VideoFilter.none,
  });
}

/// Describes an in-progress transition.
class TransitionState {
  /// The transition type being applied.
  final TransitionType type;

  /// Progress from 0.0 (start) to 1.0 (complete).
  final double progress;

  /// Duration of the transition in ms.
  final int durationMs;

  const TransitionState({
    required this.type,
    required this.progress,
    required this.durationMs,
  });
}

/// A text overlay that is currently visible.
class ActiveTextOverlay {
  final TextOverlay overlay;
  final double x;
  final double y;
  final double scale;

  const ActiveTextOverlay({
    required this.overlay,
    required this.x,
    required this.y,
    required this.scale,
  });
}

/// A sticker that is currently visible.
class ActiveSticker {
  final StickerOverlay sticker;

  const ActiveSticker({required this.sticker});
}
