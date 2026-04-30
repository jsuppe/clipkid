/// An achievement badge that kids can earn.
class Achievement {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final String category;

  const Achievement({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.category,
  });
}

const kAchievements = [
  // Getting started
  Achievement(id: 'first_video', name: 'First Take', emoji: '🎬', description: 'Create your first video', category: 'Getting Started'),
  Achievement(id: 'first_share', name: 'Broadcaster', emoji: '📡', description: 'Share a video for the first time', category: 'Getting Started'),
  Achievement(id: 'first_mission', name: 'Mission Accepted', emoji: '🦆', description: 'Complete your first duck mission', category: 'Getting Started'),

  // Volume
  Achievement(id: 'videos_5', name: 'On a Roll', emoji: '🎞️', description: 'Create 5 videos', category: 'Creator'),
  Achievement(id: 'videos_10', name: 'Film Buff', emoji: '🎥', description: 'Create 10 videos', category: 'Creator'),
  Achievement(id: 'videos_25', name: 'Director', emoji: '🎭', description: 'Create 25 videos', category: 'Creator'),
  Achievement(id: 'missions_5', name: 'Duck Squad', emoji: '🦆', description: 'Complete 5 duck missions', category: 'Creator'),
  Achievement(id: 'missions_10', name: 'Mission Master', emoji: '🏆', description: 'Complete 10 duck missions', category: 'Creator'),

  // Exploration
  Achievement(id: 'all_templates', name: 'Template Tourist', emoji: '🗺️', description: 'Try every template at least once', category: 'Explorer'),
  Achievement(id: 'all_filters', name: 'Filter Fanatic', emoji: '🎨', description: 'Try every color filter', category: 'Explorer'),
  Achievement(id: 'voice_changer', name: 'Voice Actor', emoji: '🎤', description: 'Use a voice changer effect', category: 'Explorer'),
  Achievement(id: 'green_screen', name: 'Hollywood', emoji: '🟩', description: 'Use the green screen', category: 'Explorer'),
  Achievement(id: 'speed_ramp', name: 'Time Bender', emoji: '⏱️', description: 'Use a speed ramp', category: 'Explorer'),
  Achievement(id: 'reaction', name: 'React!', emoji: '😮', description: 'Create a reaction video', category: 'Explorer'),
  Achievement(id: 'sound_effects', name: 'Sound Designer', emoji: '🔊', description: 'Add 10 sound effects total', category: 'Explorer'),

  // Mastery
  Achievement(id: 'all_missions', name: 'Mission Complete', emoji: '⭐', description: 'Complete every type of duck mission', category: 'Mastery'),
  Achievement(id: 'pro_editor', name: 'Pro Editor', emoji: '💎', description: 'Use 5+ effects on a single video', category: 'Mastery'),
];
