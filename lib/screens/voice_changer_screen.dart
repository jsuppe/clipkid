import 'package:flutter/material.dart';
import '../models/choreography.dart';

/// Picker for voice effect presets. Returns selected [VoiceEffect].
class VoiceChangerScreen extends StatelessWidget {
  final VoiceEffect current;
  const VoiceChangerScreen({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
        title: const Text('Voice Changer 🎤'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Pick a voice effect — applied during export',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          for (final effect in VoiceEffect.values)
            _VoiceCard(
              effect: effect,
              selected: effect == current,
              onTap: () => Navigator.pop(context, effect),
            ),
        ],
      ),
    );
  }
}

class _VoiceCard extends StatelessWidget {
  final VoiceEffect effect;
  final bool selected;
  final VoidCallback onTap;

  const _VoiceCard({required this.effect, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? Colors.deepPurple.withValues(alpha: 0.3) : Colors.grey[850],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.deepPurple : Colors.grey[700]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    effect.displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (effect.description.isNotEmpty)
                    Text(
                      effect.description,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Colors.deepPurple, size: 28),
          ],
        ),
      ),
    );
  }
}
