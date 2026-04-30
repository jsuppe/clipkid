import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../models/choreography.dart';
import '../screens/export_dialog.dart';
import 'overlay_renderer.dart';

/// Metadata for a rendered overlay that needs to be composited into the export.
class _OverlayExportJob {
  final RenderedOverlayPng png;
  final double xNormalized; // 0..1 within output frame
  final double yNormalized; // 0..1 within output frame
  final double startSec; // in final output timeline
  final double endSec;
  _OverlayExportJob({
    required this.png,
    required this.xNormalized,
    required this.yNormalized,
    required this.startSec,
    required this.endSec,
  });
}

/// Callback for export progress (0.0 - 1.0)
typedef ExportProgressCallback = void Function(double progress, String status);

/// Service for exporting/rendering choreography to video file
class ExportService {
  /// Export choreography to MP4 file
  /// Returns the path to the exported video, or null if export failed
  static Future<String?> exportToMp4(
    Choreography choreography, {
    ExportProgressCallback? onProgress,
    String? outputFileName,
    ExportSettings? settings,
  }) async {
    final exportSettings = settings ?? ExportSettings();
    if (choreography.clips.isEmpty) {
      return null;
    }

    // Use app's cache directory for reliability (no permission issues)
    final dir = await getTemporaryDirectory();
    final exportDir = Directory('${dir.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = outputFileName ?? '${choreography.name ?? 'export'}_$timestamp';
    final safeFileName = fileName.replaceAll(RegExp(r'[^\w\-]'), '_');
    final outputPath = '${exportDir.path}/$safeFileName.mp4';

    onProgress?.call(0.0, 'Checking files...');

    // Verify all input files exist
    for (final clip in choreography.clips) {
      final file = File(clip.playbackPath);
      if (!await file.exists()) {
        print('=== INPUT FILE MISSING ===');
        print('Path: ${clip.playbackPath}');
        onProgress?.call(0.0, 'Source file missing');
        return null;
      }
    }

    onProgress?.call(0.05, 'Preparing export...');

    // Render text overlays to PNG files (WYSIWYG with preview)
    final overlayJobs = await _prepareOverlayJobs(choreography, exportSettings);

    // Pre-extract sound effect assets to temp files for ffmpeg
    final sfxPaths = <String, String>{};
    for (final clip in choreography.clips) {
      for (final sfx in clip.effects.soundEffects) {
        if (!sfxPaths.containsKey(sfx.effectId)) {
          try {
            sfxPaths[sfx.effectId] = await _extractAssetToTemp('sounds/${sfx.effectId}.wav');
          } catch (_) {} // skip missing effects
        }
      }
    }

    try {
      // Build FFmpeg command
      final command = _buildExportCommand(
        choreography,
        outputPath,
        exportSettings,
        overlayJobs,
        sfxPaths: sfxPaths,
      );
      print('=== EXPORT COMMAND ===');
      print(command);

      onProgress?.call(0.1, 'Starting FFmpeg...');

      // Execute synchronously for better error handling
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        onProgress?.call(1.0, 'Export complete!');
        // Clean up overlay PNGs
        await OverlayRenderer.cleanup(overlayJobs.map((j) => j.png).toList());
        return outputPath;
      } else {
        final logs = await session.getLogsAsString();
        print('=== EXPORT FAILED ===');
        print('Command: $command');
        print('Logs: $logs');
        onProgress?.call(0.0, 'Export failed');
        await OverlayRenderer.cleanup(overlayJobs.map((j) => j.png).toList());
        return null;
      }
    } catch (e, stack) {
      print('=== EXPORT ERROR ===');
      print('Error: $e');
      print('Stack: $stack');
      onProgress?.call(0.0, 'Export error: $e');
      await OverlayRenderer.cleanup(overlayJobs.map((j) => j.png).toList());
      return null;
    }
  }

  /// Render all text overlays in the choreography to PNG files and compute
  /// their timing in the output timeline (accounting for cross-clip transitions).
  static Future<List<_OverlayExportJob>> _prepareOverlayJobs(
    Choreography choreography,
    ExportSettings settings,
  ) async {
    final jobs = <_OverlayExportJob>[];
    final quality = settings.quality;

    // Compute output-timeline (start, end) for each clip, accounting for
    // transition overlaps with the previous clip.
    final clipTimings = <(double start, double end)>[];
    double cursor = 0;
    for (int i = 0; i < choreography.clips.length; i++) {
      final clip = choreography.clips[i];
      final durationSec = clip.durationMs / 1000.0;
      final startAt = cursor;
      final endAt = startAt + durationSec;
      clipTimings.add((startAt, endAt));
      // Next clip starts earlier if this clip has an outgoing transition
      final transitionSec = clip.outgoingTransition.isNone
          ? 0.0
          : clip.outgoingTransition.durationMs / 1000.0;
      cursor = endAt - transitionSec;
    }

    // Walk each clip's text overlays and render them
    for (int i = 0; i < choreography.clips.length; i++) {
      final clip = choreography.clips[i];
      final (clipStart, clipEnd) = clipTimings[i];
      for (final overlay in clip.effects.textOverlays) {
        double startSec;
        double endSec;
        switch (overlay.timing) {
          case OverlayTiming.wholeClip:
            startSec = clipStart;
            endSec = clipEnd;
            break;
          case OverlayTiming.firstTwoSeconds:
            startSec = clipStart;
            endSec = clipStart + 2.0;
            break;
          case OverlayTiming.lastTwoSeconds:
            startSec = clipEnd - 2.0;
            endSec = clipEnd;
            break;
          case OverlayTiming.customRange:
            final startOffset = (overlay.customStartMs ?? 0) / 1000.0;
            final endOffset =
                (overlay.customEndMs ?? clip.durationMs) / 1000.0;
            startSec = clipStart + startOffset;
            endSec = clipStart + endOffset;
            break;
        }

        final png = await OverlayRenderer.renderTextOverlayToPng(
          overlay,
          videoWidth: quality.width,
        );
        jobs.add(_OverlayExportJob(
          png: png,
          xNormalized: overlay.x,
          yNormalized: overlay.y,
          startSec: startSec,
          endSec: endSec,
        ));
      }
    }
    return jobs;
  }

  /// Debug: Get the FFmpeg command that would be used
  static String getExportCommand(Choreography choreography, ExportSettings settings) {
    return _buildExportCommand(choreography, '/tmp/output.mp4', settings, []);
  }

  /// Build FFmpeg command for concatenating clips with their trims/effects
  /// Supports multiple segments per clip and cross-clip transitions.
  static String _buildExportCommand(
    Choreography choreography,
    String outputPath,
    ExportSettings settings,
    List<_OverlayExportJob> overlayJobs, {
    Map<String, String> sfxPaths = const {},
  }) {
    final clips = choreography.clips;
    final quality = settings.quality;

    // Flatten all segments from all clips into a list of (path, segment, clipIndex) tuples
    final allSegments = <_ExportSegment>[];
    for (int ci = 0; ci < clips.length; ci++) {
      final clip = clips[ci];
      for (final segment in clip.effectiveSegments) {
        allSegments.add(_ExportSegment(clip.playbackPath, segment, ci));
      }
    }

    // Single segment + no overlays = direct passthrough (fastest path)
    if (allSegments.length == 1 && overlayJobs.isEmpty) {
      final seg = allSegments[0];
      final inSec = seg.segment.inPointMs / 1000.0;
      final duration = seg.segment.durationMs / 1000.0;

      final audioArgs = settings.includeAudio ? '-c:a aac -b:a 128k -ac 2' : '-an';

      return '-y -ss $inSec -t $duration -i "${seg.path}" '
          '-vf "scale=${quality.width}:${quality.height}:force_original_aspect_ratio=decrease,pad=${quality.width}:${quality.height}:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p" '
          '-c:v libx264 -preset fast -crf ${quality.crf} $audioArgs '
          '-movflags +faststart "$outputPath"';
    }

    // Build inputs and per-segment scale filters
    final inputs = StringBuffer();
    final filterParts = <String>[];

    for (int i = 0; i < allSegments.length; i++) {
      final seg = allSegments[i];
      final clip = clips[seg.clipIndex];
      final inSec = seg.segment.inPointMs / 1000.0;
      final duration = seg.segment.durationMs / 1000.0;
      inputs.write('-ss $inSec -t $duration -i "${seg.path}" ');

      // Base video filter: scale + pad + per-clip effects (chroma key, color filter, speed ramp)
      final extraVideoFilters = _clipVideoFilters(clip);
      filterParts.add(
        '[$i:v]scale=${quality.width}:${quality.height}:force_original_aspect_ratio=decrease,pad=${quality.width}:${quality.height}:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p,fps=30${extraVideoFilters}[v$i]',
      );
    }

    // PIP inputs — one per clip that has a PIP set. They're looped so they
    // cover the entire clip duration.
    final pipClipIndices = <int>[];
    for (int ci = 0; ci < clips.length; ci++) {
      if (clips[ci].effects.pipPath != null &&
          File(clips[ci].effects.pipPath!).existsSync()) {
        pipClipIndices.add(ci);
        inputs.write('-stream_loop -1 -i "${clips[ci].effects.pipPath}" ');
      }
    }

    // Detect if any cross-clip transitions are set (non-none)
    final hasTransitions = clips.any((c) => !c.outgoingTransition.isNone);

    String outputLabel;

    if (allSegments.length == 1) {
      // Single segment — no concat needed, use the scaled stream directly
      outputLabel = '[v0]';
    } else if (!hasTransitions) {
      // Simple concat (legacy path)
      final concatInputs = List.generate(allSegments.length, (i) => '[v$i]').join();
      filterParts.add('${concatInputs}concat=n=${allSegments.length}:v=1:a=0[outv]');
      outputLabel = '[outv]';
    } else {
      // xfade chain — first concat segments WITHIN a clip (if any),
      // apply freeze-frame padding, then xfade between consecutive clips.
      final clipVideoLabels = <String>[]; // label of each clip's final video stream
      final clipDurationsSec = <double>[]; // each clip's final duration in the output timeline

      int segIndex = 0;
      for (int ci = 0; ci < clips.length; ci++) {
        final clip = clips[ci];
        final segs = clip.effectiveSegments;
        final segDuration = segs.fold<int>(0, (sum, s) => sum + s.durationMs) / 1000.0;
        final freezeSec = clip.effects.freezeEndMs / 1000.0;
        clipDurationsSec.add(segDuration + freezeSec);

        String streamLabel;
        if (segs.length == 1) {
          streamLabel = '[v$segIndex]';
          segIndex += 1;
        } else {
          // Concat this clip's segments into [pN]
          final inputsJoin =
              List.generate(segs.length, (i) => '[v${segIndex + i}]').join();
          filterParts.add('${inputsJoin}concat=n=${segs.length}:v=1:a=0[p$ci]');
          streamLabel = '[p$ci]';
          segIndex += segs.length;
        }

        // Apply freeze-frame padding if requested
        if (freezeSec > 0) {
          final freezeLabel = '[c$ci]';
          filterParts.add(
            '${streamLabel}tpad=stop_mode=clone:stop_duration=${freezeSec.toStringAsFixed(3)}$freezeLabel',
          );
          clipVideoLabels.add(freezeLabel);
        } else {
          clipVideoLabels.add(streamLabel);
        }
      }

      // Now chain xfade between consecutive clip labels
      String currentLabel = clipVideoLabels[0];
      double cumulativeOffset = 0;

      for (int ci = 0; ci < clips.length - 1; ci++) {
        final transition = clips[ci].outgoingTransition;
        final nextLabel = clipVideoLabels[ci + 1];
        final outLabel = '[x$ci]';

        // xfade requires a valid transition name — use fade with duration~0 for "none"
        final xfadeName =
            transition.isNone ? 'fade' : transition.type.xfadeName;
        final durationSec =
            transition.isNone ? 0.01 : transition.durationMs / 1000.0;

        // Offset = cumulative length so far minus this transition's duration
        cumulativeOffset += clipDurationsSec[ci] - durationSec;

        filterParts.add(
          '$currentLabel${nextLabel}xfade=transition=$xfadeName:duration=${durationSec.toStringAsFixed(3)}:offset=${cumulativeOffset.toStringAsFixed(3)}$outLabel',
        );
        currentLabel = outLabel;
      }

      outputLabel = currentLabel;
    }

    // Add PIP overlays. These are placed BEFORE text overlays so that text
    // can go on top of the PIP.
    if (pipClipIndices.isNotEmpty) {
      // Compute output-timeline (start, end) for each clip (accounting for
      // transitions) — same math as overlay timing.
      final clipTimings = <(double, double)>[];
      double cursor = 0;
      for (int ci = 0; ci < clips.length; ci++) {
        final clip = clips[ci];
        final duration = clip.durationMs / 1000.0;
        clipTimings.add((cursor, cursor + duration));
        final transitionSec = clip.outgoingTransition.isNone
            ? 0.0
            : clip.outgoingTransition.durationMs / 1000.0;
        cursor = cursor + duration - transitionSec;
      }

      int pipInputIdx = allSegments.length;
      String current = outputLabel;
      for (int pi = 0; pi < pipClipIndices.length; pi++) {
        final ci = pipClipIndices[pi];
        final clip = clips[ci];
        final (clipStart, clipEnd) = clipTimings[ci];
        final pipSize = (quality.width * 0.28).round();
        // Scale the PIP input
        filterParts.add('[$pipInputIdx:v]scale=$pipSize:-1[pip$pi]');

        // Compute position based on corner
        const margin = 24;
        String x, y;
        switch (clip.effects.pipPosition) {
          case PipPosition.topLeft:
            x = '$margin';
            y = '$margin';
            break;
          case PipPosition.topRight:
            x = 'W-w-$margin';
            y = '$margin';
            break;
          case PipPosition.bottomLeft:
            x = '$margin';
            y = 'H-h-$margin';
            break;
          case PipPosition.bottomRight:
            x = 'W-w-$margin';
            y = 'H-h-$margin';
            break;
        }

        final outLabel = '[pov$pi]';
        filterParts.add(
          '$current[pip$pi]overlay=x=$x:y=$y:enable=\'between(t,${clipStart.toStringAsFixed(3)},${clipEnd.toStringAsFixed(3)})\'$outLabel',
        );
        current = outLabel;
        pipInputIdx++;
      }
      outputLabel = current;
    }

    // Add overlay inputs and filter chain
    if (overlayJobs.isNotEmpty) {
      // Inputs so far: segment videos + PIP videos. Text overlay PNGs come next.
      final overlayStartIdx = allSegments.length + pipClipIndices.length;
      for (int oi = 0; oi < overlayJobs.length; oi++) {
        final job = overlayJobs[oi];
        // Loop the overlay image so it's available for the entire video
        inputs.write('-loop 1 -i "${job.png.path}" ');
      }

      String current = outputLabel;
      for (int oi = 0; oi < overlayJobs.length; oi++) {
        final job = overlayJobs[oi];
        final inputIdx = overlayStartIdx + oi;
        // Compute top-left pixel position from normalized center position
        final centerX = (job.xNormalized * quality.width).round();
        final centerY = (job.yNormalized * quality.height).round();
        final x = (centerX - job.png.width ~/ 2).clamp(0, quality.width);
        final y = (centerY - job.png.height ~/ 2).clamp(0, quality.height);
        final outLabel = oi == overlayJobs.length - 1 ? '[final]' : '[ov$oi]';
        filterParts.add(
          '$current[$inputIdx:v]overlay=x=$x:y=$y:enable=\'between(t,${job.startSec.toStringAsFixed(3)},${job.endSec.toStringAsFixed(3)})\'$outLabel',
        );
        current = outLabel;
      }
      outputLabel = current;
    }

    // Build audio: per-clip voice/speed filters, concat, mix in sound effects
    String audioMapping;
    if (!settings.includeAudio) {
      audioMapping = '-an';
    } else {
      // Compute output-timeline start for each clip (for sound effect timing)
      final clipOutputStarts = <double>[];
      double audioCursor = 0;
      for (int ci = 0; ci < clips.length; ci++) {
        clipOutputStarts.add(audioCursor);
        final dur = clips[ci].durationMs / 1000.0;
        final transSec = clips[ci].outgoingTransition.isNone
            ? 0.0
            : clips[ci].outgoingTransition.durationMs / 1000.0;
        audioCursor += dur - transSec;
      }

      // Collect all sound effects with absolute timing
      final sfxJobs = <(String effectId, double startSec, double volume)>[];
      for (int ci = 0; ci < clips.length; ci++) {
        for (final sfx in clips[ci].effects.soundEffects) {
          final absSec = clipOutputStarts[ci] + sfx.startMs / 1000.0;
          sfxJobs.add((sfx.effectId, absSec, sfx.volume));
        }
      }

      // Per-segment audio filters (voice changer, speed ramp)
      final hasAudioEffects = clips.any((c) =>
          c.effects.voiceEffect != VoiceEffect.none ||
          c.effects.speedRamp != SpeedRamp.none);

      String mainAudioLabel;

      if (allSegments.length == 1) {
        // Single segment
        final af = _clipAudioFilters(clips[0]);
        if (af.isNotEmpty) {
          filterParts.add('[0:a]${af}[amain]');
          mainAudioLabel = '[amain]';
        } else {
          mainAudioLabel = '[0:a]';
        }
      } else if (hasAudioEffects) {
        // Multi-segment with audio effects: filter each, then concat
        for (int i = 0; i < allSegments.length; i++) {
          final clip = clips[allSegments[i].clipIndex];
          final af = _clipAudioFilters(clip);
          if (af.isNotEmpty) {
            filterParts.add('[$i:a]${af}[a$i]');
          } else {
            filterParts.add('[$i:a]acopy[a$i]');
          }
        }
        final aConcat = List.generate(allSegments.length, (i) => '[a$i]').join();
        filterParts.add('${aConcat}concat=n=${allSegments.length}:v=0:a=1[amain]');
        mainAudioLabel = '[amain]';
      } else if (allSegments.length > 1) {
        // Multi-segment, no audio effects: simple concat
        final aConcat = List.generate(allSegments.length, (i) => '[$i:a]').join();
        filterParts.add('${aConcat}concat=n=${allSegments.length}:v=0:a=1[amain]');
        mainAudioLabel = '[amain]';
      } else {
        mainAudioLabel = '[0:a]';
      }

      // Mix in sound effects
      if (sfxJobs.isNotEmpty) {
        final sfxInputStart = allSegments.length + pipClipIndices.length +
            overlayJobs.length; // after all other inputs
        for (int si = 0; si < sfxJobs.length; si++) {
          final (effectId, startSec, volume) = sfxJobs[si];
          final sfxPath = sfxPaths[effectId];
          if (sfxPath == null) continue;
          inputs.write('-i "$sfxPath" ');
          final delayMs = (startSec * 1000).round();
          filterParts.add(
            '[${sfxInputStart + si}:a]volume=$volume,adelay=$delayMs|$delayMs[sfx$si]',
          );
        }
        final sfxLabels = List.generate(sfxJobs.length, (i) => '[sfx$i]').join();
        filterParts.add(
          '$mainAudioLabel${sfxLabels}amix=inputs=${sfxJobs.length + 1}:duration=longest[outa]',
        );
        audioMapping = '-map "[outa]" -c:a aac -b:a 128k -ac 2';
      } else if (mainAudioLabel != '[0:a]') {
        audioMapping = '-map "$mainAudioLabel" -c:a aac -b:a 128k -ac 2';
      } else {
        audioMapping = '-map 0:a? -c:a aac -b:a 128k -ac 2';
      }
    }

    final filterComplex = filterParts.join(';');

    return '-y ${inputs}-filter_complex "$filterComplex" -map "$outputLabel" $audioMapping '
        '-c:v libx264 -preset fast -crf ${quality.crf} '
        '-movflags +faststart "$outputPath"';
  }

  /// Get the exports directory
  static Future<Directory> getExportsDirectory() async {
    final dir = await getTemporaryDirectory();
    final exportDir = Directory('${dir.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir;
  }

  /// List all exported videos
  static Future<List<File>> listExports() async {
    final dir = await getExportsDirectory();
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.mp4'))
        .toList();
  }
}

/// Extract a Flutter asset to a temp file so ffmpeg can read it.
Future<String> _extractAssetToTemp(String assetPath) async {
  final dir = await getTemporaryDirectory();
  final fileName = assetPath.split('/').last;
  final tempFile = File('${dir.path}/sfx_$fileName');
  if (!await tempFile.exists()) {
    final data = await rootBundle.load('assets/$assetPath');
    await tempFile.writeAsBytes(data.buffer.asUint8List());
  }
  return tempFile.path;
}

/// Helper class for flattened segments during export
class _ExportSegment {
  final String path;
  final ClipTrim segment;
  final int clipIndex;
  _ExportSegment(this.path, this.segment, this.clipIndex);
}

/// Builds per-clip video filter additions (chroma key, speed ramp, color filter).
/// Returns filter string to append after scale/pad, or empty string.
String _clipVideoFilters(Clip clip) {
  final parts = <String>[];

  // Chroma key (green screen)
  if (clip.effects.chromaKey != null) {
    parts.add(clip.effects.chromaKey!.ffmpegFilter);
  }

  // Color filter preset
  if (clip.effects.filter != VideoFilter.none) {
    parts.add(clip.effects.filter.ffmpegFilter);
  }

  // Speed ramp via setpts
  if (clip.effects.speedRamp != SpeedRamp.none) {
    parts.add(_speedRampSetpts(clip.effects.speedRamp));
  }

  return parts.isEmpty ? '' : ',${parts.join(",")}';
}

/// Builds per-clip audio filter (voice changer, speed ramp tempo adjustment).
/// Returns filter string or empty string.
String _clipAudioFilters(Clip clip) {
  final parts = <String>[];

  // Voice changer
  if (clip.effects.voiceEffect != VoiceEffect.none) {
    parts.add(clip.effects.voiceEffect.ffmpegFilter);
  }

  // Speed ramp audio tempo compensation
  if (clip.effects.speedRamp != SpeedRamp.none) {
    parts.add(_speedRampAtempo(clip.effects.speedRamp));
  }

  return parts.join(',');
}

/// Map SpeedRamp presets to ffmpeg setpts expressions.
String _speedRampSetpts(SpeedRamp ramp) {
  switch (ramp) {
    case SpeedRamp.none:
      return '';
    case SpeedRamp.slowStart:
      // Starts at 0.5x, ramps to 1x over the clip
      return "setpts='if(lt(T,1),2*PTS,PTS+1)'";
    case SpeedRamp.slowEnd:
      // Normal speed, slows to 0.5x in last second
      return "setpts='PTS+max(0,(T-DURATION+1))*PTS*0.5'";
    case SpeedRamp.speedBurst:
      // 0.5x → 2x → 0.5x (middle is fast)
      return "setpts='if(lt(T,DURATION*0.3),2*PTS,if(lt(T,DURATION*0.7),0.5*PTS,2*PTS))'";
    case SpeedRamp.dramaticSlowmo:
      // 1x → 0.25x → 1x (middle is ultra-slow)
      return "setpts='if(lt(T,DURATION*0.3),PTS,if(lt(T,DURATION*0.7),4*PTS,PTS))'";
  }
}

/// Corresponding atempo adjustments for speed ramp presets.
/// Since setpts only affects video, audio needs atempo to match.
String _speedRampAtempo(SpeedRamp ramp) {
  // Approximate with overall tempo — exact variable tempo needs rubberband
  switch (ramp) {
    case SpeedRamp.none:
      return '';
    case SpeedRamp.slowStart:
      return 'atempo=0.85'; // average slowdown
    case SpeedRamp.slowEnd:
      return 'atempo=0.85';
    case SpeedRamp.speedBurst:
      return 'atempo=1.2'; // average speedup
    case SpeedRamp.dramaticSlowmo:
      return 'atempo=0.6'; // significant average slowdown
  }
}
