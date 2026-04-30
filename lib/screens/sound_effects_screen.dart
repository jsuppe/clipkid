import 'package:flutter/material.dart';
import '../models/choreography.dart';
import '../models/sound_effect.dart';
import '../services/sound_effect_player.dart';

/// Grid of sound effects. Tap to preview, tap "+" to add at current position.
/// tap "Add" to place at the current timeline position.
class SoundEffectsScreen extends StatelessWidget {
  final int currentPositionMs; // global timeline position
  final int clipStartMs; // start of the selected clip

  const SoundEffectsScreen({
    super.key,
    required this.currentPositionMs,
    required this.clipStartMs,
  });

  @override
  Widget build(BuildContext context) {
    final categories = <String, List<SoundEffect>>{};
    for (final fx in kSoundEffects) {
      categories.putIfAbsent(fx.category, () => []).add(fx);
    }

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
        title: const Text('Sound Effects 🔊'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Text(
              'Tap to preview, double-tap or long-press to add',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ),
          for (final entry in categories.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              child: Text(
                entry.key,
                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 1.0,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: entry.value.map((fx) => _SoundEffectTile(
                effect: fx,
                onAdd: () {
                  final localMs = currentPositionMs - clipStartMs;
                  final overlay = SoundEffectOverlay(
                    effectId: fx.id,
                    startMs: localMs.clamp(0, 999999),
                  );
                  Navigator.pop(context, overlay);
                },
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SoundEffectTile extends StatelessWidget {
  final SoundEffect effect;
  final VoidCallback onAdd;

  const _SoundEffectTile({required this.effect, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => SoundEffectPlayer.preview(effect.id), // tap = preview
      onLongPress: onAdd, // long press = add to timeline
      onDoubleTap: onAdd, // double tap = also adds
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[700]!, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(effect.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 4),
            Text(
              effect.name,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${(effect.durationMs / 1000).toStringAsFixed(1)}s',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
