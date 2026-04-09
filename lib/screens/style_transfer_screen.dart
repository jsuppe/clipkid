import 'dart:io';
import 'package:flutter/material.dart';
import '../models/choreography.dart';
import '../services/style_transfer_service.dart';

/// Result of a style transfer operation
class StyleTransferResult {
  final String path;
  final String styleName;
  
  StyleTransferResult({required this.path, required this.styleName});
}

/// Screen for applying AI style transfer to a video clip
class StyleTransferScreen extends StatefulWidget {
  final Clip clip;
  
  const StyleTransferScreen({
    super.key,
    required this.clip,
  });
  
  @override
  State<StyleTransferScreen> createState() => _StyleTransferScreenState();
}

class _StyleTransferScreenState extends State<StyleTransferScreen> {
  StylePreset _selectedStyle = StylePreset.cartoon;
  double _strength = 0.7;
  bool _isProcessing = false;
  String _status = '';
  double _progress = 0.0;
  String? _previewPath;
  String? _resultPath;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('AI Style Transfer'),
        backgroundColor: Colors.grey[850],
        actions: [
          if (_resultPath != null)
            TextButton.icon(
              onPressed: () => Navigator.pop(
                context,
                StyleTransferResult(
                  path: _resultPath!,
                  styleName: _selectedStyle.displayName,
                ),
              ),
              icon: const Icon(Icons.check, color: Colors.green),
              label: const Text('Use', style: TextStyle(color: Colors.green)),
            ),
        ],
      ),
      body: _buildMainContent(),
    );
  }
  
  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview area
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _previewPath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_previewPath!),
                      fit: BoxFit.contain,
                    ),
                  )
                : Center(
                    child: Text(
                      'Preview will appear here',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
          ),
          
          const SizedBox(height: 24),
          
          // Style selection
          Text(
            'Choose Style',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: StylePreset.values.map((style) {
              final isSelected = _selectedStyle == style;
              return ChoiceChip(
                label: Text(style.displayName),
                selected: isSelected,
                onSelected: _isProcessing ? null : (selected) {
                  if (selected) {
                    setState(() => _selectedStyle = style);
                  }
                },
                selectedColor: Colors.purple[400],
                backgroundColor: Colors.grey[800],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[300],
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          
          // Strength slider
          Text(
            'Style Strength: ${(_strength * 100).round()}%',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Original', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _strength,
                  min: 0.3,
                  max: 0.95,
                  onChanged: _isProcessing ? null : (value) {
                    setState(() => _strength = value);
                  },
                  activeColor: Colors.purple[400],
                ),
              ),
              Text('Stylized', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Progress indicator
          if (_isProcessing) ...[
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation(Colors.purple[400]),
            ),
            const SizedBox(height: 8),
            Text(
              _status,
              style: TextStyle(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _previewFrame,
                  icon: const Icon(Icons.preview),
                  label: const Text('Preview Frame'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _transformVideo,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Transform Video'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Info text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[900]?.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[300], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Preview tests one frame. Full transform processes the whole video (may take a few minutes).',
                    style: TextStyle(color: Colors.blue[200], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _previewFrame() async {
    setState(() {
      _isProcessing = true;
      _status = 'Extracting frame...';
      _progress = 0;
    });
    
    try {
      final service = StyleTransferService();
      
      // Extract a single frame from the video
      final tempDir = Directory.systemTemp;
      final framePath = '${tempDir.path}/preview_frame_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Extract frame at 1 second (or start if shorter)
      final result = await Process.run('ffmpeg', [
        '-i', widget.clip.playbackPath,
        '-ss', '1',
        '-vframes', '1',
        '-y',
        framePath,
      ]);
      
      if (result.exitCode != 0) {
        throw Exception('Failed to extract frame');
      }
      
      // Transform the frame
      final styled = await service.transformImage(
        inputImage: File(framePath),
        style: _selectedStyle,
        strength: _strength,
        onProgress: (status) {
          setState(() => _status = status);
        },
      );
      
      if (styled != null) {
        setState(() {
          _previewPath = styled.path;
        });
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
        _status = '';
      });
    }
  }
  
  Future<void> _transformVideo() async {
    setState(() {
      _isProcessing = true;
      _status = 'Starting transformation...';
      _progress = 0;
    });
    
    try {
      final service = StyleTransferService();
      
      final outputPath = await service.transformVideo(
        inputVideoPath: widget.clip.playbackPath,
        style: _selectedStyle,
        strength: _strength,
        frameInterval: 3, // Process every 3rd frame for speed
        onProgress: (progress, status) {
          setState(() {
            _progress = progress;
            _status = status;
          });
        },
      );
      
      if (outputPath != null) {
        setState(() {
          _resultPath = outputPath;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video transformed! Tap "Use" to apply.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
}
