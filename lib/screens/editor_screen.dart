import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
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

  Future<void> _addVideos() async {
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
              Text(_choreography.name ?? 'New Project'),
              const SizedBox(width: 4),
              Icon(Icons.edit, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
        backgroundColor: Colors.grey[900],
        leading: Center(
          child: Text('🐥', style: TextStyle(fontSize: 24)),
        ),
        actions: [
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
