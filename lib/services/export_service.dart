import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import '../models/choreography.dart';
import '../screens/export_dialog.dart';

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

    try {
      // Build FFmpeg command
      final command = _buildExportCommand(choreography, outputPath, exportSettings);
      print('=== EXPORT COMMAND ===');
      print(command);
      
      // Calculate total duration for progress
      final totalDurationMs = choreography.totalDurationMs;

      onProgress?.call(0.1, 'Starting FFmpeg...');

      // Execute synchronously for better error handling
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        onProgress?.call(1.0, 'Export complete!');
        return outputPath;
      } else {
        final logs = await session.getLogsAsString();
        print('=== EXPORT FAILED ===');
        print('Command: $command');
        print('Logs: $logs');
        onProgress?.call(0.0, 'Export failed');
        return null;
      }
    } catch (e, stack) {
      print('=== EXPORT ERROR ===');
      print('Error: $e');
      print('Stack: $stack');
      onProgress?.call(0.0, 'Export error: $e');
      return null;
    }
  }

  /// Debug: Get the FFmpeg command that would be used
  static String getExportCommand(Choreography choreography, ExportSettings settings) {
    return _buildExportCommand(choreography, '/tmp/output.mp4', settings);
  }

  /// Build FFmpeg command for concatenating clips with their trims/effects
  /// Supports multiple segments per clip and cross-clip transitions.
  static String _buildExportCommand(
    Choreography choreography,
    String outputPath,
    ExportSettings settings,
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

    // Single segment = direct passthrough
    if (allSegments.length == 1) {
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

    if (!hasTransitions) {
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
