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
class ClipEffects {
  final bool stabilize;
  final double? stabilizeStrength; // 0.0 - 1.0, default 0.5
  final double speed; // 0.25 - 4.0, default 1.0

  ClipEffects({
    this.stabilize = false,
    this.stabilizeStrength,
    this.speed = 1.0,
  });

  Map<String, dynamic> toJson() => {
        if (stabilize) 'stabilize': stabilize,
        if (stabilizeStrength != null) 'stabilizeStrength': stabilizeStrength,
        if (speed != 1.0) 'speed': speed,
      };

  factory ClipEffects.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ClipEffects();
    return ClipEffects(
      stabilize: json['stabilize'] as bool? ?? false,
      stabilizeStrength: (json['stabilizeStrength'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
    );
  }

  ClipEffects copyWith({
    bool? stabilize,
    double? stabilizeStrength,
    double? speed,
  }) =>
      ClipEffects(
        stabilize: stabilize ?? this.stabilize,
        stabilizeStrength: stabilizeStrength ?? this.stabilizeStrength,
        speed: speed ?? this.speed,
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

/// The choreography - describes how clips are arranged
class Choreography {
  final int version;
  final List<Clip> clips;
  final String? name;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Choreography({
    this.version = 1,
    required this.clips,
    this.name,
    DateTime? createdAt,
    DateTime? modifiedAt,
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
