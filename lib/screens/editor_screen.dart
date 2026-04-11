import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import '../models/choreography.dart';
import '../models/duck_guide.dart';
import '../services/project_service.dart';
import '../services/video_processor.dart';
import '../services/export_service.dart';
import '../widgets/timeline_view.dart';
import '../widgets/video_preview.dart';
import '../widgets/duck_guide_overlay.dart';
import 'trim_screen.dart';
import 'export_dialog.dart';
import 'style_transfer_screen.dart';
import 'quick_edit_screen.dart';
import 'music_picker_screen.dart';
import 'pexels_browser_screen.dart';
import 'text_editor_screen.dart';
import 'transition_picker_screen.dart';
import 'templates_gallery_screen.dart';
import '../services/captions_service.dart';

/// Main editor screen
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  Choreography _choreography = Choreography.empty(name: 'New Project');
  int _currentPositionMs = 0;
  int? _seekToMs;
  bool _isLoading = false;
  bool _isProcessing = false;
  bool _isExporting = false;
  String _processingStatus = '';
  double _processingProgress = 0.0;
  double _exportProgress = 0.0;
  String _exportStatus = '';
  int? _selectedClipIndex;
  final GlobalKey<VideoPreviewState> _previewKey = GlobalKey();
  
  // Duck guide for interactive tutorial
  final DuckGuide _duckGuide = DuckGuide();

  @override
  void initState() {
    super.initState();
    // Offer duck guide help on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _duckGuide.offer();
      setState(() {});
    });
    _duckGuide.addListener(_onDuckGuideChanged);
  }

  @override
  void dispose() {
    _duckGuide.removeListener(_onDuckGuideChanged);
    _duckGuide.dispose();
    super.dispose();
  }

  void _onDuckGuideChanged() {
    if (mounted) setState(() {});
  }

  /// Show options for adding a clip (camera or gallery)
  void _showAddClipOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Add Clip',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.videocam, color: Colors.red, size: 28),
                ),
                title: const Text('Record Video', style: TextStyle(color: Colors.white)),
                subtitle: Text('Capture a new clip with camera', style: TextStyle(color: Colors.grey[400])),
                onTap: () {
                  Navigator.pop(context);
                  _captureVideo();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.blue, size: 28),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
                subtitle: Text('Select existing videos', style: TextStyle(color: Colors.grey[400])),
                onTap: () {
                  Navigator.pop(context);
                  _addVideosFromGallery();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.public, color: Colors.green, size: 28),
                ),
                title: const Text('Browse Stock Videos 🎬', style: TextStyle(color: Colors.white)),
                subtitle: Text('Find awesome clips from the internet', style: TextStyle(color: Colors.grey[400])),
                onTap: () {
                  Navigator.pop(context);
                  _addVideoFromPexels();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Capture video from camera
  Future<void> _captureVideo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final video = await ProjectService.captureVideo(
        maxDuration: const Duration(minutes: 3),
      );
      
      if (video != null) {
        // Add clip immediately with placeholder duration
        final fastUpdate = ProjectService.addVideosToChoreographyFast(
          _choreography,
          [video],
        );
        setState(() {
          _choreography = fastUpdate;
          _isLoading = false;
        });

        // Notify duck guide that clips were added
        _duckGuide.onClipsAdded(1);

        // Resolve actual durations in background
        _resolveDurationsInBackground();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video recorded! 🎬'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      // Camera not available (e.g., iOS simulator). Offer friendly fallback.
      final isCameraMissing = e.toString().toLowerCase().contains('camera') ||
          e.toString().toLowerCase().contains('not available');
      final useGallery = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            isCameraMissing ? 'No camera here! 📷' : 'Hmm, something went wrong',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            isCameraMissing
                ? "This device doesn't have a camera. Want to pick a video from the gallery instead?"
                : 'Want to pick a video from your gallery instead?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No thanks'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open Gallery'),
            ),
          ],
        ),
      );
      if (useGallery == true && mounted) {
        _addVideosFromGallery();
      }
    }
  }

  /// Pick videos from gallery
  Future<void> _addVideosFromGallery() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final videos = await ProjectService.pickVideos();
      if (videos != null && videos.isNotEmpty) {
        // Add clips immediately with placeholder durations
        final fastUpdate = ProjectService.addVideosToChoreographyFast(
          _choreography,
          videos,
        );
        setState(() {
          _choreography = fastUpdate;
          _isLoading = false;
        });

        // Notify duck guide that clips were added
        _duckGuide.onClipsAdded(videos.length);

        // Resolve actual durations in background
        _resolveDurationsInBackground();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding videos: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Find which clip is currently playing based on global position.
  int _currentClipIndex() {
    if (_choreography.clips.isEmpty) return -1;
    for (var i = 0; i < _choreography.clips.length; i++) {
      final clip = _choreography.clips[i];
      if (_currentPositionMs >= clip.startMs &&
          _currentPositionMs < clip.startMs + clip.durationMs) {
        return i;
      }
    }
    return 0; // fallback to first clip
  }

  /// Open the text editor and add the result as an overlay on the current clip.
  Future<void> _addTextOverlay() async {
    final clipIndex = _currentClipIndex();
    if (clipIndex < 0) return;

    final result = await Navigator.push<TextOverlay?>(
      context,
      MaterialPageRoute(builder: (_) => const TextEditorScreen()),
    );

    if (result == null) return;

    final clip = _choreography.clips[clipIndex];
    final newOverlays = List<TextOverlay>.from(clip.effects.textOverlays)..add(result);
    final newEffects = clip.effects.copyWith(textOverlays: newOverlays);
    setState(() {
      _choreography = _choreography.copyWith(
        clips: [
          for (var i = 0; i < _choreography.clips.length; i++)
            if (i == clipIndex)
              _choreography.clips[i].copyWith(effects: newEffects)
            else
              _choreography.clips[i],
        ],
      );
    });
  }

  /// Run Whisper on a clip and add its transcription as caption overlays.
  Future<void> _runAutoCaption(int index) async {
    if (index < 0 || index >= _choreography.clips.length) return;
    final clip = _choreography.clips[index];
    final status = ValueNotifier<String>('Uploading video...');

    // Show persistent progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Auto Caption 🎤',
            style: TextStyle(color: Colors.white)),
        content: ValueListenableBuilder<String>(
          valueListenable: status,
          builder: (ctx, msg, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(msg, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );

    try {
      final captions = CaptionsService();
      final segments = await captions.transcribe(
        File(clip.playbackPath),
        onProgress: (s) => status.value = s,
      );
      if (!mounted) return;
      Navigator.pop(context); // dismiss progress dialog

      if (segments.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No speech detected in this clip')),
        );
        return;
      }

      final overlays = CaptionsService.segmentsToOverlays(segments);
      final newTextOverlays = [...clip.effects.textOverlays, ...overlays];
      final newEffects = clip.effects.copyWith(textOverlays: newTextOverlays);
      setState(() {
        _choreography = _choreography.copyWith(
          clips: [
            for (var i = 0; i < _choreography.clips.length; i++)
              if (i == index)
                _choreography.clips[i].copyWith(effects: newEffects)
              else
                _choreography.clips[i],
          ],
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${segments.length} captions ✨')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t generate captions: $e')),
      );
    }
  }

  /// Open the Templates gallery. If the kid picks a template and fills it in,
  /// we replace the current choreography with the instantiated template.
  /// If the current project has clips, we confirm first.
  Future<void> _openTemplates() async {
    if (_choreography.clips.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Start a new video?',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'This will replace your current project. Make sure you saved it first!',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep editing'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Use a template'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    if (!mounted) return;
    final newChoreography = await Navigator.push<Choreography?>(
      context,
      MaterialPageRoute(builder: (_) => const TemplatesGalleryScreen()),
    );
    if (newChoreography == null || !mounted) return;
    setState(() {
      _choreography = newChoreography;
      _currentPositionMs = 0;
      _selectedClipIndex = null;
    });
  }

  /// Open the transition picker for the transition between clip[index]
  /// and clip[index+1].
  Future<void> _editTransition(int index) async {
    if (index < 0 || index >= _choreography.clips.length - 1) return;
    final fromClip = _choreography.clips[index];
    final toClip = _choreography.clips[index + 1];
    final result = await TransitionPickerSheet.show(
      context,
      current: fromClip.outgoingTransition,
      fromClipName: fromClip.name ?? 'Clip ${index + 1}',
      toClipName: toClip.name ?? 'Clip ${index + 2}',
    );
    if (result == null) return;
    setState(() {
      _choreography = _choreography.copyWith(
        clips: [
          for (var i = 0; i < _choreography.clips.length; i++)
            if (i == index)
              _choreography.clips[i].copyWith(outgoingTransition: result)
            else
              _choreography.clips[i],
        ],
      );
    });
  }

  /// Called by VideoPreview when an overlay is dragged / deleted / resized.
  void _onClipEffectsChanged(int clipIndex, ClipEffects newEffects) {
    if (clipIndex < 0 || clipIndex >= _choreography.clips.length) return;
    setState(() {
      _choreography = _choreography.copyWith(
        clips: [
          for (var i = 0; i < _choreography.clips.length; i++)
            if (i == clipIndex)
              _choreography.clips[i].copyWith(effects: newEffects)
            else
              _choreography.clips[i],
        ],
      );
    });
  }

  /// Browse and download a video from Pexels
  Future<void> _addVideoFromPexels() async {
    final downloadedPath = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const PexelsBrowserScreen()),
    );

    if (downloadedPath == null || downloadedPath.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final file = File(downloadedPath);
      final fastUpdate = ProjectService.addVideosToChoreographyFast(
        _choreography,
        [file],
      );
      setState(() {
        _choreography = fastUpdate;
        _isLoading = false;
      });

      _duckGuide.onClipsAdded(1);
      _resolveDurationsInBackground();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding video: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Legacy method for backwards compatibility
  Future<void> _addVideos() async {
    _showAddClipOptions();
  }

  Future<void> _resolveDurationsInBackground() async {
    final resolved = await ProjectService.resolveDurations(
      _choreography,
      onProgress: (updated, done, total) {
        if (mounted) {
          setState(() {
            _choreography = updated;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _choreography = resolved;
      });
    }
  }

  Future<void> _saveProject() async {
    try {
      final file = await ProjectService.saveChoreography(_choreography);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  void _toggleStabilization(int index) {
    final clip = _choreography.clips[index];
    final newEffects = clip.effects.copyWith(
      stabilize: !clip.effects.stabilize,
    );
    final newClip = clip.copyWith(
      effects: newEffects,
      processedPath: null, // Clear processed path when toggling
    );
    
    final newClips = List<Clip>.from(_choreography.clips);
    newClips[index] = newClip;
    
    setState(() {
      _choreography = Choreography(
        version: _choreography.version,
        clips: newClips,
        name: _choreography.name,
        createdAt: _choreography.createdAt,
        modifiedAt: DateTime.now(),
      );
    });
  }

  /// Enable stabilization on all clips and start processing
  void _stabilizeAllClips() {
    final newClips = _choreography.clips.map((clip) {
      if (!clip.effects.stabilize) {
        return clip.copyWith(
          effects: clip.effects.copyWith(stabilize: true),
          processedPath: null,
        );
      }
      return clip;
    }).toList();

    setState(() {
      _choreography = Choreography(
        version: _choreography.version,
        clips: newClips,
        name: _choreography.name,
        createdAt: _choreography.createdAt,
        modifiedAt: DateTime.now(),
      );
    });

    // Start processing after enabling stabilization
    _processClips();
  }

  Future<void> _processClips() async {
    final needsProcessing = _choreography.clips.any((c) => c.needsProcessing);
    if (!needsProcessing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All clips already processed!')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingProgress = 0.0;
      _processingStatus = 'Starting...';
    });

    try {
      final processed = await VideoProcessor.processChoreography(
        _choreography,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _processingProgress = progress;
              _processingStatus = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _choreography = processed;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Processing complete!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Processing error: $e')),
        );
      }
    }
  }

  void _showClipOptions(int index) {
    // If duck guide is asking for star moment, handle that instead
    if (_duckGuide.isActive && _duckGuide.currentStep == GuideStep.starMoment) {
      _duckGuide.setStarClip(index);
      _duckGuide.nextStep();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⭐ Clip ${index + 1} is your star moment!'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.amber[700],
        ),
      );
      return;
    }

    final clip = _choreography.clips[index];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              clip.name ?? 'Clip ${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Trim option
            ListTile(
              leading: const Icon(Icons.content_cut, color: Colors.white),
              title: const Text('Trim', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                clip.isTrimmed 
                    ? 'Trimmed to ${_formatDuration(clip.durationMs)}'
                    : 'Set in/out points',
                style: TextStyle(color: Colors.grey[400]),
              ),
              onTap: () {
                Navigator.pop(context);
                _openTrimEditor(index);
              },
            ),
            
            // Quick Edit option (speed, reverse, filters, stickers)
            ListTile(
              leading: Icon(Icons.auto_awesome, color: Colors.amber[400]),
              title: Text('Quick Edit ✨', style: TextStyle(color: Colors.amber[400])),
              subtitle: Text(
                _getQuickEditSummary(clip),
                style: TextStyle(color: Colors.grey[400]),
              ),
              onTap: () {
                Navigator.pop(context);
                _openQuickEdit(index);
              },
            ),
            
            // Stabilize option
            SwitchListTile(
              secondary: const Icon(Icons.auto_fix_high, color: Colors.white),
              title: const Text('Stabilize', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                clip.effects.stabilize
                    ? (clip.processedPath != null ? 'Applied ✓' : 'Pending processing')
                    : 'Reduce camera shake',
                style: TextStyle(color: Colors.grey[400]),
              ),
              value: clip.effects.stabilize,
              onChanged: (value) {
                _toggleStabilization(index);
                Navigator.pop(context);
              },
            ),
            
            // Style Transfer option
            ListTile(
              leading: Icon(Icons.palette, color: Colors.purple[300]),
              title: Text('AI Style Transfer', style: TextStyle(color: Colors.purple[300])),
              subtitle: Text(
                'Transform with AI (cartoon, anime, etc.)',
                style: TextStyle(color: Colors.grey[400]),
              ),
              onTap: () {
                Navigator.pop(context);
                _openStyleTransfer(index);
              },
            ),

            // Auto Captions option
            ListTile(
              leading: Icon(Icons.closed_caption, color: Colors.cyan[300]),
              title: Text('Auto Caption 🎤', style: TextStyle(color: Colors.cyan[300])),
              subtitle: Text(
                'Listen to the video and add captions automatically',
                style: TextStyle(color: Colors.grey[400]),
              ),
              onTap: () {
                Navigator.pop(context);
                _runAutoCaption(index);
              },
            ),
            
            // Delete option
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red[300]),
              title: Text('Delete', style: TextStyle(color: Colors.red[300])),
              onTap: () {
                Navigator.pop(context);
                _deleteClip(index);
              },
            ),
            
            const SizedBox(height: 8),
            if (clip.needsProcessing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '⚠️ Tap "Process" to apply stabilization',
                  style: TextStyle(color: Colors.orange[300], fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTrimEditor(int index) async {
    // Pause preview before opening trim screen
    _previewKey.currentState?.pause();
    
    final clip = _choreography.clips[index];
    final result = await Navigator.push<List<ClipTrim>>(
      context,
      MaterialPageRoute(
        builder: (context) => TrimScreen(clip: clip),
      ),
    );

    if (result != null && mounted) {
      _updateClipSegments(index, result);
    }
  }

  String _getQuickEditSummary(Clip clip) {
    final parts = <String>[];
    if (clip.effects.speed != 1.0) parts.add('${clip.effects.speed}x');
    if (clip.effects.reverse) parts.add('reversed');
    if (clip.effects.filter != VideoFilter.none) parts.add(clip.effects.filter.displayName);
    if (clip.effects.stickers.isNotEmpty) parts.add('${clip.effects.stickers.length} stickers');
    return parts.isEmpty ? 'Speed, filters, stickers & more' : parts.join(', ');
  }

  Future<void> _openQuickEdit(int index) async {
    _previewKey.currentState?.pause();
    
    final clip = _choreography.clips[index];
    final result = await Navigator.push<ClipEffects>(
      context,
      MaterialPageRoute(
        builder: (context) => QuickEditScreen(clip: clip),
      ),
    );

    if (result != null && mounted) {
      final clips = List<Clip>.from(_choreography.clips);
      clips[index] = clips[index].copyWith(effects: result);
      
      setState(() {
        _choreography = Choreography(
          version: _choreography.version,
          clips: clips,
          name: _choreography.name,
          createdAt: _choreography.createdAt,
          modifiedAt: DateTime.now(),
          musicTrack: _choreography.musicTrack,
          musicVolume: _choreography.musicVolume,
          keepOriginalAudio: _choreography.keepOriginalAudio,
        );
      });
    }
  }

  Future<void> _openMusicPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => MusicPickerScreen(
          currentTrack: _choreography.musicTrack,
          currentVolume: _choreography.musicVolume,
          keepOriginalAudio: _choreography.keepOriginalAudio,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _choreography = _choreography.copyWith(
          musicTrack: result['track'] as MusicTrack,
          musicVolume: result['volume'] as double,
          keepOriginalAudio: result['keepOriginal'] as bool,
        );
      });
    }
  }

  Future<void> _openStyleTransfer(int index) async {
    // Pause preview before opening style transfer screen
    _previewKey.currentState?.pause();
    
    final clip = _choreography.clips[index];
    
    if (!mounted) return;
    
    final result = await Navigator.push<StyleTransferResult>(
      context,
      MaterialPageRoute(
        builder: (context) => StyleTransferScreen(clip: clip),
      ),
    );

    if (result != null && mounted) {
      // Update clip with styled video as the processed path
      final clips = List<Clip>.from(_choreography.clips);
      clips[index] = clips[index].copyWith(
        processedPath: result.path,
        effects: clips[index].effects.copyWith(
          styled: true,
          styleName: result.styleName,
        ),
      );
      
      setState(() {
        _choreography = Choreography(
          version: _choreography.version,
          clips: clips,
          name: _choreography.name,
          createdAt: _choreography.createdAt,
          modifiedAt: DateTime.now(),
        );
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Style applied! Playing styled version.'),
          backgroundColor: Colors.purple,
        ),
      );
    }
  }

  void _updateClipSegments(int index, List<ClipTrim> segments) {
    final clips = List<Clip>.from(_choreography.clips);
    clips[index] = clips[index].copyWith(
      segments: segments,
      trim: segments.first, // Keep first segment as legacy trim for compatibility
      processedPath: null, // Clear processed path when segments change
    );
    
    // Recalculate start positions for all clips after this one
    for (int i = index + 1; i < clips.length; i++) {
      clips[i] = clips[i].copyWith(startMs: clips[i - 1].endMs);
    }

    setState(() {
      _choreography = Choreography(
        version: _choreography.version,
        clips: clips,
        name: _choreography.name,
        createdAt: _choreography.createdAt,
        modifiedAt: DateTime.now(),
      );
    });

    // Notify duck guide
    _duckGuide.onClipTrimmed();
  }

  void _deleteClip(int index) {
    final clips = List<Clip>.from(_choreography.clips);
    clips.removeAt(index);
    
    // Recalculate start positions
    for (int i = index; i < clips.length; i++) {
      final newStart = i == 0 ? 0 : clips[i - 1].endMs;
      clips[i] = clips[i].copyWith(startMs: newStart);
    }

    setState(() {
      _choreography = Choreography(
        version: _choreography.version,
        clips: clips,
        name: _choreography.name,
        createdAt: _choreography.createdAt,
        modifiedAt: DateTime.now(),
      );
    });
  }

  void _reorderClips(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    
    final clips = List<Clip>.from(_choreography.clips);
    final clip = clips.removeAt(oldIndex);
    clips.insert(newIndex, clip);
    
    // Recalculate all start positions
    for (int i = 0; i < clips.length; i++) {
      final newStart = i == 0 ? 0 : clips[i - 1].endMs;
      clips[i] = clips[i].copyWith(startMs: newStart);
    }

    setState(() {
      _choreography = Choreography(
        version: _choreography.version,
        clips: clips,
        name: _choreography.name,
        createdAt: _choreography.createdAt,
        modifiedAt: DateTime.now(),
      );
    });

    // Notify duck guide
    _duckGuide.onClipsReordered();
  }

  void _onSeek(int ms) {
    setState(() {
      _seekToMs = ms;
    });
  }

  void _onPositionChanged(int ms) {
    setState(() {
      _currentPositionMs = ms;
      _seekToMs = null; // Clear seek after it's been processed
    });
  }

  String _formatDuration(int ms) {
    final seconds = (ms / 1000).floor();
    final minutes = (seconds / 60).floor();
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _showVersionInfo() async {
    // Get package info
    final packageInfo = await PackageInfo.fromPlatform();
    
    // Get Shorebird patch info
    final updater = ShorebirdUpdater();
    final isShorebird = updater.isAvailable;
    int? patchNumber;
    bool isNewPatchAvailable = false;
    
    if (isShorebird) {
      final currentPatch = await updater.readCurrentPatch();
      patchNumber = currentPatch?.number;
      final status = await updater.checkForUpdate();
      isNewPatchAvailable = status == UpdateStatus.outdated;
    }
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Row(
          children: [
            Text('🐥', style: TextStyle(fontSize: 28)),
            SizedBox(width: 8),
            Text('ClipKid', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _versionRow('Version', packageInfo.version),
            _versionRow('Build', packageInfo.buildNumber),
            if (isShorebird) ...[
              _versionRow('Patch', patchNumber?.toString() ?? 'Base'),
              if (isNewPatchAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.system_update, color: Colors.blue, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Update available!\nRestart app to install.',
                          style: TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
            ] else
              _versionRow('Updates', 'Not available'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  Widget _versionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400])),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _renameProject() {
    final controller = TextEditingController(text: _choreography.name ?? 'New Project');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Rename Project', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Project name',
            hintStyle: TextStyle(color: Colors.grey[500]),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  _choreography = Choreography(
                    version: _choreography.version,
                    clips: _choreography.clips,
                    name: newName,
                    createdAt: _choreography.createdAt,
                    modifiedAt: DateTime.now(),
                  );
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportVideo() async {
    if (_choreography.clips.isEmpty) return;

    // Check if any clips need processing first
    if (_choreography.clips.any((c) => c.needsProcessing)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please process all clips before exporting'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show export options dialog
    final settings = await showDialog<ExportSettings>(
      context: context,
      builder: (context) => ExportOptionsDialog(
        projectName: _choreography.name ?? 'New Project',
        clipCount: _choreography.clips.length,
        durationMs: _choreography.totalDurationMs,
      ),
    );

    if (settings == null) return; // User cancelled

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
      _exportStatus = 'Starting export...';
    });

    try {
      final outputPath = await ExportService.exportToMp4(
        _choreography,
        settings: settings,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _exportProgress = progress;
              _exportStatus = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isExporting = false;
        });

        if (outputPath != null) {
          _showExportComplete(outputPath);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export failed - check video format compatibility'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showExportComplete(String outputPath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Complete!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Video saved to:',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            Text(
              outputPath.split('/').last,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Share.shareXFiles([XFile(outputPath)], text: _choreography.name);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: GestureDetector(
          onTap: _renameProject,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _choreography.name ?? 'New Project',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
        backgroundColor: Colors.grey[900],
        leading: GestureDetector(
          onTap: _showVersionInfo,
          child: const Center(
            child: Text('🐥', style: TextStyle(fontSize: 24)),
          ),
        ),
        actions: [
          // Templates button
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: (_isLoading || _isProcessing || _isExporting)
                ? null
                : _openTemplates,
            tooltip: 'Templates',
          ),
          // Add Videos button
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.add),
            onPressed: (_isLoading || _isProcessing || _isExporting) ? null : _addVideos,
            tooltip: 'Add Videos',
          ),
          // Add Text button
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: (_choreography.clips.isEmpty || _isProcessing || _isExporting)
                ? null
                : _addTextOverlay,
            tooltip: 'Add Text',
          ),
          // Music button
          IconButton(
            icon: Icon(
              Icons.music_note,
              color: _choreography.musicTrack != MusicTrack.none
                  ? Colors.purple[300]
                  : null,
            ),
            onPressed: (_choreography.clips.isEmpty || _isProcessing || _isExporting)
                ? null
                : _openMusicPicker,
            tooltip: 'Add Music',
          ),
          // Export button
          IconButton(
            icon: const Icon(Icons.movie_creation),
            onPressed: (_choreography.clips.isEmpty || _isProcessing || _isExporting) 
                ? null 
                : _exportVideo,
            tooltip: 'Export Video',
          ),
          // Save button
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _choreography.clips.isNotEmpty ? _saveProject : null,
            tooltip: 'Save Project',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main editor content
          Column(
            children: [
              // Preview area
              Expanded(
                flex: 3,
                child: VideoPreview(
                  key: _previewKey,
                  choreography: _choreography,
                  onPositionChanged: _onPositionChanged,
                  seekToMs: _seekToMs,
                  onClipEffectsChanged: _onClipEffectsChanged,
                ),
              ),

          // Playback controls
          Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Current time
                SizedBox(
                  width: 60,
                  child: Text(
                    _formatDuration(_currentPositionMs),
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Play/Pause button
                IconButton(
                  icon: Icon(
                    _previewKey.currentState?.isPlaying ?? false
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 48,
                  ),
                  color: Colors.white,
                  onPressed: _choreography.clips.isNotEmpty
                      ? () {
                          _previewKey.currentState?.togglePlayPause();
                          setState(() {}); // Refresh UI
                        }
                      : null,
                ),

                // Total time
                SizedBox(
                  width: 60,
                  child: Text(
                    _formatDuration(_choreography.totalDurationMs),
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: _processingProgress),
                  const SizedBox(height: 8),
                  Text(
                    _processingStatus,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),

          // Export progress indicator
          if (_isExporting)
            Container(
              color: Colors.blue.withValues(alpha: 0.9),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: _exportProgress,
                    backgroundColor: Colors.blue[200],
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _exportStatus,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          // Timeline - drag clips to reorder, tap for options
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TimelineView(
              choreography: _choreography,
              currentPositionMs: _currentPositionMs,
              onSeek: _onSeek,
              onClipTap: _showClipOptions,
              onReorder: _reorderClips,
              onTransitionTap: _editTransition,
              selectedClipIndex: _selectedClipIndex,
            ),
          ),

          // Clip count and process button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_choreography.clips.length} clip${_choreography.clips.length == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                if (_choreography.clips.any((c) => c.needsProcessing))
                  TextButton.icon(
                    onPressed: _isProcessing ? null : _processClips,
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: const Text('Process'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange[300],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
          
          // Duck guide overlay
          DuckGuideOverlay(
            guide: _duckGuide,
            onDismiss: () => _duckGuide.dismiss(),
            onResume: () => _duckGuide.resume(),
            onReply: (value) => _duckGuide.handleReply(value),
            onExport: _exportVideo,
            onStabilizeAll: _stabilizeAllClips,
          ),
        ],
      ),
    );
  }
}
