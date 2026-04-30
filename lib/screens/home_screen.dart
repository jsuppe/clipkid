import 'package:flutter/material.dart';
import '../models/duck_mission.dart';
import '../models/template.dart';
import 'achievements_screen.dart';
import 'capture_template_screen.dart';
import 'editor_screen.dart';
import 'mission_capture_screen.dart';

/// Capture-first home screen. Duck mission card at top, template grid below,
/// small import link at bottom.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _startTemplate(BuildContext context, Template template) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CaptureTemplateScreen(template: template)),
    );
  }

  Future<void> _startMission(BuildContext context) async {
    final mission = DuckMission.random();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MissionCaptureScreen(mission: mission)),
    );
  }

  void _openImport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges button
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 12, top: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                      ),
                      child: const Center(child: Text('🏆', style: TextStyle(fontSize: 22))),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ClipKid 🎬',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pick a template or go on a duck mission!',
                          style: TextStyle(color: Colors.grey[400], fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Duck Mission card
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: _DuckMissionCard(onTap: () => _startMission(context)),
            ),
            // Template grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: kBundledTemplates.length,
                itemBuilder: (ctx, i) => _TemplateCard(
                  template: kBundledTemplates[i],
                  onTap: () => _startTemplate(ctx, kBundledTemplates[i]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: TextButton.icon(
                onPressed: () => _openImport(context),
                icon: Icon(Icons.video_library, color: Colors.grey[400]),
                label: Text(
                  'Import a video instead',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DuckMissionCard extends StatelessWidget {
  final VoidCallback onTap;
  const _DuckMissionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.withValues(alpha: 0.9),
              Colors.deepOrange.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            const Text('🦆', style: TextStyle(fontSize: 48)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Duck Mission',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Get a random challenge and film it!',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final Template template;
  final VoidCallback onTap;
  const _TemplateCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              template.accentColor.withValues(alpha: 0.85),
              template.accentColor.withValues(alpha: 0.45),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(template.emoji, style: const TextStyle(fontSize: 48))),
            Flexible(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  template.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  template.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${template.slotCount} shots',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )),
          ],
        ),
      ),
    );
  }
}
