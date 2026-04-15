import 'package:flutter/material.dart';
import '../models/template.dart';
import '../services/project_service.dart';
import 'pexels_browser_screen.dart';

/// Shows the template's slots as a vertical list. Each slot has a tap-to-pick
/// button. When every slot is filled, the "Make Video!" button lights up.
/// On tap, instantiates the template into a Choreography and pops it back.
class TemplateFillScreen extends StatefulWidget {
  final Template template;
  const TemplateFillScreen({super.key, required this.template});

  @override
  State<TemplateFillScreen> createState() => _TemplateFillScreenState();
}

class _TemplateFillScreenState extends State<TemplateFillScreen> {
  late List<String?> _clipPaths; // one entry per slot; null = not filled
  late List<int> _clipDurations; // placeholder, resolved later
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _clipPaths = List.filled(widget.template.slots.length, null);
    _clipDurations = List.filled(widget.template.slots.length, 3000);
  }

  bool get _allFilled => _clipPaths.every((p) => p != null);

  Future<void> _pickClipForSlot(int slotIndex) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Where should this clip come from?',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue, size: 32),
              title: const Text('From my gallery', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.public, color: Colors.green, size: 32),
              title: const Text('Browse stock videos 🎬', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'pexels'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    String? path;
    if (source == 'gallery') {
      final videos = await ProjectService.pickVideos();
      if (videos != null && videos.isNotEmpty) {
        path = videos.first.path;
      }
    } else if (source == 'pexels') {
      path = await Navigator.push<String?>(
        context,
        MaterialPageRoute(builder: (_) => const PexelsBrowserScreen()),
      );
    }

    if (path == null) return;

    // Probe duration in the background
    setState(() {
      _clipPaths[slotIndex] = path;
      _resolving = true;
    });

    try {
      final durationMs = await ProjectService.getVideoDurationMs(path);
      if (!mounted) return;
      setState(() {
        _clipDurations[slotIndex] = durationMs > 0 ? durationMs : 3000;
        _resolving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _resolving = false);
    }
  }

  void _makeVideo() {
    if (!_allFilled) return;
    final choreography = widget.template.instantiate(
      clipPaths: _clipPaths.cast<String>(),
      clipDurationsMs: _clipDurations,
    );
    Navigator.pop(context, choreography);
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: template.accentColor,
        foregroundColor: Colors.white,
        title: Text('${template.emoji} ${template.name}'),
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: template.accentColor.withValues(alpha: 0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.description,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fill in ${template.slotCount} clips below',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          // Slot list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: template.slots.length,
              itemBuilder: (ctx, i) => _buildSlotCard(i),
            ),
          ),
          // Big Make Video button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _allFilled && !_resolving ? _makeVideo : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: template.accentColor,
                  disabledBackgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _allFilled ? 'Make Video! 🎬' : 'Add ${_clipPaths.where((p) => p == null).length} more clip${_clipPaths.where((p) => p == null).length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _allFilled ? Colors.white : Colors.grey[500],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(int i) {
    final slot = widget.template.slots[i];
    final filled = _clipPaths[i] != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: filled ? widget.template.accentColor : Colors.grey[700]!,
          width: filled ? 3 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _pickClipForSlot(i),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Number circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: filled ? widget.template.accentColor : Colors.grey[800],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: filled
                      ? const Icon(Icons.check, color: Colors.white, size: 28)
                      : Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      slot.hint,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    if (filled) ...[
                      const SizedBox(height: 6),
                      Text(
                        '✓ ${_clipPaths[i]!.split('/').last}',
                        style: TextStyle(
                          color: widget.template.accentColor,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
