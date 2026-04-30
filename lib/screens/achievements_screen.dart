import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../services/achievement_service.dart';

/// Badge gallery showing all achievements and their unlock status.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<(Achievement, bool)> _achievements = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await AchievementService.getAll();
    if (mounted) setState(() => _achievements = all);
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _achievements.where((a) => a.$2).length;
    final total = _achievements.length;

    // Group by category
    final categories = <String, List<(Achievement, bool)>>{};
    for (final entry in _achievements) {
      categories.putIfAbsent(entry.$1.category, () => []).add(entry);
    }

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
        title: Text('Badges ($unlocked/$total)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Progress bar
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total > 0 ? unlocked / total : 0,
                    minHeight: 10,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation(Colors.amber),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  unlocked == total ? 'All badges unlocked!' : '$unlocked of $total badges earned',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
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
              childAspectRatio: 0.85,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: entry.value.map((pair) => _BadgeTile(achievement: pair.$1, unlocked: pair.$2)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;

  const _BadgeTile({required this.achievement, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: unlocked ? Colors.amber.withValues(alpha: 0.15) : Colors.grey[850],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unlocked ? Colors.amber : Colors.grey[800]!,
          width: unlocked ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            unlocked ? achievement.emoji : '🔒',
            style: TextStyle(fontSize: 28, color: unlocked ? null : Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            achievement.name,
            style: TextStyle(
              color: unlocked ? Colors.white : Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            achievement.description,
            style: TextStyle(color: unlocked ? Colors.white54 : Colors.white24, fontSize: 9),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Popup shown when a badge is newly earned.
class AchievementPopup extends StatelessWidget {
  final Achievement achievement;
  const AchievementPopup({super.key, required this.achievement});

  static Future<void> show(BuildContext context, Achievement achievement) {
    return showDialog(
      context: context,
      builder: (_) => AchievementPopup(achievement: achievement),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Badge Earned!', style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(achievement.emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              achievement.name,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              achievement.description,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Awesome!', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
