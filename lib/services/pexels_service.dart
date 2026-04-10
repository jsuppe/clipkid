import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// A video result from Pexels
class PexelsVideo {
  final int id;
  final int duration;
  final int width;
  final int height;
  final String thumbnail;
  final String downloadUrl;
  final String fileType;
  final String user;

  PexelsVideo({
    required this.id,
    required this.duration,
    required this.width,
    required this.height,
    required this.thumbnail,
    required this.downloadUrl,
    required this.fileType,
    required this.user,
  });

  factory PexelsVideo.fromJson(Map<String, dynamic> json) => PexelsVideo(
        id: json['id'] as int,
        duration: json['duration'] as int? ?? 0,
        width: json['width'] as int? ?? 0,
        height: json['height'] as int? ?? 0,
        thumbnail: json['thumbnail'] as String? ?? '',
        downloadUrl: json['download_url'] as String? ?? '',
        fileType: json['file_type'] as String? ?? 'video/mp4',
        user: json['user'] as String? ?? 'Unknown',
      );
}

/// Service for browsing and downloading kid-friendly stock videos from Pexels.
/// Uses the ClipKid backend API to keep the Pexels API key on the server.
class PexelsService {
  // ClipKid backend API (public endpoint)
  static const String _apiBaseUrl = 'https://clipkid-api.ruminateai.com';

  /// Search Pexels for videos matching [query].
  Future<List<PexelsVideo>> search(String query, {int page = 1, int perPage = 20}) async {
    final uri = Uri.parse('$_apiBaseUrl/pexels/search').replace(queryParameters: {
      'q': query,
      'page': page.toString(),
      'per_page': perPage.toString(),
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Pexels search failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final videos = data['videos'] as List<dynamic>? ?? [];
    return videos.map((v) => PexelsVideo.fromJson(v as Map<String, dynamic>)).toList();
  }

  /// Get popular kid-friendly videos.
  Future<List<PexelsVideo>> popular({int page = 1, int perPage = 20}) async {
    final uri = Uri.parse('$_apiBaseUrl/pexels/popular').replace(queryParameters: {
      'page': page.toString(),
      'per_page': perPage.toString(),
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Pexels popular failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final videos = data['videos'] as List<dynamic>? ?? [];
    return videos.map((v) => PexelsVideo.fromJson(v as Map<String, dynamic>)).toList();
  }

  /// Get kid-safe topic suggestions.
  Future<List<String>> topics() async {
    final uri = Uri.parse('$_apiBaseUrl/pexels/topics');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      return _defaultTopics;
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return List<String>.from(data['topics'] as List<dynamic>);
  }

  /// Download a video from [url] to a local file. Returns the file path.
  Future<String> downloadVideo(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final clipsDir = Directory('${dir.path}/pexels_clips');
    if (!await clipsDir.exists()) {
      await clipsDir.create(recursive: true);
    }

    final fileName = 'pexels_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final filePath = '${clipsDir.path}/$fileName';

    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception('Failed to download video: ${response.statusCode}');
    }

    final contentLength = response.contentLength ?? 0;
    final file = File(filePath);
    final sink = file.openWrite();
    int received = 0;

    await response.stream.forEach((chunk) {
      sink.add(chunk);
      received += chunk.length;
      if (contentLength > 0 && onProgress != null) {
        onProgress(received / contentLength);
      }
    });

    await sink.close();
    return filePath;
  }

  static const List<String> _defaultTopics = [
    'puppy', 'kitten', 'space', 'dinosaur', 'ocean',
    'flower', 'rainbow', 'butterfly', 'castle', 'cartoon',
  ];
}
