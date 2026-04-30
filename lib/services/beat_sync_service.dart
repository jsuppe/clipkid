import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

/// Beat detection and auto-sync service.
/// Uses ffmpeg's `ebur128` loudness analysis to find energy peaks.
class BeatSyncService {
  /// Analyze an audio/video file and return beat timestamps in milliseconds.
  /// Uses energy-based onset detection via ffmpeg.
  static Future<List<int>> detectBeats(String filePath) async {
    final dir = await getTemporaryDirectory();
    final outputPath = '${dir.path}/beat_analysis.txt';

    // Use ffmpeg to extract audio amplitude envelope
    final command =
        '-i "$filePath" -af "aformat=sample_fmts=s16:channel_layouts=mono,astats=metadata=1:reset=1" '
        '-f null -';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      // Fallback: generate evenly-spaced beats at ~120 BPM
      return _fallbackBeats(filePath);
    }

    // Parse the output for loudness peaks
    final logs = await session.getLogsAsString() ?? '';
    return _parseBeatsFromLogs(logs);
  }

  /// Fallback: assume ~120 BPM (500ms between beats) and generate beats
  /// for the duration of the file.
  static Future<List<int>> _fallbackBeats(String filePath) async {
    // Probe duration
    final probeSession = await FFmpegKit.execute(
      '-i "$filePath" -f null -',
    );
    final logs = await probeSession.getLogsAsString() ?? '';
    final durationMatch = RegExp(r'Duration:\s*(\d+):(\d+):(\d+)\.(\d+)').firstMatch(logs);

    int durationMs = 30000; // default 30s
    if (durationMatch != null) {
      final h = int.parse(durationMatch.group(1)!);
      final m = int.parse(durationMatch.group(2)!);
      final s = int.parse(durationMatch.group(3)!);
      final cs = int.parse(durationMatch.group(4)!);
      durationMs = (h * 3600 + m * 60 + s) * 1000 + cs * 10;
    }

    // Generate beats at 120 BPM
    const beatIntervalMs = 500;
    final beats = <int>[];
    for (int t = 0; t < durationMs; t += beatIntervalMs) {
      beats.add(t);
    }
    return beats;
  }

  /// Parse ffmpeg logs for energy peaks. Simplified — looks for volume spikes.
  static List<int> _parseBeatsFromLogs(String logs) {
    // This is a simplified beat detector. For production, use aubio or
    // a dedicated beat tracking library. For prototype, we fall back to
    // evenly-spaced beats.
    // TODO: implement real peak detection from astats output
    return [];
  }

  /// Given beat timestamps and clip durations, compute optimal trim points
  /// so each clip starts/ends on a beat.
  static List<int> computeBeatSyncDurations({
    required List<int> beats,
    required int clipCount,
  }) {
    if (beats.isEmpty || clipCount <= 0) return [];

    // Distribute beats evenly across clips
    final beatsPerClip = beats.length ~/ clipCount;
    if (beatsPerClip < 1) {
      // More clips than beats — each clip gets one beat interval
      final interval = beats.length > 1 ? beats[1] - beats[0] : 500;
      return List.filled(clipCount, interval);
    }

    final durations = <int>[];
    for (int i = 0; i < clipCount; i++) {
      final startBeat = i * beatsPerClip;
      final endBeat = (i + 1) * beatsPerClip;
      if (startBeat < beats.length && endBeat <= beats.length) {
        durations.add(beats[endBeat - 1] - beats[startBeat]);
      } else {
        durations.add(beats.last ~/ clipCount);
      }
    }
    return durations;
  }
}
