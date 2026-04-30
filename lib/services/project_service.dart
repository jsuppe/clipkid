import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import '../models/choreography.dart';

/// Service for managing projects and video files
class ProjectService {
  static const _uuid = Uuid();
  static final _picker = ImagePicker();

  static const _videoExtensions = {
    '.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v', '.3gp', '.ts',
  };

  /// Pick a video file from device gallery.
  /// Validates the picked file is actually a video before returning.
  static Future<List<File>?> pickVideos() async {
    final result = await _picker.pickVideo(source: ImageSource.gallery);
    if (result == null) return null;

    final ext = result.path.toLowerCase().split('.').last;
    if (!_videoExtensions.contains('.$ext')) {
      // Not a video file — try to validate via VideoPlayerController
      try {
        final controller = VideoPlayerController.file(File(result.path));
        await controller.initialize();
        await controller.dispose();
      } catch (_) {
        return null; // Can't play as video — reject
      }
    }

    return [File(result.path)];
  }

  /// Capture a video using the device camera
  /// Returns the recorded video file, or null if cancelled
  static Future<File?> captureVideo({
    Duration? maxDuration,
    CameraDevice preferredCamera = CameraDevice.rear,
  }) async {
    final result = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: maxDuration ?? const Duration(minutes: 5),
      preferredCameraDevice: preferredCamera,
    );
    
    if (result == null) return null;
    
    return File(result.path);
  }

  /// Get video duration using VideoPlayerController
  static Future<int> getVideoDurationMs(String path) async {
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      return controller.value.duration.inMilliseconds;
    } finally {
      await controller.dispose();
    }
  }

  /// Create clips from video files and add to choreography immediately
  /// Returns choreography with placeholder durations (fast)
  /// Videos are sorted by recording/modification time (chronological order)
  static Choreography addVideosToChoreographyFast(
    Choreography choreography,
    List<File> videos,
  ) {
    // Sort videos by modification time (proxy for recording time)
    final sortedVideos = List<File>.from(videos);
    sortedVideos.sort((a, b) {
      try {
        final aTime = a.lastModifiedSync();
        final bTime = b.lastModifiedSync();
        return aTime.compareTo(bTime);
      } catch (e) {
        return 0; // Keep original order if we can't read times
      }
    });

    var updated = choreography;

    for (final video in sortedVideos) {
      // Use placeholder duration - will be resolved later
      final clip = Clip(
        id: _uuid.v4(),
        path: video.path,
        startMs: updated.totalDurationMs,
        sourceDurationMs: 5000, // Placeholder: 5 seconds
        name: video.path.split('/').last,
      );
      updated = updated.addClip(clip);
    }

    return updated;
  }

  /// Resolve actual durations for clips that have placeholder values
  /// Calls onProgress after each clip is resolved
  static Future<Choreography> resolveDurations(
    Choreography choreography, {
    void Function(Choreography updated, int resolved, int total)? onProgress,
  }) async {
    final clips = List<Clip>.from(choreography.clips);
    var needsRecalc = false;

    for (int i = 0; i < clips.length; i++) {
      final clip = clips[i];
      
      // Check if this clip needs duration resolution
      // (placeholder duration is exactly 5000ms)
      if (clip.sourceDurationMs == 5000) {
        try {
          final actualDuration = await getVideoDurationMs(clip.path);
          clips[i] = clip.copyWith(
            sourceDurationMs: actualDuration,
            trim: ClipTrim(inPointMs: 0, outPointMs: actualDuration),
          );
          needsRecalc = true;
        } catch (e) {
          // Keep placeholder if we can't get duration
          print('Failed to get duration for ${clip.path}: $e');
        }
      }

      // Recalculate start positions if needed
      if (needsRecalc) {
        for (int j = 1; j < clips.length; j++) {
          clips[j] = clips[j].copyWith(startMs: clips[j - 1].endMs);
        }
      }

      final updated = Choreography(
        version: choreography.version,
        clips: clips,
        name: choreography.name,
        createdAt: choreography.createdAt,
        modifiedAt: DateTime.now(),
      );

      onProgress?.call(updated, i + 1, clips.length);
    }

    return Choreography(
      version: choreography.version,
      clips: clips,
      name: choreography.name,
      createdAt: choreography.createdAt,
      modifiedAt: DateTime.now(),
    );
  }

  /// Create clips from video files and add to choreography (legacy - blocking)
  static Future<Choreography> addVideosToChoreography(
    Choreography choreography,
    List<File> videos,
  ) async {
    var updated = choreography;

    for (final video in videos) {
      final durationMs = await getVideoDurationMs(video.path);
      final clip = Clip(
        id: _uuid.v4(),
        path: video.path,
        startMs: updated.totalDurationMs,
        sourceDurationMs: durationMs,
        name: video.path.split('/').last,
      );
      updated = updated.addClip(clip);
    }

    return updated;
  }

  /// Save choreography to a JSON file
  static Future<File> saveChoreography(
    Choreography choreography, {
    String? fileName,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final projectsDir = Directory('${dir.path}/clipkid_projects');
    if (!await projectsDir.exists()) {
      await projectsDir.create(recursive: true);
    }

    final name = fileName ?? 'project_${DateTime.now().millisecondsSinceEpoch}';
    final file = File('${projectsDir.path}/$name.json');
    await file.writeAsString(choreography.toJsonString());
    return file;
  }

  /// Load choreography from a JSON file
  static Future<Choreography> loadChoreography(String path) async {
    final file = File(path);
    final jsonString = await file.readAsString();
    return Choreography.fromJsonString(jsonString);
  }

  /// List all saved projects
  static Future<List<File>> listProjects() async {
    final dir = await getApplicationDocumentsDirectory();
    final projectsDir = Directory('${dir.path}/clipkid_projects');
    if (!await projectsDir.exists()) return [];

    return projectsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
  }
}
