import 'package:audioplayers/audioplayers.dart';
import '../models/sound_effect.dart';

/// Plays sound effects from bundled assets. Used for preview in the
/// sound effects board and for real-time playback during preview.
class SoundEffectPlayer {
  static final _player = AudioPlayer();

  /// Preview a sound effect (tap in the sound board).
  static Future<void> preview(String effectId) async {
    final fx = soundEffectById(effectId);
    if (fx == null) return;
    await _player.stop();
    await _player.play(AssetSource('sounds/${fx.id}.wav'));
  }

  /// Play a sound effect at a given volume.
  static Future<void> play(String effectId, {double volume = 1.0}) async {
    final fx = soundEffectById(effectId);
    if (fx == null) return;
    // Use a fresh player instance for overlapping sounds
    final p = AudioPlayer();
    await p.setVolume(volume);
    await p.play(AssetSource('sounds/${fx.id}.wav'));
    // Auto-dispose after playback
    p.onPlayerComplete.listen((_) => p.dispose());
  }

  static Future<void> dispose() async {
    await _player.dispose();
  }
}
