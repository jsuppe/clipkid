import 'package:flutter/material.dart';
import '../models/choreography.dart';

/// Music picker screen for adding background music
class MusicPickerScreen extends StatefulWidget {
  final MusicTrack currentTrack;
  final double currentVolume;
  final bool keepOriginalAudio;
  
  const MusicPickerScreen({
    super.key,
    required this.currentTrack,
    required this.currentVolume,
    required this.keepOriginalAudio,
  });
  
  @override
  State<MusicPickerScreen> createState() => _MusicPickerScreenState();
}

class _MusicPickerScreenState extends State<MusicPickerScreen> {
  late MusicTrack _selectedTrack;
  late double _volume;
  late bool _keepOriginalAudio;
  
  @override
  void initState() {
    super.initState();
    _selectedTrack = widget.currentTrack;
    _volume = widget.currentVolume;
    _keepOriginalAudio = widget.keepOriginalAudio;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Add Music 🎵'),
        backgroundColor: Colors.grey[850],
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, {
              'track': _selectedTrack,
              'volume': _volume,
              'keepOriginal': _keepOriginalAudio,
            }),
            child: const Text('Done', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Music tracks
            _buildSectionTitle('Choose a track 🎶'),
            _buildTrackList(),
            
            const SizedBox(height: 24),
            
            // Volume control
            _buildSectionTitle('Music volume'),
            _buildVolumeControl(),
            
            const SizedBox(height: 24),
            
            // Original audio toggle
            _buildSectionTitle('Original sound'),
            _buildOriginalAudioToggle(),
            
            const SizedBox(height: 24),
            
            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[900]?.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[300], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Music will be added when you export your video.',
                      style: TextStyle(color: Colors.blue[200], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
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
  
  Widget _buildTrackList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: MusicTrack.values.map((track) {
          final isSelected = _selectedTrack == track;
          return ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? Colors.purple[600] : Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  track == MusicTrack.none ? Icons.music_off : Icons.music_note,
                  color: isSelected ? Colors.white : Colors.grey[400],
                ),
              ),
            ),
            title: Text(
              track.displayName,
              style: TextStyle(
                color: isSelected ? Colors.purple[300] : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: isSelected 
                ? Icon(Icons.check_circle, color: Colors.purple[300])
                : null,
            onTap: () => setState(() => _selectedTrack = track),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildVolumeControl() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.volume_down, color: Colors.grey[400]),
              Expanded(
                child: Slider(
                  value: _volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  activeColor: Colors.purple[400],
                  onChanged: (value) => setState(() => _volume = value),
                ),
              ),
              Icon(Icons.volume_up, color: Colors.grey[400]),
            ],
          ),
          Text(
            '${(_volume * 100).round()}%',
            style: TextStyle(color: Colors.purple[300], fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOriginalAudioToggle() {
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
              onTap: () => setState(() => _keepOriginalAudio = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _keepOriginalAudio ? Colors.green[600] : Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.merge_type, color: _keepOriginalAudio ? Colors.white : Colors.grey[400], size: 28),
                    const SizedBox(height: 4),
                    Text('Mix both', style: TextStyle(color: _keepOriginalAudio ? Colors.white : Colors.grey[400])),
                    Text('🎤 + 🎵', style: TextStyle(fontSize: 12, color: _keepOriginalAudio ? Colors.white70 : Colors.grey[600])),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _keepOriginalAudio = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: !_keepOriginalAudio ? Colors.orange[600] : Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.music_note, color: !_keepOriginalAudio ? Colors.white : Colors.grey[400], size: 28),
                    const SizedBox(height: 4),
                    Text('Music only', style: TextStyle(color: !_keepOriginalAudio ? Colors.white : Colors.grey[400])),
                    Text('🎵 only', style: TextStyle(fontSize: 12, color: !_keepOriginalAudio ? Colors.white70 : Colors.grey[600])),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
