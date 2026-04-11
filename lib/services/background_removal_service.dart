import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service for AI background removal on video clips. Uses the ClipKid backend
/// which proxies through Replicate's video matting model.
class BackgroundRemovalService {
  static const String _apiBaseUrl = 'https://clipkid-api.ruminateai.com';

  /// Uploads [videoFile] and runs background removal. Composites onto
  /// [backgroundColorHex] (e.g. "#00FF00") if provided.
  /// Returns the local file path of the processed video.
  Future<String> removeBackground(
    File videoFile, {
    String? backgroundColorHex,
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Uploading video...');

    final uri = Uri.parse('$_apiBaseUrl/matting');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('video', videoFile.path));
    if (backgroundColorHex != null) {
      request.fields['background_color'] = backgroundColorHex;
    }

    final streamedResponse = await request.send().timeout(const Duration(seconds: 180));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final predictionId = data['prediction_id'] as String?;
    if (predictionId == null) throw Exception('No prediction id returned');

    // Poll for completion — matting can take a while on longer clips
    onProgress?.call('Removing background...');
    String? outputUrl;
    for (int attempt = 0; attempt < 120; attempt++) {
      await Future.delayed(const Duration(seconds: 3));
      final statusResp = await http
          .get(Uri.parse('$_apiBaseUrl/matting/status/$predictionId'))
          .timeout(const Duration(seconds: 15));
      if (statusResp.statusCode != 200) continue;

      final statusData = jsonDecode(statusResp.body) as Map<String, dynamic>;
      final status = statusData['status'] as String?;
      if (status == 'succeeded') {
        outputUrl = statusData['output_url'] as String?;
        break;
      } else if (status == 'failed') {
        throw Exception('Background removal failed: ${statusData['error']}');
      }
    }

    if (outputUrl == null) throw Exception('Background removal timed out');

    // Download the processed video
    onProgress?.call('Downloading result...');
    final dir = await getApplicationDocumentsDirectory();
    final procDir = Directory('${dir.path}/processed');
    if (!await procDir.exists()) await procDir.create(recursive: true);
    final filePath = '${procDir.path}/bg_removed_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final downloadResp = await http.get(Uri.parse(outputUrl)).timeout(const Duration(seconds: 180));
    if (downloadResp.statusCode != 200) {
      throw Exception('Failed to download result: ${downloadResp.statusCode}');
    }
    await File(filePath).writeAsBytes(downloadResp.bodyBytes);
    return filePath;
  }
}
