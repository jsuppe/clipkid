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

class ClipEffects {
  final bool stabilize;
  final double? stabilizeStrength; // 0.0 - 1.0, default 0.5
  final double speed; // 0.25 - 4.0, default 1.0
  final bool styled; // AI style transfer applied
  final String? styleName; // Name of the applied style
  final bool reverse; // Play backwards
  final VideoFilter filter; // Color filter preset
  final List<StickerOverlay> stickers; // Emoji/sticker overlays

  ClipEffects({
    this.stabilize = false,
    this.stabilizeStrength,
    this.speed = 1.0,
    this.styled = false,
    this.styleName,
    this.reverse = false,
    this.filter = VideoFilter.none,
    this.stickers = const [],
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
  }) : trim = trim ?? ClipTrim(inPointMs: 0, outPointMs: sourceDurationMs),
       segments = segments ?? [],
       effects = effects ?? ClipEffects();

  /// Get the effective segments (uses segments list if non-empty, otherwise wraps trim)
  List<ClipTrim> get effectiveSegments => 
      segments.isNotEmpty ? segments : [trim];

  /// Duration in timeline (after trim/segments and speed adjustment)
  int get durationMs {
    final totalTrimmed = effectiveSegments.fold<int>(0, (sum, s) => sum + s.durationMs);
    return (totalTrimmed / effects.speed).round();
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
