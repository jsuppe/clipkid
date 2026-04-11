import 'package:flutter/material.dart';
import '../models/template.dart';
import 'template_fill_screen.dart';

/// Grid of all bundled templates. Tap one to start filling it with clips.
class TemplatesGalleryScreen extends StatelessWidget {
  const TemplatesGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
        title: const Text('Start from a template ✨'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Text(
              'Pick a template, drop in your clips, done!',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: kBundledTemplates.length,
            itemBuilder: (ctx, i) => _TemplateCard(template: kBundledTemplates[i]),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final Template template;
  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final choreography = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TemplateFillScreen(template: template)),
        );
        if (choreography != null && context.mounted) {
          // Pass the completed choreography back up to the editor
          Navigator.pop(context, choreography);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              template.accentColor.withValues(alpha: 0.8),
              template.accentColor.withValues(alpha: 0.4),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              template.emoji,
              style: const TextStyle(fontSize: 56),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  template.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${template.slotCount} clips',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
