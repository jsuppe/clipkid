import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
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

    try {
      // Build FFmpeg command
      final command = _buildExportCommand(
        choreography,
        outputPath,
        exportSettings,
        overlayJobs,
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
    List<_OverlayExportJob> overlayJobs,
  ) {
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
      final inSec = seg.segment.inPointMs / 1000.0;
      final duration = seg.segment.durationMs / 1000.0;
      inputs.write('-ss $inSec -t $duration -i "${seg.path}" ');
      filterParts.add(
        '[$i:v]scale=${quality.width}:${quality.height}:force_original_aspect_ratio=decrease,pad=${quality.width}:${quality.height}:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p,fps=30[v$i]',
      );
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
      // then xfade between consecutive clips.
      final clipVideoLabels = <String>[]; // label of each clip's final video stream
      final clipDurationsSec = <double>[]; // each clip's final duration in the output timeline

      int segIndex = 0;
      for (int ci = 0; ci < clips.length; ci++) {
        final clip = clips[ci];
        final segs = clip.effectiveSegments;
        final clipDuration = segs.fold<int>(0, (sum, s) => sum + s.durationMs) / 1000.0;
        clipDurationsSec.add(clipDuration);

        if (segs.length == 1) {
          clipVideoLabels.add('[v$segIndex]');
          segIndex += 1;
        } else {
          // Concat this clip's segments into [cN]
          final inputs =
              List.generate(segs.length, (i) => '[v${segIndex + i}]').join();
          filterParts.add('${inputs}concat=n=${segs.length}:v=1:a=0[c$ci]');
          clipVideoLabels.add('[c$ci]');
          segIndex += segs.length;
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

    // Add overlay inputs and filter chain
    if (overlayJobs.isNotEmpty) {
      final segmentInputCount = allSegments.length;
      for (int oi = 0; oi < overlayJobs.length; oi++) {
        final job = overlayJobs[oi];
        // Loop the overlay image so it's available for the entire video
        inputs.write('-loop 1 -i "${job.png.path}" ');
      }

      String current = outputLabel;
      for (int oi = 0; oi < overlayJobs.length; oi++) {
        final job = overlayJobs[oi];
        final inputIdx = segmentInputCount + oi;
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

    final filterComplex = filterParts.join(';');

    final audioArgs = settings.includeAudio
        ? '-map 0:a? -c:a aac -b:a 128k -ac 2'
        : '-an';

    return '-y ${inputs}-filter_complex "$filterComplex" -map "$outputLabel" $audioArgs '
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

/// Helper class for flattened segments during export
class _ExportSegment {
  final String path;
  final ClipTrim segment;
  final int clipIndex;
  _ExportSegment(this.path, this.segment, this.clipIndex);
}
