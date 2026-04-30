import 'dart:convert';

/// Trim points for a clip (in milliseconds, relative to source video)
class ClipTrim {
  final int inPointMs;  // Start point in source video
  final int outPointMs; // End point in source video

  ClipTrim({
    this.inPointMs = 0,
    required this.outPointMs,
  });

  /// Duration after trim
  int get durationMs => outPointMs - inPointMs;

  Map<String, dynamic> toJson() => {
        'in': inPointMs,
        'out': outPointMs,
      };

  factory ClipTrim.fromJson(Map<String, dynamic> json) => ClipTrim(
        inPointMs: json['in'] as int? ?? 0,
        outPointMs: json['out'] as int,
      );

  ClipTrim copyWith({
    int? inPointMs,
    int? outPointMs,
  }) =>
      ClipTrim(
        inPointMs: inPointMs ?? this.inPointMs,
        outPointMs: outPointMs ?? this.outPointMs,
      );
}

/// Effects that can be applied to a clip
/// Filter presets for video
enum VideoFilter {
  none('None', ''),
  sunny('Sunny ☀️', 'eq=brightness=0.1:saturation=1.3'),
  cool('Cool 🧊', 'colorbalance=bs=0.3:bm=0.1'),
  warm('Warm 🔥', 'colorbalance=rs=0.2:gs=0.1'),
  vintage('Vintage 📷', 'curves=vintage'),
  dramatic('Dramatic 🎭', 'eq=contrast=1.3:brightness=-0.05:saturation=0.8'),
  blackWhite('B&W ⬛', 'hue=s=0'),
  spooky('Spooky 👻', 'eq=brightness=-0.1:saturation=0.5,hue=h=20');

  final String displayName;
  final String ffmpegFilter;
  const VideoFilter(this.displayName, this.ffmpegFilter);
}

/// A sticker overlay on a clip
class StickerOverlay {
  final String emoji;
  final double x; // 0.0 - 1.0 (percentage of width)
  final double y; // 0.0 - 1.0 (percentage of height)
  final double scale; // 0.5 - 3.0
  final int startMs; // When to show (relative to clip)
  final int? endMs; // When to hide (null = whole clip)

  StickerOverlay({
    required this.emoji,
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 1.0,
    this.startMs = 0,
    this.endMs,
  });

  Map<String, dynamic> toJson() => {
    'emoji': emoji,
    'x': x,
    'y': y,
    'scale': scale,
    'startMs': startMs,
    if (endMs != null) 'endMs': endMs,
  };

  factory StickerOverlay.fromJson(Map<String, dynamic> json) => StickerOverlay(
    emoji: json['emoji'] as String,
    x: (json['x'] as num?)?.toDouble() ?? 0.5,
    y: (json['y'] as num?)?.toDouble() ?? 0.5,
    scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
    startMs: json['startMs'] as int? ?? 0,
    endMs: json['endMs'] as int?,
  );

  StickerOverlay copyWith({
    String? emoji,
    double? x,
    double? y,
    double? scale,
    int? startMs,
    int? endMs,
  }) => StickerOverlay(
    emoji: emoji ?? this.emoji,
    x: x ?? this.x,
    y: y ?? this.y,
    scale: scale ?? this.scale,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
  );
}

/// A sound effect placed at a specific time in a clip.
class SoundEffectOverlay {
  final String effectId; // key into kSoundEffects
  final int startMs; // when to play (relative to clip start)
  final double volume; // 0.0 - 1.0

  SoundEffectOverlay({
    required this.effectId,
    required this.startMs,
    this.volume = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'effectId': effectId,
    'startMs': startMs,
    'volume': volume,
  };

  factory SoundEffectOverlay.fromJson(Map<String, dynamic> json) =>
      SoundEffectOverlay(
        effectId: json['effectId'] as String,
        startMs: json['startMs'] as int? ?? 0,
        volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      );

  SoundEffectOverlay copyWith({String? effectId, int? startMs, double? volume}) =>
      SoundEffectOverlay(
        effectId: effectId ?? this.effectId,
        startMs: startMs ?? this.startMs,
        volume: volume ?? this.volume,
      );
}

/// Voice effect preset applied to clip audio during export.
enum VoiceEffect {
  none('None', '', ''),
  robot('Robot 🤖', 'asetrate=22050,atempo=2.0,aformat=sample_fmts=fltp', 'Metallic and mechanical'),
  chipmunk('Chipmunk 🐿️', 'asetrate=65100,atempo=0.675,aformat=sample_fmts=fltp', 'High-pitched and fast'),
  deep('Deep 🎸', 'asetrate=32000,atempo=1.378,aformat=sample_fmts=fltp', 'Low and booming'),
  echo('Echo 🏔️', 'aecho=0.8:0.88:60:0.4', 'Reverberating echo'),
  alien('Alien 👽', 'vibrato=f=7:d=0.5,aecho=0.8:0.7:40:0.3', 'Wobbly and otherworldly');

  final String displayName;
  final String ffmpegFilter;
  final String description;
  const VoiceEffect(this.displayName, this.ffmpegFilter, this.description);
}

/// Speed ramp preset — variable speed within a clip.
enum SpeedRamp {
  none('None', 'No speed change'),
  slowStart('Slow Start 🐢➡️🐇', 'Starts slow, speeds up to normal'),
  slowEnd('Slow End 🐇➡️🐢', 'Normal speed, slows at the end'),
  speedBurst('Speed Burst ⚡', 'Slow → fast → slow'),
  dramaticSlowmo('Dramatic Slowmo 🎭', 'Normal → super slow → normal');

  final String displayName;
  final String description;
  const SpeedRamp(this.displayName, this.description);
}

/// Chroma key (green screen) settings.
class ChromaKeySettings {
  final double hue; // 0-360 (120 = green, 240 = blue)
  final double similarity; // 0.0-1.0 (how close to target color)
  final double blend; // 0.0-1.0 (edge smoothing)
  final String? backgroundPath; // null = transparent/black

  const ChromaKeySettings({
    this.hue = 120, // green by default
    this.similarity = 0.3,
    this.blend = 0.1,
    this.backgroundPath,
  });

  String get ffmpegFilter =>
      'chromakey=0x${_hueToHex(hue)}:${similarity.toStringAsFixed(2)}:${blend.toStringAsFixed(2)}';

  static String _hueToHex(double hue) {
    // Convert HSL hue to hex color for ffmpeg chromakey
    if (hue >= 100 && hue <= 140) return '00FF00'; // green
    if (hue >= 220 && hue <= 260) return '0000FF'; // blue
    if (hue >= 340 || hue <= 20) return 'FF0000'; // red
    return '00FF00'; // default green
  }

  Map<String, dynamic> toJson() => {
    'hue': hue,
    'similarity': similarity,
    'blend': blend,
    if (backgroundPath != null) 'backgroundPath': backgroundPath,
  };

  factory ChromaKeySettings.fromJson(Map<String, dynamic> json) =>
      ChromaKeySettings(
        hue: (json['hue'] as num?)?.toDouble() ?? 120,
        similarity: (json['similarity'] as num?)?.toDouble() ?? 0.3,
        blend: (json['blend'] as num?)?.toDouble() ?? 0.1,
        backgroundPath: json['backgroundPath'] as String?,
      );

  ChromaKeySettings copyWith({double? hue, double? similarity, double? blend, String? backgroundPath}) =>
      ChromaKeySettings(
        hue: hue ?? this.hue,
        similarity: similarity ?? this.similarity,
        blend: blend ?? this.blend,
        backgroundPath: backgroundPath ?? this.backgroundPath,
      );
}

/// Transition between two consecutive clips.
/// Each preset maps to an ffmpeg xfade transition name.
enum TransitionType {
  none('Cut ✂️', '', 0),
  fade('Fade 🌫️', 'fade', 500),
  slideLeft('Slide ⬅️', 'slideleft', 500),
  slideRight('Slide ➡️', 'slideright', 500),
  slideUp('Slide ⬆️', 'slideup', 500),
  slideDown('Slide ⬇️', 'slidedown', 500),
  wipe('Wipe 🧹', 'wipeleft', 500),
  zoom('Zoom 🔍', 'zoomin', 500),
  circleClose('Circle ⭕', 'circleclose', 500);

  final String displayName;
  final String xfadeName; // ffmpeg xfade transition identifier
  final int defaultDurationMs;
  const TransitionType(this.displayName, this.xfadeName, this.defaultDurationMs);
}

/// A transition applied between this clip and the next one.
class Transition {
  final TransitionType type;
  final int durationMs;

  const Transition({
    this.type = TransitionType.none,
    this.durationMs = 500,
  });

  bool get isNone => type == TransitionType.none;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'durationMs': durationMs,
      };

  factory Transition.fromJson(Map<String, dynamic> json) => Transition(
        type: TransitionType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => TransitionType.none,
        ),
        durationMs: json['durationMs'] as int? ?? 500,
      );

  Transition copyWith({TransitionType? type, int? durationMs}) => Transition(
        type: type ?? this.type,
        durationMs: durationMs ?? this.durationMs,
      );
}

/// Preset style for a text overlay. Each preset bakes in font, color,
/// stroke, shadow, default position, and default size — kids pick ONE
/// look instead of fiddling with a dozen parameters.
enum TextStylePreset {
  title('Title ⭐'),
  bubble('Bubble 💭'),
  comic('Comic 💥'),
  rainbow('Rainbow 🌈'),
  spooky('Spooky 👻'),
  neon('Neon ⚡'),
  caption('Caption 💬'),
  handwritten('Handwritten ✏️');

  final String displayName;
  const TextStylePreset(this.displayName);
}

/// Where to place a Picture-in-Picture overlay on the main clip.
enum PipPosition {
  topLeft('Top Left ↖️'),
  topRight('Top Right ↗️'),
  bottomLeft('Bottom Left ↙️'),
  bottomRight('Bottom Right ↘️');

  final String displayName;
  const PipPosition(this.displayName);
}

/// When a text overlay is visible within its clip.
enum OverlayTiming {
  wholeClip('Whole clip 🕐'),
  firstTwoSeconds('First 2 seconds ⏱️'),
  lastTwoSeconds('Last 2 seconds ⏱️'),
  customRange('Custom range 🎯');

  final String displayName;
  const OverlayTiming(this.displayName);
}

/// A text overlay on a clip.
class TextOverlay {
  final String text;
  final TextStylePreset style;
  final double x; // 0.0 - 1.0 (normalized position)
  final double y; // 0.0 - 1.0 (normalized position)
  final double scale; // 0.5 - 3.0 (relative size)
  final OverlayTiming timing;
  // Used only when timing == customRange; milliseconds relative to clip start.
  final int? customStartMs;
  final int? customEndMs;

  TextOverlay({
    required this.text,
    this.style = TextStylePreset.title,
    double? x,
    double? y,
    this.scale = 1.0,
    this.timing = OverlayTiming.wholeClip,
    this.customStartMs,
    this.customEndMs,
  })  : x = x ?? _defaultX(style),
        y = y ?? _defaultY(style);

  // Default positions per style — Title goes top, Caption goes bottom, etc.
  static double _defaultX(TextStylePreset style) => 0.5;
  static double _defaultY(TextStylePreset style) {
    switch (style) {
      case TextStylePreset.title:
        return 0.2;
      case TextStylePreset.caption:
        return 0.85;
      default:
        return 0.5;
    }
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'style': style.name,
        'x': x,
        'y': y,
        'scale': scale,
        'timing': timing.name,
        if (customStartMs != null) 'customStartMs': customStartMs,
        if (customEndMs != null) 'customEndMs': customEndMs,
      };

  factory TextOverlay.fromJson(Map<String, dynamic> json) => TextOverlay(
        text: json['text'] as String,
        style: TextStylePreset.values.firstWhere(
          (s) => s.name == json['style'],
          orElse: () => TextStylePreset.title,
        ),
        x: (json['x'] as num?)?.toDouble(),
        y: (json['y'] as num?)?.toDouble(),
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        timing: OverlayTiming.values.firstWhere(
          (t) => t.name == json['timing'],
          orElse: () => OverlayTiming.wholeClip,
        ),
        customStartMs: json['customStartMs'] as int?,
        customEndMs: json['customEndMs'] as int?,
      );

  TextOverlay copyWith({
    String? text,
    TextStylePreset? style,
    double? x,
    double? y,
    double? scale,
    OverlayTiming? timing,
    int? customStartMs,
    int? customEndMs,
  }) =>
      TextOverlay(
        text: text ?? this.text,
        style: style ?? this.style,
        x: x ?? this.x,
        y: y ?? this.y,
        scale: scale ?? this.scale,
        timing: timing ?? this.timing,
        customStartMs: customStartMs ?? this.customStartMs,
        customEndMs: customEndMs ?? this.customEndMs,
      );
}

class ClipEffects {
  final bool stabilize;
  final double? stabilizeStrength; // 0.0 - 1.0, default 0.5
  final double speed; // 0.25 - 4.0, default 1.0
  final bool styled; // AI style transfer applied
  final String? styleName; // Name of the applied style
  final bool reverse; // Play backwards
  final VideoFilter filter; // Color filter preset
  final List<StickerOverlay> stickers; // Emoji/sticker overlays
  final List<TextOverlay> textOverlays; // Text overlays
  final int freezeEndMs; // Freeze last frame for this many ms (0 = no freeze)
  final String? backgroundRemovalPath; // Path to bg-removed clip if processed
  final String? pipPath; // Path to a clip that should play as Picture-in-Picture
  final PipPosition pipPosition;
  final List<SoundEffectOverlay> soundEffects; // Sound effects on timeline
  final VoiceEffect voiceEffect; // Voice changer preset
  final SpeedRamp speedRamp; // Speed ramp preset
  final ChromaKeySettings? chromaKey; // Green screen / chroma key

  const ClipEffects({
    this.stabilize = false,
    this.stabilizeStrength,
    this.speed = 1.0,
    this.styled = false,
    this.styleName,
    this.reverse = false,
    this.filter = VideoFilter.none,
    this.stickers = const [],
    this.textOverlays = const [],
    this.freezeEndMs = 0,
    this.backgroundRemovalPath,
    this.pipPath,
    this.pipPosition = PipPosition.bottomRight,
    this.soundEffects = const [],
    this.voiceEffect = VoiceEffect.none,
    this.speedRamp = SpeedRamp.none,
    this.chromaKey,
  });

  Map<String, dynamic> toJson() => {
        if (stabilize) 'stabilize': stabilize,
        if (stabilizeStrength != null) 'stabilizeStrength': stabilizeStrength,
        if (speed != 1.0) 'speed': speed,
        if (styled) 'styled': styled,
        if (styleName != null) 'styleName': styleName,
        if (reverse) 'reverse': reverse,
        if (filter != VideoFilter.none) 'filter': filter.name,
        if (stickers.isNotEmpty) 'stickers': stickers.map((s) => s.toJson()).toList(),
        if (textOverlays.isNotEmpty) 'textOverlays': textOverlays.map((t) => t.toJson()).toList(),
        if (freezeEndMs > 0) 'freezeEndMs': freezeEndMs,
        if (backgroundRemovalPath != null) 'backgroundRemovalPath': backgroundRemovalPath,
        if (pipPath != null) 'pipPath': pipPath,
        if (pipPath != null) 'pipPosition': pipPosition.name,
        if (soundEffects.isNotEmpty) 'soundEffects': soundEffects.map((s) => s.toJson()).toList(),
        if (voiceEffect != VoiceEffect.none) 'voiceEffect': voiceEffect.name,
        if (speedRamp != SpeedRamp.none) 'speedRamp': speedRamp.name,
        if (chromaKey != null) 'chromaKey': chromaKey!.toJson(),
      };

  factory ClipEffects.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ClipEffects();
    return ClipEffects(
      stabilize: json['stabilize'] as bool? ?? false,
      stabilizeStrength: (json['stabilizeStrength'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      styled: json['styled'] as bool? ?? false,
      styleName: json['styleName'] as String?,
      reverse: json['reverse'] as bool? ?? false,
      filter: VideoFilter.values.firstWhere(
        (f) => f.name == json['filter'],
        orElse: () => VideoFilter.none,
      ),
      stickers: (json['stickers'] as List<dynamic>?)
          ?.map((s) => StickerOverlay.fromJson(s as Map<String, dynamic>))
          .toList() ?? [],
      textOverlays: (json['textOverlays'] as List<dynamic>?)
          ?.map((t) => TextOverlay.fromJson(t as Map<String, dynamic>))
          .toList() ?? [],
      freezeEndMs: json['freezeEndMs'] as int? ?? 0,
      backgroundRemovalPath: json['backgroundRemovalPath'] as String?,
      pipPath: json['pipPath'] as String?,
      pipPosition: PipPosition.values.firstWhere(
        (p) => p.name == json['pipPosition'],
        orElse: () => PipPosition.bottomRight,
      ),
      soundEffects: (json['soundEffects'] as List<dynamic>?)
          ?.map((s) => SoundEffectOverlay.fromJson(s as Map<String, dynamic>))
          .toList() ?? [],
      voiceEffect: VoiceEffect.values.firstWhere(
        (v) => v.name == json['voiceEffect'],
        orElse: () => VoiceEffect.none,
      ),
      speedRamp: SpeedRamp.values.firstWhere(
        (r) => r.name == json['speedRamp'],
        orElse: () => SpeedRamp.none,
      ),
      chromaKey: json['chromaKey'] != null
          ? ChromaKeySettings.fromJson(json['chromaKey'] as Map<String, dynamic>)
          : null,
    );
  }

  ClipEffects copyWith({
    bool? stabilize,
    double? stabilizeStrength,
    double? speed,
    bool? styled,
    String? styleName,
    bool? reverse,
    VideoFilter? filter,
    List<StickerOverlay>? stickers,
    List<TextOverlay>? textOverlays,
    int? freezeEndMs,
    String? backgroundRemovalPath,
    String? pipPath,
    PipPosition? pipPosition,
    List<SoundEffectOverlay>? soundEffects,
    VoiceEffect? voiceEffect,
    SpeedRamp? speedRamp,
    ChromaKeySettings? chromaKey,
  }) =>
      ClipEffects(
        stabilize: stabilize ?? this.stabilize,
        stabilizeStrength: stabilizeStrength ?? this.stabilizeStrength,
        speed: speed ?? this.speed,
        styled: styled ?? this.styled,
        styleName: styleName ?? this.styleName,
        reverse: reverse ?? this.reverse,
        filter: filter ?? this.filter,
        stickers: stickers ?? this.stickers,
        textOverlays: textOverlays ?? this.textOverlays,
        freezeEndMs: freezeEndMs ?? this.freezeEndMs,
        backgroundRemovalPath: backgroundRemovalPath ?? this.backgroundRemovalPath,
        pipPath: pipPath ?? this.pipPath,
        pipPosition: pipPosition ?? this.pipPosition,
        soundEffects: soundEffects ?? this.soundEffects,
        voiceEffect: voiceEffect ?? this.voiceEffect,
        speedRamp: speedRamp ?? this.speedRamp,
        chromaKey: chromaKey ?? this.chromaKey,
      );
}

/// Represents a single video clip in the choreography
class Clip {
  final String id;
  final String path;
  final String? processedPath; // Path to processed version (stabilized, etc.)
  final int startMs; // Start position in timeline (milliseconds)
  final int sourceDurationMs; // Original duration of source video
  final ClipTrim trim; // Legacy single trim (used if segments is empty)
  final List<ClipTrim> segments; // Multiple keep segments (takes precedence over trim)
  final String? name;
  final ClipEffects effects;
  final Transition outgoingTransition; // Transition to the next clip (last clip's ignored)

  Clip({
    required this.id,
    required this.path,
    this.processedPath,
    required this.startMs,
    required this.sourceDurationMs,
    ClipTrim? trim,
    List<ClipTrim>? segments,
    this.name,
    ClipEffects? effects,
    this.outgoingTransition = const Transition(),
  }) : trim = trim ?? ClipTrim(inPointMs: 0, outPointMs: sourceDurationMs),
       segments = segments ?? [],
       effects = effects ?? ClipEffects();

  /// Get the effective segments (uses segments list if non-empty, otherwise wraps trim)
  List<ClipTrim> get effectiveSegments => 
      segments.isNotEmpty ? segments : [trim];

  /// Duration in timeline (after trim/segments, speed adjustment, and freeze)
  int get durationMs {
    final totalTrimmed = effectiveSegments.fold<int>(0, (sum, s) => sum + s.durationMs);
    final base = (totalTrimmed / effects.speed).round();
    return base + effects.freezeEndMs;
  }

  /// The path to use for playback (processed if available, otherwise original)
  String get playbackPath => processedPath ?? path;

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        if (processedPath != null) 'processedPath': processedPath,
        'start': startMs,
        'sourceDuration': sourceDurationMs,
        'trim': trim.toJson(),
        if (segments.isNotEmpty) 'segments': segments.map((s) => s.toJson()).toList(),
        if (name != null) 'name': name,
        'effects': effects.toJson(),
        if (!outgoingTransition.isNone) 'transition': outgoingTransition.toJson(),
      };

  factory Clip.fromJson(Map<String, dynamic> json) {
    final sourceDuration = json['sourceDuration'] as int? ?? json['duration'] as int;
    return Clip(
        id: json['id'] as String,
        path: json['path'] as String,
        processedPath: json['processedPath'] as String?,
        startMs: json['start'] as int,
        sourceDurationMs: sourceDuration,
        trim: json['trim'] != null 
            ? ClipTrim.fromJson(json['trim'] as Map<String, dynamic>)
            : ClipTrim(inPointMs: 0, outPointMs: sourceDuration),
        segments: (json['segments'] as List<dynamic>?)
            ?.map((s) => ClipTrim.fromJson(s as Map<String, dynamic>))
            .toList() ?? [],
        name: json['name'] as String?,
        effects: ClipEffects.fromJson(json['effects'] as Map<String, dynamic>?),
        outgoingTransition: json['transition'] != null
            ? Transition.fromJson(json['transition'] as Map<String, dynamic>)
            : const Transition(),
      );
  }

  /// End position in timeline
  int get endMs => startMs + durationMs;

  /// Whether this clip needs processing (has effects but no processed path)
  bool get needsProcessing => effects.stabilize && processedPath == null;

  /// Whether this clip has been trimmed from original
  bool get isTrimmed {
    if (segments.isNotEmpty) {
      // Multiple segments = definitely trimmed
      if (segments.length > 1) return true;
      // Single segment - check if it covers the whole video
      final s = segments.first;
      return s.inPointMs > 0 || s.outPointMs < sourceDurationMs;
    }
    return trim.inPointMs > 0 || trim.outPointMs < sourceDurationMs;
  }

  /// Whether this clip has multiple segments
  bool get hasMultipleSegments => segments.length > 1;

  Clip copyWith({
    String? id,
    String? path,
    String? processedPath,
    int? startMs,
    int? sourceDurationMs,
    ClipTrim? trim,
    List<ClipTrim>? segments,
    String? name,
    ClipEffects? effects,
    Transition? outgoingTransition,
  }) =>
      Clip(
        id: id ?? this.id,
        path: path ?? this.path,
        processedPath: processedPath ?? this.processedPath,
        startMs: startMs ?? this.startMs,
        sourceDurationMs: sourceDurationMs ?? this.sourceDurationMs,
        trim: trim ?? this.trim,
        segments: segments ?? this.segments,
        name: name ?? this.name,
        effects: effects ?? this.effects,
        outgoingTransition: outgoingTransition ?? this.outgoingTransition,
      );
}

/// Built-in music tracks for kids
enum MusicTrack {
  none('None', ''),
  happy('Happy 🎉', 'assets/music/happy.mp3'),
  adventure('Adventure 🗺️', 'assets/music/adventure.mp3'),
  funny('Funny 🤣', 'assets/music/funny.mp3'),
  chill('Chill 😌', 'assets/music/chill.mp3'),
  epic('Epic 🦸', 'assets/music/epic.mp3'),
  spooky('Spooky 👻', 'assets/music/spooky.mp3');

  final String displayName;
  final String assetPath;
  const MusicTrack(this.displayName, this.assetPath);
}

/// The choreography - describes how clips are arranged
class Choreography {
  final int version;
  final List<Clip> clips;
  final String? name;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final MusicTrack musicTrack; // Background music
  final double musicVolume; // 0.0 - 1.0
  final bool keepOriginalAudio; // Mix with original or replace

  Choreography({
    this.version = 1,
    required this.clips,
    this.name,
    DateTime? createdAt,
    DateTime? modifiedAt,
    this.musicTrack = MusicTrack.none,
    this.musicVolume = 0.5,
    this.keepOriginalAudio = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        modifiedAt = modifiedAt ?? DateTime.now();

  /// Total duration of the choreography
  int get totalDurationMs {
    if (clips.isEmpty) return 0;
    return clips.map((c) => c.endMs).reduce((a, b) => a > b ? a : b);
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'clips': clips.map((c) => c.toJson()).toList(),
        if (name != null) 'name': name,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        if (musicTrack != MusicTrack.none) 'musicTrack': musicTrack.name,
        if (musicVolume != 0.5) 'musicVolume': musicVolume,
        if (!keepOriginalAudio) 'keepOriginalAudio': keepOriginalAudio,
      };

  factory Choreography.fromJson(Map<String, dynamic> json) => Choreography(
        version: json['version'] as int? ?? 1,
        clips: (json['clips'] as List)
            .map((c) => Clip.fromJson(c as Map<String, dynamic>))
            .toList(),
        name: json['name'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        modifiedAt: json['modifiedAt'] != null
            ? DateTime.parse(json['modifiedAt'] as String)
            : null,
        musicTrack: MusicTrack.values.firstWhere(
          (m) => m.name == json['musicTrack'],
          orElse: () => MusicTrack.none,
        ),
        musicVolume: (json['musicVolume'] as num?)?.toDouble() ?? 0.5,
        keepOriginalAudio: json['keepOriginalAudio'] as bool? ?? true,
      );
  
  Choreography copyWith({
    int? version,
    List<Clip>? clips,
    String? name,
    DateTime? createdAt,
    DateTime? modifiedAt,
    MusicTrack? musicTrack,
    double? musicVolume,
    bool? keepOriginalAudio,
  }) => Choreography(
    version: version ?? this.version,
    clips: clips ?? this.clips,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt ?? DateTime.now(),
    musicTrack: musicTrack ?? this.musicTrack,
    musicVolume: musicVolume ?? this.musicVolume,
    keepOriginalAudio: keepOriginalAudio ?? this.keepOriginalAudio,
  );

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory Choreography.fromJsonString(String jsonString) =>
      Choreography.fromJson(json.decode(jsonString) as Map<String, dynamic>);

  /// Create a new choreography with an additional clip appended
  Choreography addClip(Clip clip) {
    final newClip = clip.copyWith(startMs: totalDurationMs);
    return Choreography(
      version: version,
      clips: [...clips, newClip],
      name: name,
      createdAt: createdAt,
      modifiedAt: DateTime.now(),
    );
  }

  /// Create empty choreography
  factory Choreography.empty({String? name}) => Choreography(
        clips: [],
        name: name,
      );
}
