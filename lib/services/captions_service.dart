import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/choreography.dart';

/// A transcribed segment returned by Whisper: a phrase with its time range.
class CaptionSegment {
  final double startSec;
  final double endSec;
  final String text;

  CaptionSegment({
    required this.startSec,
    required this.endSec,
    required this.text,
  });

  factory CaptionSegment.fromJson(Map<String, dynamic> json) => CaptionSegment(
        startSec: (json['start'] as num).toDouble(),
        endSec: (json['end'] as num).toDouble(),
        text: json['text'] as String,
      );
}

/// Uploads a video to the ClipKid backend for Whisper-based transcription.
/// Returns a list of CaptionSegments that the caller turns into TextOverlays.
class CaptionsService {
  static const String _apiBaseUrl = 'https://clipkid-api.ruminateai.com';

  /// Transcribes [videoFile] and returns the segments. Handles upload,
  /// polling, and cleanup. [onProgress] is called with status strings.
  Future<List<CaptionSegment>> transcribe(
    File videoFile, {
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Uploading video...');

    // POST the video as multipart
    final uri = Uri.parse('$_apiBaseUrl/captions');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('video', videoFile.path));
    final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final predictionId = data['prediction_id'] as String?;
    if (predictionId == null) {
      throw Exception('Server did not return a prediction id');
    }

    // Poll for completion
    onProgress?.call('Listening to your video...');
    for (int attempt = 0; attempt < 60; attempt++) {
      await Future.delayed(const Duration(seconds: 2));
      final statusResponse = await http
          .get(Uri.parse('$_apiBaseUrl/captions/status/$predictionId'))
          .timeout(const Duration(seconds: 15));
      if (statusResponse.statusCode != 200) continue;

      final statusData = jsonDecode(statusResponse.body) as Map<String, dynamic>;
      final status = statusData['status'] as String?;

      if (status == 'succeeded') {
        onProgress?.call('Writing captions...');
        final segments = (statusData['segments'] as List<dynamic>?) ?? [];
        return segments
            .map((s) => CaptionSegment.fromJson(s as Map<String, dynamic>))
            .toList();
      } else if (status == 'failed') {
        throw Exception('Transcription failed: ${statusData['error']}');
      }
      // otherwise: starting, processing — keep polling
    }
    throw Exception('Transcription timed out');
  }

  /// Converts [segments] into a list of TextOverlay objects positioned at
  /// the bottom of the video with the Caption style, one per phrase, each
  /// with its own custom time range.
  static List<TextOverlay> segmentsToOverlays(List<CaptionSegment> segments) {
    return segments
        .map((s) => TextOverlay(
              text: s.text,
              style: TextStylePreset.caption,
              x: 0.5,
              y: 0.85,
              timing: OverlayTiming.customRange,
              customStartMs: (s.startSec * 1000).round(),
              customEndMs: (s.endSec * 1000).round(),
            ))
        .toList();
  }
}
