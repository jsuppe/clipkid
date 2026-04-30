import '../models/choreography.dart';
import 'scene_frame.dart';

/// Pure evaluator: given a [Choreography] and a global time position,
/// produces a [SceneFrame] describing exactly what should be rendered.
///
/// All timeline math lives here — trim, segments, speed, freeze frames,
/// transition overlap. The renderer just paints what the evaluator says.
class SceneEvaluator {
  const SceneEvaluator();

  SceneFrame evaluate(Choreography choreography, int timeMs) {
    final clips = choreography.clips;
    if (clips.isEmpty) {
      return SceneFrame(
        timeMs: timeMs,
        totalDurationMs: 0,
      );
    }

    final totalMs = choreography.totalDurationMs;
    final clampedTime = timeMs.clamp(0, totalMs);

    // Find which clip(s) are active at this time.
    // During a transition, two clips overlap: the outgoing clip's tail
    // and the incoming clip's head share time.
    final activeIndex = _clipIndexAt(clips, clampedTime);
    if (activeIndex < 0) {
      return SceneFrame(timeMs: clampedTime, totalDurationMs: totalMs);
    }

    final activeClip = clips[activeIndex];

    // Check if we're in a transition region.
    // A transition happens at the END of clip[i], overlapping with the
    // START of clip[i+1]. The transition belongs to clip[i].outgoingTransition.
    TransitionState? transState;
    VideoLayer? secondary;
    VideoLayer? primary;

    // Check: are we in the outgoing transition of the previous clip?
    if (activeIndex > 0) {
      final prevClip = clips[activeIndex - 1];
      final prevTrans = prevClip.outgoingTransition;
      if (!prevTrans.isNone) {
        final transEndMs = prevClip.endMs;
        final transStartMs = transEndMs - prevTrans.durationMs;
        if (clampedTime >= transStartMs && clampedTime < transEndMs) {
          // We're in the transition: prev is outgoing, active is incoming.
          final progress =
              (clampedTime - transStartMs) / prevTrans.durationMs;
          transState = TransitionState(
            type: prevTrans.type,
            progress: progress.clamp(0.0, 1.0),
            durationMs: prevTrans.durationMs,
          );
          secondary = _buildLayer(prevClip, activeIndex - 1, clampedTime);
          primary = _buildLayer(activeClip, activeIndex, clampedTime);
        }
      }
    }

    // Check: are we in our own outgoing transition to the next clip?
    if (transState == null &&
        activeIndex < clips.length - 1 &&
        !activeClip.outgoingTransition.isNone) {
      final trans = activeClip.outgoingTransition;
      final transEndMs = activeClip.endMs;
      final transStartMs = transEndMs - trans.durationMs;
      if (clampedTime >= transStartMs && clampedTime < transEndMs) {
        final nextClip = clips[activeIndex + 1];
        final progress = (clampedTime - transStartMs) / trans.durationMs;
        transState = TransitionState(
          type: trans.type,
          progress: progress.clamp(0.0, 1.0),
          durationMs: trans.durationMs,
        );
        secondary = _buildLayer(activeClip, activeIndex, clampedTime);
        primary = _buildLayer(nextClip, activeIndex + 1, clampedTime);
      }
    }

    // No transition — just the active clip.
    primary ??= _buildLayer(activeClip, activeIndex, clampedTime);

    // Collect visible overlays from the primary clip.
    final textOverlays = _activeTextOverlays(primary.clip, primary.localPositionMs);
    final stickers = _activeStickers(primary.clip, primary.localPositionMs);

    return SceneFrame(
      primary: primary,
      secondary: secondary,
      transition: transState,
      textOverlays: textOverlays,
      stickers: stickers,
      timeMs: clampedTime,
      totalDurationMs: totalMs,
    );
  }

  /// Find the clip index whose timeline span contains [timeMs].
  int _clipIndexAt(List<Clip> clips, int timeMs) {
    for (int i = 0; i < clips.length; i++) {
      if (timeMs >= clips[i].startMs && timeMs < clips[i].endMs) {
        return i;
      }
    }
    // Past the end — return last clip.
    if (clips.isNotEmpty && timeMs >= clips.last.endMs) {
      return clips.length - 1;
    }
    return -1;
  }

  /// Build a [VideoLayer] for a clip at the given global time.
  VideoLayer _buildLayer(Clip clip, int clipIndex, int globalTimeMs) {
    final clipLocalMs = globalTimeMs - clip.startMs;
    final sourceLocalMs = _clipLocalToSource(clip, clipLocalMs);
    return VideoLayer(
      clipIndex: clipIndex,
      localPositionMs: sourceLocalMs,
      clip: clip,
      filter: clip.effects.filter,
    );
  }

  /// Convert clip-local time (after speed/freeze) to source-file time.
  int _clipLocalToSource(Clip clip, int clipLocalMs) {
    final speed = clip.effects.speed;
    final freezeMs = clip.effects.freezeEndMs;
    final segments = clip.effectiveSegments;

    // Total content duration before freeze.
    final contentDurationMs = clip.durationMs - freezeMs;
    if (clipLocalMs >= contentDurationMs) {
      // In freeze region — return last frame of last segment.
      return segments.last.outPointMs;
    }

    // Convert from playback time (speed-adjusted) to source time.
    final sourceElapsed = (clipLocalMs * speed).round();

    // Walk through segments to find the right source position.
    int accumulated = 0;
    for (final seg in segments) {
      final segDuration = seg.durationMs;
      if (accumulated + segDuration > sourceElapsed) {
        return seg.inPointMs + (sourceElapsed - accumulated);
      }
      accumulated += segDuration;
    }

    // Past end of segments — clamp to last frame.
    return segments.last.outPointMs;
  }

  /// Collect text overlays visible at a given local position within a clip.
  List<ActiveTextOverlay> _activeTextOverlays(Clip clip, int localMs) {
    final result = <ActiveTextOverlay>[];
    final durationMs = clip.durationMs;
    for (final overlay in clip.effects.textOverlays) {
      if (_isOverlayVisible(overlay.timing, localMs, durationMs,
          overlay.customStartMs, overlay.customEndMs)) {
        result.add(ActiveTextOverlay(
          overlay: overlay,
          x: overlay.x,
          y: overlay.y,
          scale: overlay.scale,
        ));
      }
    }
    return result;
  }

  bool _isOverlayVisible(
    OverlayTiming timing,
    int localMs,
    int clipDurationMs,
    int? customStartMs,
    int? customEndMs,
  ) {
    switch (timing) {
      case OverlayTiming.wholeClip:
        return true;
      case OverlayTiming.firstTwoSeconds:
        return localMs < 2000;
      case OverlayTiming.lastTwoSeconds:
        return localMs > clipDurationMs - 2000;
      case OverlayTiming.customRange:
        final start = customStartMs ?? 0;
        final end = customEndMs ?? clipDurationMs;
        return localMs >= start && localMs <= end;
    }
  }

  /// Collect stickers visible at a given local position within a clip.
  List<ActiveSticker> _activeStickers(Clip clip, int localMs) {
    final result = <ActiveSticker>[];
    for (final sticker in clip.effects.stickers) {
      final end = sticker.endMs ?? clip.durationMs;
      if (localMs >= sticker.startMs && localMs <= end) {
        result.add(ActiveSticker(sticker: sticker));
      }
    }
    return result;
  }
}
