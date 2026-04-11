import 'package:flutter/material.dart';
import '../models/choreography.dart';
import '../widgets/text_overlay_style.dart';

/// Kid-friendly text editor. Flow:
/// 1. Type text (or pick a suggestion chip)
/// 2. Pick a style from a scrollable row of live previews
/// 3. Pick timing (3 big buttons)
/// 4. Done — returns a TextOverlay
class TextEditorScreen extends StatefulWidget {
  final TextOverlay? existing;

  const TextEditorScreen({super.key, this.existing});

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  late TextEditingController _controller;
  late TextStylePreset _style;
  late OverlayTiming _timing;

  // Pre-written suggestions — kids often freeze on what to type
  static const _suggestions = [
    'Wait for it...',
    'Watch this!',
    'LOL',
    'OMG',
    'Part 1',
    'The End',
    'Check it out',
    'Oops!',
    'Look!',
    'Best day ever',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existing?.text ?? '');
    _style = widget.existing?.style ?? TextStylePreset.title;
    _timing = widget.existing?.timing ?? OverlayTiming.wholeClip;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type something first!')),
      );
      return;
    }
    final overlay = TextOverlay(
      text: text,
      style: _style,
      x: widget.existing?.x,
      y: widget.existing?.y,
      scale: widget.existing?.scale ?? 1.0,
      timing: _timing,
    );
    Navigator.pop(context, overlay);
  }

  @override
  Widget build(BuildContext context) {
    final previewText = _controller.text.trim().isEmpty ? 'Your text' : _controller.text;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
        title: const Text('Add Text 📝'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'DONE',
              style: TextStyle(
                color: Colors.yellow,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live preview of current choice
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: Center(
                child: StyledOverlayText(
                  text: previewText,
                  style: _style,
                  baseFontSize: 36,
                ),
              ),
            ),
          ),

          // Input + suggestions + style picker + timing
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text input
                  TextField(
                    controller: _controller,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    autofocus: widget.existing == null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type your text here...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),

                  // Suggestion chips
                  const Text(
                    'Or try one of these:',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestions.map((s) => ActionChip(
                          backgroundColor: Colors.grey[800],
                          label: Text(s, style: const TextStyle(color: Colors.white)),
                          onPressed: () {
                            _controller.text = s;
                            _controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: s.length),
                            );
                            setState(() {});
                          },
                        )).toList(),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Pick a look:',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Style picker — horizontal scrollable row of live previews
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: TextStylePreset.values.length,
                      itemBuilder: (ctx, i) {
                        final s = TextStylePreset.values[i];
                        final selected = s == _style;
                        return GestureDetector(
                          onTap: () => setState(() => _style = s),
                          child: Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? Colors.yellow : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: StyledOverlayText(
                                          text: 'Text',
                                          style: s,
                                          baseFontSize: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    s.displayName,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'When to show:',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Timing — 3 big buttons
                  Row(
                    children: OverlayTiming.values.map((t) {
                      final selected = t == _timing;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _timing = t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: selected ? Colors.yellow : Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                t.displayName,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: selected ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
