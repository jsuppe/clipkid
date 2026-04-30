/// Catalog of available sound effects.
class SoundEffect {
  final String id;
  final String name;
  final String emoji;
  final String category;
  final int durationMs;

  const SoundEffect({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.durationMs,
  });
}

const kSoundEffects = [
  // Comedy
  SoundEffect(id: 'rimshot', name: 'Ba Dum Tss', emoji: '🥁', category: 'Comedy', durationMs: 1200),
  SoundEffect(id: 'laugh', name: 'Laugh Track', emoji: '😂', category: 'Comedy', durationMs: 2000),
  SoundEffect(id: 'boing', name: 'Boing', emoji: '🦘', category: 'Comedy', durationMs: 500),
  SoundEffect(id: 'fart', name: 'Whoopee', emoji: '💨', category: 'Comedy', durationMs: 600),
  SoundEffect(id: 'slide_whistle', name: 'Slide Whistle', emoji: '🎵', category: 'Comedy', durationMs: 800),
  // Action
  SoundEffect(id: 'whoosh', name: 'Whoosh', emoji: '💨', category: 'Action', durationMs: 400),
  SoundEffect(id: 'explosion', name: 'Boom', emoji: '💥', category: 'Action', durationMs: 1500),
  SoundEffect(id: 'punch', name: 'Punch', emoji: '👊', category: 'Action', durationMs: 300),
  SoundEffect(id: 'laser', name: 'Laser', emoji: '🔫', category: 'Action', durationMs: 500),
  SoundEffect(id: 'sword', name: 'Sword', emoji: '⚔️', category: 'Action', durationMs: 400),
  // Reactions
  SoundEffect(id: 'applause', name: 'Applause', emoji: '👏', category: 'Reactions', durationMs: 2500),
  SoundEffect(id: 'gasp', name: 'Gasp', emoji: '😱', category: 'Reactions', durationMs: 800),
  SoundEffect(id: 'aww', name: 'Aww', emoji: '🥺', category: 'Reactions', durationMs: 1000),
  SoundEffect(id: 'record_scratch', name: 'Record Scratch', emoji: '💿', category: 'Reactions', durationMs: 600),
  SoundEffect(id: 'tada', name: 'Ta-da!', emoji: '🎉', category: 'Reactions', durationMs: 1200),
  // Music
  SoundEffect(id: 'ding', name: 'Ding', emoji: '🔔', category: 'Music', durationMs: 500),
  SoundEffect(id: 'horn', name: 'Air Horn', emoji: '📯', category: 'Music', durationMs: 800),
  SoundEffect(id: 'vinyl', name: 'Vinyl Pop', emoji: '🎶', category: 'Music', durationMs: 300),
];

/// Lookup a sound effect by ID.
SoundEffect? soundEffectById(String id) {
  for (final fx in kSoundEffects) {
    if (fx.id == id) return fx;
  }
  return null;
}
