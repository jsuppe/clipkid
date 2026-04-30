import 'package:flutter/material.dart';
import '../models/choreography.dart';

/// Green screen / chroma key settings. Returns [ChromaKeySettings] or null to disable.
class GreenScreenScreen extends StatefulWidget {
  final ChromaKeySettings? current;
  const GreenScreenScreen({super.key, this.current});

  @override
  State<GreenScreenScreen> createState() => _GreenScreenScreenState();
}

class _GreenScreenScreenState extends State<GreenScreenScreen> {
  late double _hue;
  late double _similarity;
  late double _blend;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _enabled = c != null;
    _hue = c?.hue ?? 120;
    _similarity = c?.similarity ?? 0.3;
    _blend = c?.blend ?? 0.1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
        title: const Text('Green Screen 🟩'),
        actions: [
          TextButton(
            onPressed: () {
              if (_enabled) {
                Navigator.pop(context, ChromaKeySettings(
                  hue: _hue,
                  similarity: _similarity,
                  blend: _blend,
                ));
              } else {
                Navigator.pop(context, 'disabled');
              }
            },
            child: const Text('Apply', style: TextStyle(color: Colors.green, fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            title: const Text('Enable Chroma Key', style: TextStyle(color: Colors.white)),
            value: _enabled,
            activeColor: Colors.green,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          if (_enabled) ...[
            const SizedBox(height: 24),
            const Text('Key Color', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _colorChip('Green', Colors.green, 120),
                _colorChip('Blue', Colors.blue, 240),
                _colorChip('Red', Colors.red, 0),
              ],
            ),
            const SizedBox(height: 24),
            _slider('Similarity', _similarity, 0.05, 0.8, (v) => setState(() => _similarity = v),
                'How close to the key color to remove'),
            _slider('Edge Blend', _blend, 0.0, 0.5, (v) => setState(() => _blend = v),
                'Smoothness of the edges'),
            const SizedBox(height: 24),
            // Preview of ffmpeg filter
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ffmpeg: ${ChromaKeySettings(hue: _hue, similarity: _similarity, blend: _blend).ffmpegFilter}',
                style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _colorChip(String label, Color color, double hue) {
    final selected = (_hue - hue).abs() < 30;
    return GestureDetector(
      onTap: () => setState(() => _hue = hue),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12)]
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          )),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const Spacer(),
            Text(value.toStringAsFixed(2), style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: Colors.green,
          onChanged: onChanged,
        ),
        Text(hint, style: const TextStyle(color: Colors.white24, fontSize: 11)),
        const SizedBox(height: 12),
      ],
    );
  }
}
