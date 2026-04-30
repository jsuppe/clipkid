import 'package:audioplayers/audioplayers.dart';

/// Audio feedback during capture: countdown beeps, go chime, done chime.
class CaptureAudio {
  static final _player = AudioPlayer();

  /// Play the countdown beep (3, 2, 1).
  static Future<void> beep() async {
    await _player.stop();
    await _player.play(AssetSource('sounds/beep.wav'));
  }

  /// Play the "go!" chime when recording starts.
  static Future<void> go() async {
    await _player.stop();
    await _player.play(AssetSource('sounds/beep_go.wav'));
  }

  /// Play the "done" chime when recording stops.
  static Future<void> done() async {
    await _player.stop();
    await _player.play(AssetSource('sounds/beep_done.wav'));
  }

  static Future<void> dispose() async {
    await _player.dispose();
  }
}
