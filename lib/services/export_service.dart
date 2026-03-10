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
  /// Supports multiple segments per clip
  static String _buildExportCommand(
    Choreography choreography, 
    String outputPath,
    ExportSettings settings,
  ) {
    final clips = choreography.clips;
    final quality = settings.quality;
    
    // Flatten all segments from all clips into a list of (path, segment) pairs
    final allSegments = <_ExportSegment>[];
    for (final clip in clips) {
      for (final segment in clip.effectiveSegments) {
        allSegments.add(_ExportSegment(clip.playbackPath, segment));
      }
    }
    
    // For single segment, use simpler command
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
    
    // For multiple segments, use filter_complex
    final inputs = StringBuffer();
    final filterParts = <String>[];
    
    for (int i = 0; i < allSegments.length; i++) {
      final seg = allSegments[i];
      final inSec = seg.segment.inPointMs / 1000.0;
      final duration = seg.segment.durationMs / 1000.0;
      
      inputs.write('-ss $inSec -t $duration -i "${seg.path}" ');
      
      // Scale video
      filterParts.add('[$i:v]scale=${quality.width}:${quality.height}:force_original_aspect_ratio=decrease,pad=${quality.width}:${quality.height}:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p[v$i]');
    }
    
    // Concat all video streams
    final concatInputs = List.generate(allSegments.length, (i) => '[v$i]').join();
    filterParts.add('${concatInputs}concat=n=${allSegments.length}:v=1:a=0[outv]');
    
    final filterComplex = filterParts.join(';');
    
    // For audio: just take from first clip or disable
    final audioArgs = settings.includeAudio 
        ? '-map 0:a? -c:a aac -b:a 128k -ac 2' 
        : '-an';
    
    return '-y ${inputs}-filter_complex "$filterComplex" -map "[outv]" $audioArgs '
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
  _ExportSegment(this.path, this.segment);
}
