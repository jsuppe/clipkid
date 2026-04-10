import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Style presets for video transformation
enum StylePreset {
  cartoon('Cartoon', 'cartoon'),
  anime('Anime', 'anime'),
  watercolor('Watercolor', 'watercolor'),
  pixelArt('Pixel Art', 'pixel_art'),
  oilPainting('Oil Painting', 'oil_painting'),
  sketch('Pencil Sketch', 'sketch'),
  neon('Neon Glow', 'neon'),
  fantasy('Fantasy', 'fantasy');

  final String displayName;
  final String apiId;
  const StylePreset(this.displayName, this.apiId);
}

/// Service for AI-powered style transfer on video frames
/// Uses ClipKid backend API (no API key needed on client)
class StyleTransferService {
  // ClipKid backend API (public endpoint)
  static const String _apiBaseUrl = 'https://clipkid-api.ruminateai.com';
  
  /// Transform a single image with a style preset
  Future<File?> transformImage({
    required File inputImage,
    required StylePreset style,
    double strength = 0.7,
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Uploading image...');
    
    // Convert image to base64
    final bytes = await inputImage.readAsBytes();
    final base64Image = base64Encode(bytes);
    
    // Start transformation
    onProgress?.call('Starting AI transformation...');
    
    final startResponse = await http.post(
      Uri.parse('$_apiBaseUrl/transform'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'image': base64Image,
        'style': style.apiId,
        'strength': strength,
      }),
    );
    
    if (startResponse.statusCode == 429) {
      throw Exception('Rate limit reached! Try again tomorrow.');
    }
    
    if (startResponse.statusCode != 200) {
      final error = jsonDecode(startResponse.body);
      throw Exception(error['error'] ?? 'Failed to start transformation');
    }
    
    final startResult = jsonDecode(startResponse.body);
    final predictionId = startResult['prediction_id'];
    final remaining = startResult['remaining_today'];
    
    onProgress?.call('AI is transforming... ($remaining transforms left today)');
    
    // Poll for completion
    while (true) {
      await Future.delayed(const Duration(seconds: 2));
      
      final statusResponse = await http.get(
        Uri.parse('$_apiBaseUrl/status/$predictionId'),
      );
      
      if (statusResponse.statusCode != 200) {
        throw Exception('Failed to check status');
      }
      
      final status = jsonDecode(statusResponse.body);
      final state = status['status'];
      
      if (state == 'succeeded') {
        final outputUrl = status['output']?[0];
        if (outputUrl == null) {
          throw Exception('No output image returned');
        }
        
        // Download the result
        onProgress?.call('Downloading result...');
        final imageResponse = await http.get(Uri.parse(outputUrl));
        
        // Save to temp file
        final tempDir = await getTemporaryDirectory();
        final outputFile = File('${tempDir.path}/styled_${DateTime.now().millisecondsSinceEpoch}.png');
        await outputFile.writeAsBytes(imageResponse.bodyBytes);
        
        onProgress?.call('Done!');
        return outputFile;
        
      } else if (state == 'failed') {
        throw Exception('Transformation failed: ${status['error']}');
      }
      
      onProgress?.call('AI is working...');
    }
  }
  
  /// Transform a video by processing key frames
  Future<String?> transformVideo({
    required String inputVideoPath,
    required StylePreset style,
    double strength = 0.7,
    int frameInterval = 5,
    void Function(double progress, String status)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final workDir = '${tempDir.path}/style_${DateTime.now().millisecondsSinceEpoch}';
    final framesDir = Directory('$workDir/frames');
    final styledDir = Directory('$workDir/styled');
    await framesDir.create(recursive: true);
    await styledDir.create(recursive: true);
    
    try {
      // Extract frames
      onProgress?.call(0.1, 'Extracting frames...');
      
      final extractResult = await Process.run('ffmpeg', [
        '-i', inputVideoPath,
        '-vf', 'fps=10',
        '${framesDir.path}/frame_%04d.jpg',
      ]);
      
      if (extractResult.exitCode != 0) {
        throw Exception('Failed to extract frames');
      }
      
      // Get frame list
      final frames = framesDir.listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.jpg'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      
      if (frames.isEmpty) {
        throw Exception('No frames extracted');
      }
      
      // Transform key frames
      File? lastStyled;
      for (int i = 0; i < frames.length; i++) {
        final frame = frames[i];
        final frameNum = i.toString().padLeft(4, '0');
        final outputPath = '${styledDir.path}/frame_$frameNum.png';
        
        if (i % frameInterval == 0) {
          onProgress?.call(
            0.1 + (0.7 * i / frames.length),
            'Styling frame ${i + 1}/${frames.length}...',
          );
          
          final styled = await transformImage(
            inputImage: frame,
            style: style,
            strength: strength,
          );
          
          if (styled != null) {
            await styled.copy(outputPath);
            lastStyled = File(outputPath);
          }
        } else if (lastStyled != null) {
          // Copy previous styled frame
          await lastStyled.copy(outputPath);
        }
      }
      
      // Reassemble video
      onProgress?.call(0.9, 'Creating video...');
      
      final outputPath = '$workDir/styled_video.mp4';
      
      final assembleResult = await Process.run('ffmpeg', [
        '-framerate', '10',
        '-i', '${styledDir.path}/frame_%04d.png',
        '-c:v', 'libx264',
        '-pix_fmt', 'yuv420p',
        '-y',
        outputPath,
      ]);
      
      if (assembleResult.exitCode != 0) {
        throw Exception('Failed to create video');
      }
      
      onProgress?.call(1.0, 'Done!');
      return outputPath;
      
    } catch (e) {
      // Cleanup on error
      try {
        await Directory(workDir).delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }
  
  /// Check remaining transforms for today
  Future<int?> getRemainingTransforms() async {
    try {
      final response = await http.get(Uri.parse('$_apiBaseUrl/health'));
      if (response.statusCode == 200) {
        return null; // Health endpoint doesn't return remaining, that comes with transform
      }
    } catch (_) {}
    return null;
  }
}
