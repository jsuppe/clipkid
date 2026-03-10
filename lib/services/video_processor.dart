import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import '../models/choreography.dart';

/// Callback for processing progress updates
typedef ProgressCallback = void Function(double progress, String status);

/// Service for video processing (stabilization, effects, etc.)
class VideoProcessor {
  /// Process a clip with its effects applied
  /// Returns the path to the processed video, or null if processing failed
  static Future<String?> processClip(
    Clip clip, {
    ProgressCallback? onProgress,
  }) async {
    if (!clip.effects.stabilize) {
      return clip.path; // No processing needed
    }

    return stabilizeVideo(
      clip.path,
      strength: clip.effects.stabilizeStrength ?? 0.5,
      onProgress: onProgress,
    );
  }

  /// Stabilize a video using FFmpeg's vidstab filter
  /// This is a two-pass process:
  /// 1. Analyze motion and create transform data
  /// 2. Apply transforms to stabilize the video
  static Future<String?> stabilizeVideo(
    String inputPath, {
    double strength = 0.5, // 0.0 - 1.0
    ProgressCallback? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final transformFile = '${dir.path}/transforms_$timestamp.trf';
    final outputPath = '${dir.path}/stabilized_$timestamp.mp4';

    // Clamp strength to valid range and calculate smoothing (1-30)
    final smoothing = (strength * 30).round().clamp(1, 30);
    
    try {
      // Pass 1: Analyze motion with vidstabdetect
      onProgress?.call(0.0, 'Analyzing motion...');
      
      final pass1Command = '-y -i "$inputPath" '
          '-vf "vidstabdetect=stepsize=6:shakiness=10:accuracy=15:result=$transformFile" '
          '-f null -';

      final pass1Session = await FFmpegKit.execute(pass1Command);
      final pass1Code = await pass1Session.getReturnCode();

      if (!ReturnCode.isSuccess(pass1Code)) {
        final logs = await pass1Session.getLogsAsString();
        print('Stabilization pass 1 failed: $logs');
        return null;
      }

      onProgress?.call(0.5, 'Applying stabilization...');

      // Pass 2: Apply stabilization with vidstabtransform
      // zoom=5 adds 5% zoom to hide black borders from stabilization
      // crop=black fills edges with black instead of cropping
      final pass2Command = '-y -i "$inputPath" '
          '-vf "vidstabtransform=input=$transformFile:smoothing=$smoothing:crop=black:zoom=5" '
          '-c:a copy "$outputPath"';

      final pass2Session = await FFmpegKit.execute(pass2Command);
      final pass2Code = await pass2Session.getReturnCode();

      if (!ReturnCode.isSuccess(pass2Code)) {
        final logs = await pass2Session.getLogsAsString();
        print('Stabilization pass 2 failed: $logs');
        return null;
      }

      // Cleanup transform file
      try {
        await File(transformFile).delete();
      } catch (_) {}

      onProgress?.call(1.0, 'Done!');
      return outputPath;
    } catch (e) {
      print('Stabilization error: $e');
      return null;
    }
  }

  /// Process all clips in a choreography that need processing
  /// Returns a new choreography with processed paths filled in
  static Future<Choreography> processChoreography(
    Choreography choreography, {
    ProgressCallback? onProgress,
  }) async {
    final clips = <Clip>[];
    final needsProcessing = choreography.clips.where((c) => c.needsProcessing).toList();
    final total = needsProcessing.length;
    var processed = 0;

    for (final clip in choreography.clips) {
      if (clip.needsProcessing) {
        onProgress?.call(
          processed / total,
          'Processing clip ${processed + 1} of $total...',
        );

        final processedPath = await processClip(
          clip,
          onProgress: (p, s) {
            final overallProgress = (processed + p) / total;
            onProgress?.call(overallProgress, s);
          },
        );

        clips.add(clip.copyWith(processedPath: processedPath));
        processed++;
      } else {
        clips.add(clip);
      }
    }

    onProgress?.call(1.0, 'All clips processed!');

    return Choreography(
      version: choreography.version,
      clips: clips,
      name: choreography.name,
      createdAt: choreography.createdAt,
      modifiedAt: DateTime.now(),
    );
  }
}
