import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui show Clip;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';
import '../models/choreography.dart';
import '../widgets/text_overlay_style.dart';
import 'filter_matrix.dart';
import 'scene_evaluator.dart';
import 'scene_frame.dart';
import 'transition_painter.dart';

/// Real-time scene graph renderer. Evaluates the [Choreography] at the
/// current playback position on every tick and composites video layers,
/// transitions, filters, text overlays, and stickers.
///
/// Replaces [VideoPreview] as the single rendering engine.
class SceneRenderer extends StatefulWidget {
  final Choreography choreography;
  final ValueChanged<int>? onPositionChanged;
  final int? seekToMs;
  final void Function(int clipIndex, ClipEffects newEffects)? onClipEffectsChanged;
  /// When true, disables interactive overlay editing (drag/delete).
  final bool readOnly;

  const SceneRenderer({
    super.key,
    required this.choreography,
    this.onPositionChanged,
    this.seekToMs,
    this.onClipEffectsChanged,
    this.readOnly = false,
  });

  @override
  State<SceneRenderer> createState() => SceneRendererState();
}

class SceneRendererState extends State<SceneRenderer>
    with SingleTickerProviderStateMixin {
  static const _evaluator = SceneEvaluator();

  late Ticker _ticker;
  Duration _lastTick = Duration.zero;
  int _globalTimeMs = 0;
  bool _isPlaying = false;

  // Two-player pool. _players[0] and _players[1] alternate roles.
  final List<_PlayerSlot> _players = [_PlayerSlot(), _PlayerSlot()];

  // Which _PlayerSlot currently holds the primary clip.
  int _primarySlotIndex = 0;

  // Last evaluated frame — drives the build.
  SceneFrame _frame = const SceneFrame(timeMs: 0, totalDurationMs: 0);

  // Music player for background track
  AudioPlayer? _musicPlayer;

  int? _selectedOverlayIndex;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.choreography.clips.isNotEmpty) {
      _loadClipIntoSlot(0, 0);
      _evaluate();
    }
  }

  @override
  void didUpdateWidget(SceneRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seekToMs != null && widget.seekToMs != oldWidget.seekToMs) {
      seekTo(widget.seekToMs!);
    }
    if (widget.choreography.clips.length != oldWidget.choreography.clips.length) {
      if (widget.choreography.clips.isNotEmpty &&
          _players[_primarySlotIndex].clipIndex < 0) {
        _loadClipIntoSlot(0, _primarySlotIndex);
      }
      _evaluate();
    }
    // Reload if playback path changed (processing).
    final pi = _players[_primarySlotIndex].clipIndex;
    if (pi >= 0 &&
        pi < widget.choreography.clips.length &&
        pi < oldWidget.choreography.clips.length) {
      final newPath = widget.choreography.clips[pi].playbackPath;
      final oldPath = oldWidget.choreography.clips[pi].playbackPath;
      if (newPath != oldPath) {
        _loadClipIntoSlot(pi, _primarySlotIndex);
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final s in _players) {
      s.dispose();
    }
    _musicPlayer?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Public API (matches VideoPreview surface)
  // ------------------------------------------------------------------

  bool get isPlaying => _isPlaying;

  bool get isPlayingStabilized {
    final ci = _players[_primarySlotIndex].clipIndex;
    if (ci < 0 || ci >= widget.choreography.clips.length) return false;
    final clip = widget.choreography.clips[ci];
    return clip.effects.stabilize && clip.processedPath != null;
  }

  bool get isPlayingStyled {
    final ci = _players[_primarySlotIndex].clipIndex;
    if (ci < 0 || ci >= widget.choreography.clips.length) return false;
    final clip = widget.choreography.clips[ci];
    return clip.effects.styled && clip.processedPath != null;
  }

  String? get currentStyleName {
    final ci = _players[_primarySlotIndex].clipIndex;
    if (ci < 0 || ci >= widget.choreography.clips.length) return null;
    return widget.choreography.clips[ci].effects.styleName;
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _pause();
    } else {
      await _play();
    }
  }

  Future<void> pause() async => _pause();

  Future<void> seekTo(int globalMs) async {
    _globalTimeMs = globalMs.clamp(0, widget.choreography.totalDurationMs);
    _evaluate();
    await _syncPlayersToFrame();
    widget.onPositionChanged?.call(_globalTimeMs);
  }

  // ------------------------------------------------------------------
  // Playback control
  // ------------------------------------------------------------------

  Future<void> _play() async {
    if (widget.choreography.clips.isEmpty) return;
    // If at end, restart.
    if (_globalTimeMs >= widget.choreography.totalDurationMs) {
      _globalTimeMs = 0;
      _evaluate();
      await _syncPlayersToFrame();
    }
    _isPlaying = true;
    _lastTick = Duration.zero;
    _ticker.start();
    for (final s in _players) {
      if (s.controller?.value.isInitialized == true) {
        await s.controller!.play();
      }
    }
    await _startMusic();
    setState(() {});
  }

  Future<void> _pause() async {
    _isPlaying = false;
    _ticker.stop();
    for (final s in _players) {
      await s.controller?.pause();
    }
    await _musicPlayer?.pause();
    setState(() {});
  }

  Future<void> _startMusic() async {
    final track = widget.choreography.musicTrack;
    if (track == MusicTrack.none) return;
    _musicPlayer ??= AudioPlayer();
    await _musicPlayer!.setVolume(widget.choreography.musicVolume);
    await _musicPlayer!.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer!.play(AssetSource(track.assetPath.replaceFirst('assets/', '')));
  }

  void _onTick(Duration elapsed) {
    if (!_isPlaying) return;
    final dt = _lastTick == Duration.zero ? 0 : elapsed.inMilliseconds - _lastTick.inMilliseconds;
    _lastTick = elapsed;
    _globalTimeMs += dt;

    if (_globalTimeMs >= widget.choreography.totalDurationMs) {
      _globalTimeMs = widget.choreography.totalDurationMs;
      _pause();
    }

    _evaluate();
    _ensurePlayersMatchFrame();
    widget.onPositionChanged?.call(_globalTimeMs);
  }

  // ------------------------------------------------------------------
  // Scene evaluation
  // ------------------------------------------------------------------

  void _evaluate() {
    final newFrame = _evaluator.evaluate(widget.choreography, _globalTimeMs);
    if (mounted) {
      setState(() => _frame = newFrame);
    }
  }

  // ------------------------------------------------------------------
  // Player management
  // ------------------------------------------------------------------

  Future<void> _loadClipIntoSlot(int clipIndex, int slotIndex) async {
    if (clipIndex < 0 || clipIndex >= widget.choreography.clips.length) return;
    final clip = widget.choreography.clips[clipIndex];
    final slot = _players[slotIndex];

    // Skip if already loaded.
    if (slot.clipIndex == clipIndex && slot.controller?.value.isInitialized == true) {
      return;
    }

    final old = slot.controller;
    final c = VideoPlayerController.file(File(clip.playbackPath));
    try {
      await c.initialize();
    } catch (_) {
      await c.dispose();
      return;
    }
    if (!mounted) {
      await c.dispose();
      return;
    }
    slot.controller = c;
    slot.clipIndex = clipIndex;
    await old?.dispose();
  }

  /// Make sure the right clips are loaded and seeked for the current frame.
  void _ensurePlayersMatchFrame() {
    final primary = _frame.primary;
    if (primary == null) return;

    final pSlot = _players[_primarySlotIndex];
    final sSlotIndex = 1 - _primarySlotIndex;
    final sSlot = _players[sSlotIndex];

    // Ensure primary slot has the right clip.
    if (pSlot.clipIndex != primary.clipIndex) {
      // Check if the secondary slot already has it (swap).
      if (sSlot.clipIndex == primary.clipIndex) {
        _primarySlotIndex = sSlotIndex;
      } else {
        _loadClipIntoSlot(primary.clipIndex, _primarySlotIndex);
      }
    }

    // Ensure secondary slot has the transition clip if needed.
    final secondary = _frame.secondary;
    if (secondary != null) {
      final otherIndex = 1 - _primarySlotIndex;
      if (_players[otherIndex].clipIndex != secondary.clipIndex) {
        _loadClipIntoSlot(secondary.clipIndex, otherIndex);
      }
    }

    // Pre-load next clip into the free slot when not in transition.
    if (secondary == null && primary.clipIndex + 1 < widget.choreography.clips.length) {
      final freeSlot = 1 - _primarySlotIndex;
      final nextIndex = primary.clipIndex + 1;
      if (_players[freeSlot].clipIndex != nextIndex) {
        _loadClipIntoSlot(nextIndex, freeSlot);
      }
    }
  }

  /// After a seek, sync player positions to the evaluated frame.
  Future<void> _syncPlayersToFrame() async {
    final primary = _frame.primary;
    if (primary == null) return;

    // Load primary if needed.
    if (_players[_primarySlotIndex].clipIndex != primary.clipIndex) {
      await _loadClipIntoSlot(primary.clipIndex, _primarySlotIndex);
    }
    final pCtrl = _players[_primarySlotIndex].controller;
    if (pCtrl?.value.isInitialized == true) {
      await pCtrl!.seekTo(Duration(milliseconds: primary.localPositionMs));
      if (!_isPlaying) await pCtrl.pause();
    }

    final secondary = _frame.secondary;
    if (secondary != null) {
      final sIdx = 1 - _primarySlotIndex;
      if (_players[sIdx].clipIndex != secondary.clipIndex) {
        await _loadClipIntoSlot(secondary.clipIndex, sIdx);
      }
      final sCtrl = _players[sIdx].controller;
      if (sCtrl?.value.isInitialized == true) {
        await sCtrl!.seekTo(Duration(milliseconds: secondary.localPositionMs));
        if (!_isPlaying) await sCtrl.pause();
      }
    }
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_frame.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text('Add videos to preview', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return Container(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Center(child: _buildVideoLayers(constraints.biggest)),
              _buildBadges(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideoLayers(Size viewSize) {
    final pCtrl = _players[_primarySlotIndex].controller;

    // Determine aspect ratio from the primary player.
    final aspect = pCtrl?.value.isInitialized == true
        ? pCtrl!.value.aspectRatio
        : 16 / 9;

    return AspectRatio(
      aspectRatio: aspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // --- Secondary (outgoing) during transition ---
          if (_frame.hasTransition) _buildSecondaryLayer(),

          // --- Primary (current / incoming) ---
          _buildPrimaryLayer(),

          // --- Overlay layer (text + stickers) ---
          _buildOverlayLayer(),
        ],
      ),
    );
  }

  Widget _buildPrimaryLayer() {
    final primary = _frame.primary!;
    final pCtrl = _players[_primarySlotIndex].controller;
    Widget video = _videoWidget(pCtrl);

    // Apply color filter.
    final cf = colorFilterFor(primary.filter);
    if (cf != null) {
      video = ColorFiltered(colorFilter: cf, child: video);
    }

    // Apply transition to the incoming (primary) layer.
    if (_frame.hasTransition) {
      final trans = _frame.transition!;
      final type = trans.type;
      final progress = trans.progress;

      if (type == TransitionType.fade) {
        video = Opacity(opacity: progress, child: video);
      } else if (_isSlide(type)) {
        video = LayoutBuilder(
          builder: (ctx, c) {
            final offset = slideInOffset(type, progress, c.biggest);
            return Transform.translate(offset: offset, child: video);
          },
        );
      } else {
        // Clip-based transitions (wipe, zoom, circle).
        video = LayoutBuilder(
          builder: (ctx, c) {
            final clipper = clipperForTransition(type, progress, c.biggest);
            if (clipper == null) return video;
            return ClipPath(clipper: clipper, child: video);
          },
        );
      }
    }

    return video;
  }

  Widget _buildSecondaryLayer() {
    final secondary = _frame.secondary!;
    final sIdx = 1 - _primarySlotIndex;
    final sCtrl = _players[sIdx].controller;
    Widget video = _videoWidget(sCtrl);

    // Apply color filter.
    final cf = colorFilterFor(secondary.filter);
    if (cf != null) {
      video = ColorFiltered(colorFilter: cf, child: video);
    }

    // Apply outgoing transition offset.
    final trans = _frame.transition!;
    final type = trans.type;
    final progress = trans.progress;

    if (type == TransitionType.fade) {
      video = Opacity(opacity: 1.0 - progress, child: video);
    } else if (_isSlide(type)) {
      video = LayoutBuilder(
        builder: (ctx, c) {
          final offset = slideOutOffset(type, progress, c.biggest);
          return Transform.translate(offset: offset, child: video);
        },
      );
    }
    // For wipe/zoom/circle the outgoing stays fully visible behind the clip mask.

    return video;
  }

  Widget _videoWidget(VideoPlayerController? ctrl) {
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: ctrl.value.size.width,
          height: ctrl.value.size.height,
          child: VideoPlayer(ctrl),
        ),
      ),
    );
  }

  bool _isSlide(TransitionType t) =>
      t == TransitionType.slideLeft ||
      t == TransitionType.slideRight ||
      t == TransitionType.slideUp ||
      t == TransitionType.slideDown;

  Widget _buildOverlayLayer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final videoSize = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.readOnly ? null : () => setState(() => _selectedOverlayIndex = null),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Text overlays
              for (var i = 0; i < _frame.textOverlays.length; i++)
                _buildTextOverlay(i, videoSize),

              // Stickers
              for (final s in _frame.stickers)
                Positioned(
                  left: s.sticker.x * videoSize.width,
                  top: s.sticker.y * videoSize.height,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: Text(
                      s.sticker.emoji,
                      style: TextStyle(fontSize: 32 * s.sticker.scale),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextOverlay(int frameOverlayIndex, Size videoSize) {
    final active = _frame.textOverlays[frameOverlayIndex];
    final overlay = active.overlay;
    final selected = !widget.readOnly && _selectedOverlayIndex == frameOverlayIndex;
    final baseFontSize = (videoSize.width / 12).clamp(14.0, 60.0) * active.scale;

    return Positioned(
      left: active.x * videoSize.width,
      top: active.y * videoSize.height,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.readOnly
              ? null
              : () => setState(() => _selectedOverlayIndex = frameOverlayIndex),
          onPanUpdate: widget.readOnly || widget.onClipEffectsChanged == null
              ? null
              : (details) {
                  final ci = _frame.primary?.clipIndex;
                  if (ci == null) return;
                  final clip = widget.choreography.clips[ci];
                  // Find which overlay in clip.effects this corresponds to.
                  final overlayIndex = _resolveOverlayIndex(ci, overlay);
                  if (overlayIndex < 0) return;
                  final newX = (overlay.x + details.delta.dx / videoSize.width).clamp(0.05, 0.95);
                  final newY = (overlay.y + details.delta.dy / videoSize.height).clamp(0.05, 0.95);
                  final newOverlays = List<TextOverlay>.from(clip.effects.textOverlays);
                  newOverlays[overlayIndex] = overlay.copyWith(x: newX, y: newY);
                  widget.onClipEffectsChanged!(ci, clip.effects.copyWith(textOverlays: newOverlays));
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
                        final ci = _frame.primary?.clipIndex;
                        if (ci == null) return;
                        final clip = widget.choreography.clips[ci];
                        final overlayIndex = _resolveOverlayIndex(ci, overlay);
                        if (overlayIndex < 0) return;
                        final newOverlays = List<TextOverlay>.from(clip.effects.textOverlays)
                          ..removeAt(overlayIndex);
                        widget.onClipEffectsChanged!(ci, clip.effects.copyWith(textOverlays: newOverlays));
                        setState(() => _selectedOverlayIndex = null);
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
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

  /// Map a scene-frame overlay back to its index in the clip's effects list.
  int _resolveOverlayIndex(int clipIndex, TextOverlay overlay) {
    final clip = widget.choreography.clips[clipIndex];
    for (int i = 0; i < clip.effects.textOverlays.length; i++) {
      if (identical(clip.effects.textOverlays[i], overlay)) return i;
    }
    // Fallback: match by text + style.
    for (int i = 0; i < clip.effects.textOverlays.length; i++) {
      final o = clip.effects.textOverlays[i];
      if (o.text == overlay.text && o.style == overlay.style) return i;
    }
    return -1;
  }

  Widget _buildBadges() {
    return Positioned(
      top: 8,
      left: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
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
                  Text('Stabilized', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Internal bookkeeping for one player in the two-player pool.
class _PlayerSlot {
  VideoPlayerController? controller;
  int clipIndex = -1;

  Future<void> dispose() async {
    await controller?.dispose();
    controller = null;
    clipIndex = -1;
  }
}
