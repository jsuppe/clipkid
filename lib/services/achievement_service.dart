import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/achievement.dart';

/// Persists achievement progress and checks unlock conditions.
class AchievementService {
  static Map<String, dynamic> _stats = {};
  static Set<String> _unlocked = {};
  static bool _loaded = false;

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/achievements.json');
      if (await file.exists()) {
        final data = json.decode(await file.readAsString()) as Map<String, dynamic>;
        _stats = Map<String, dynamic>.from(data['stats'] ?? {});
        _unlocked = Set<String>.from((data['unlocked'] as List?)?.cast<String>() ?? []);
      }
    } catch (_) {}
    _loaded = true;
  }

  static Future<void> _save() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/achievements.json');
      await file.writeAsString(json.encode({
        'stats': _stats,
        'unlocked': _unlocked.toList(),
      }));
    } catch (_) {}
  }

  /// Increment a stat counter and check for new unlocks.
  /// Returns list of newly unlocked achievements (empty if none).
  static Future<List<Achievement>> recordEvent(String event, {int count = 1}) async {
    await _ensureLoaded();
    _stats[event] = (_stats[event] as int? ?? 0) + count;
    await _save();
    return checkUnlocks();
  }

  /// Record that a specific thing was used (for exploration achievements).
  static Future<List<Achievement>> recordUsage(String feature) async {
    await _ensureLoaded();
    final usedSet = Set<String>.from((_stats['used_$feature'] as List?)?.cast<String>() ?? []);
    usedSet.add(feature);
    _stats['used_$feature'] = usedSet.toList();
    await _save();
    return checkUnlocks();
  }

  /// Check all achievement conditions, return newly unlocked ones.
  static Future<List<Achievement>> checkUnlocks() async {
    await _ensureLoaded();
    final newlyUnlocked = <Achievement>[];

    for (final ach in kAchievements) {
      if (_unlocked.contains(ach.id)) continue;
      if (_checkCondition(ach.id)) {
        _unlocked.add(ach.id);
        newlyUnlocked.add(ach);
      }
    }

    if (newlyUnlocked.isNotEmpty) await _save();
    return newlyUnlocked;
  }

  static bool _checkCondition(String id) {
    int stat(String key) => _stats[key] as int? ?? 0;

    switch (id) {
      case 'first_video': return stat('videos_created') >= 1;
      case 'first_share': return stat('videos_shared') >= 1;
      case 'first_mission': return stat('missions_completed') >= 1;
      case 'videos_5': return stat('videos_created') >= 5;
      case 'videos_10': return stat('videos_created') >= 10;
      case 'videos_25': return stat('videos_created') >= 25;
      case 'missions_5': return stat('missions_completed') >= 5;
      case 'missions_10': return stat('missions_completed') >= 10;
      case 'voice_changer': return stat('voice_changer_used') >= 1;
      case 'green_screen': return stat('green_screen_used') >= 1;
      case 'speed_ramp': return stat('speed_ramp_used') >= 1;
      case 'reaction': return stat('reactions_created') >= 1;
      case 'sound_effects': return stat('sound_effects_added') >= 10;
      default: return false;
    }
  }

  /// Get all achievements with their unlock status.
  static Future<List<(Achievement, bool)>> getAll() async {
    await _ensureLoaded();
    return kAchievements.map((a) => (a, _unlocked.contains(a.id))).toList();
  }

  static Future<int> get unlockedCount async {
    await _ensureLoaded();
    return _unlocked.length;
  }
}
