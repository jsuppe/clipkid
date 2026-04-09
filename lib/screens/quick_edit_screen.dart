import 'package:flutter/material.dart';
import '../models/choreography.dart';

/// Quick edit screen for speed, reverse, filters, and stickers
class QuickEditScreen extends StatefulWidget {
  final Clip clip;
  
  const QuickEditScreen({super.key, required this.clip});
  
  @override
  State<QuickEditScreen> createState() => _QuickEditScreenState();
}

class _QuickEditScreenState extends State<QuickEditScreen> {
  late double _speed;
  late bool _reverse;
  late VideoFilter _filter;
  late List<StickerOverlay> _stickers;
  
  // Available stickers for kids
  static const List<String> availableStickers = [
    '⭐', '🌟', '✨', '💫', '🔥', '❤️', '💖', '😎', '🤩', '😂',
    '🎉', '🎊', '🎈', '🦄', '🌈', '🍕', '🎮', '⚽', '🏀', '🎸',
    '👑', '💎', '🚀', '🛸', '👻', '🎃', '💀', '👽', '🤖', '🦖',
  ];
  
  @override
  void initState() {
    super.initState();
    _speed = widget.clip.effects.speed;
    _reverse = widget.clip.effects.reverse;
    _filter = widget.clip.effects.filter;
    _stickers = List.from(widget.clip.effects.stickers);
  }
  
  ClipEffects get _updatedEffects => widget.clip.effects.copyWith(
    speed: _speed,
    reverse: _reverse,
    filter: _filter,
    stickers: _stickers,
  );
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Quick Edit ✨'),
        backgroundColor: Colors.grey[850],
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _updatedEffects),
            child: const Text('Done', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Speed Control
            _buildSectionTitle('Speed 🏃'),
            _buildSpeedControl(),
            
            const SizedBox(height: 24),
            
            // Reverse
            _buildSectionTitle('Direction 🔄'),
            _buildReverseToggle(),
            
            const SizedBox(height: 24),
            
            // Filters
            _buildSectionTitle('Filter 🎨'),
            _buildFilterPicker(),
            
            const SizedBox(height: 24),
            
            // Stickers
            _buildSectionTitle('Stickers ${_stickers.isNotEmpty ? "(${_stickers.length})" : ""}'),
            _buildStickerPicker(),
            
            if (_stickers.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildStickerList(),
            ],
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildSpeedControl() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Speed presets
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSpeedButton('🐢', 0.5, 'Slow'),
              _buildSpeedButton('🚶', 1.0, 'Normal'),
              _buildSpeedButton('🏃', 1.5, 'Fast'),
              _buildSpeedButton('🚀', 2.0, 'Super'),
            ],
          ),
          const SizedBox(height: 16),
          // Fine-tune slider
          Row(
            children: [
              const Text('0.25x', style: TextStyle(color: Colors.grey, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _speed,
                  min: 0.25,
                  max: 3.0,
                  divisions: 11,
                  label: '${_speed.toStringAsFixed(2)}x',
                  activeColor: Colors.purple[400],
                  onChanged: (value) => setState(() => _speed = value),
                ),
              ),
              const Text('3x', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          Text(
            '${_speed.toStringAsFixed(2)}x speed',
            style: TextStyle(color: Colors.purple[300], fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSpeedButton(String emoji, double speed, String label) {
    final isSelected = (_speed - speed).abs() < 0.1;
    return GestureDetector(
      onTap: () => setState(() => _speed = speed),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple[600] : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.purple[300]!, width: 2) : null,
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[400], fontSize: 12)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildReverseToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _reverse = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: !_reverse ? Colors.blue[600] : Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text('▶️', style: TextStyle(fontSize: 28)),
                    const SizedBox(height: 4),
                    Text('Forward', style: TextStyle(color: !_reverse ? Colors.white : Colors.grey[400])),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _reverse = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _reverse ? Colors.orange[600] : Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text('◀️', style: TextStyle(fontSize: 28)),
                    const SizedBox(height: 4),
                    Text('Reverse', style: TextStyle(color: _reverse ? Colors.white : Colors.grey[400])),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterPicker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: VideoFilter.values.map((filter) {
          final isSelected = _filter == filter;
          return GestureDetector(
            onTap: () => setState(() => _filter = filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.purple[600] : Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
                border: isSelected ? Border.all(color: Colors.purple[300]!, width: 2) : null,
              ),
              child: Text(
                filter.displayName,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[300],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildStickerPicker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: availableStickers.map((emoji) {
          return GestureDetector(
            onTap: () {
              setState(() {
                _stickers.add(StickerOverlay(emoji: emoji));
              });
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildStickerList() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Added stickers:', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _stickers.asMap().entries.map((entry) {
              final index = entry.key;
              final sticker = entry.value;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _stickers.removeAt(index);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(sticker.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 4),
                      Icon(Icons.close, size: 16, color: Colors.red[300]),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text('Tap to remove', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        ],
      ),
    );
  }
}
