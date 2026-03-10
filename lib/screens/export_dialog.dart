import 'package:flutter/material.dart';

/// Export quality presets
enum ExportQuality {
  low('Low (480p)', 854, 480, 28),
  medium('Medium (720p)', 1280, 720, 23),
  high('High (1080p)', 1920, 1080, 20),
  ;

  final String label;
  final int width;
  final int height;
  final int crf;

  const ExportQuality(this.label, this.width, this.height, this.crf);
}

/// Export settings
class ExportSettings {
  final ExportQuality quality;
  final bool includeAudio;

  ExportSettings({
    this.quality = ExportQuality.medium,
    this.includeAudio = true,
  });

  ExportSettings copyWith({
    ExportQuality? quality,
    bool? includeAudio,
  }) =>
      ExportSettings(
        quality: quality ?? this.quality,
        includeAudio: includeAudio ?? this.includeAudio,
      );
}

/// Dialog to select export options
class ExportOptionsDialog extends StatefulWidget {
  final String projectName;
  final int clipCount;
  final int durationMs;

  const ExportOptionsDialog({
    super.key,
    required this.projectName,
    required this.clipCount,
    required this.durationMs,
  });

  @override
  State<ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<ExportOptionsDialog> {
  ExportSettings _settings = ExportSettings();

  String _formatDuration(int ms) {
    final seconds = (ms / 1000).floor();
    final minutes = (seconds / 60).floor();
    final secs = seconds % 60;
    return '${minutes}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('Export Video', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.movie, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.projectName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.clipCount} clips • ${_formatDuration(widget.durationMs)}',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Quality selector
          Text('Quality', style: TextStyle(color: Colors.grey[400])),
          const SizedBox(height: 8),
          ...ExportQuality.values.map((quality) => RadioListTile<ExportQuality>(
                title: Text(quality.label, style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  '${quality.width}×${quality.height}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                value: quality,
                groupValue: _settings.quality,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _settings = _settings.copyWith(quality: value);
                    });
                  }
                },
                activeColor: Colors.blue,
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),

          const SizedBox(height: 12),

          // Audio toggle
          SwitchListTile(
            title: const Text('Include Audio', style: TextStyle(color: Colors.white)),
            value: _settings.includeAudio,
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(includeAudio: value);
              });
            },
            activeColor: Colors.blue,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, _settings),
          icon: const Icon(Icons.movie_creation),
          label: const Text('Export'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
