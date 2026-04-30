import 'dart:math';

/// A freeform capture mission from the duck. Unlike templates, missions
/// don't have fixed slots — the kid records as many clips as they want
/// following the mission theme.
class DuckMission {
  final String id;
  final String title;
  final String prompt; // what the duck says
  final String emoji;
  final int maxSecondsPerClip;
  final int suggestedClips; // hint, not enforced

  const DuckMission({
    required this.id,
    required this.title,
    required this.prompt,
    required this.emoji,
    this.maxSecondsPerClip = 5,
    this.suggestedClips = 3,
  });

  static DuckMission random() {
    final r = Random();
    return kMissions[r.nextInt(kMissions.length)];
  }
}

const kMissions = [
  DuckMission(
    id: 'blue_things',
    title: '3 Blue Things',
    prompt: 'Find 3 things that are blue and film each one!',
    emoji: '🔵',
    suggestedClips: 3,
  ),
  DuckMission(
    id: 'sounds',
    title: 'Cool Sounds',
    prompt: 'Record 3 interesting sounds around you',
    emoji: '🔊',
    suggestedClips: 3,
  ),
  DuckMission(
    id: 'tiny_world',
    title: 'Tiny World',
    prompt: 'Get super close to small things — make them look giant',
    emoji: '🔍',
    suggestedClips: 4,
    maxSecondsPerClip: 4,
  ),
  DuckMission(
    id: 'upside_down',
    title: 'Upside Down',
    prompt: 'Flip the camera and film things from a weird angle',
    emoji: '🙃',
    suggestedClips: 3,
    maxSecondsPerClip: 4,
  ),
  DuckMission(
    id: 'speed_round',
    title: 'Speed Round',
    prompt: 'Film 5 different things as fast as you can — GO!',
    emoji: '⚡',
    suggestedClips: 5,
    maxSecondsPerClip: 3,
  ),
  DuckMission(
    id: 'textures',
    title: 'Feel the Texture',
    prompt: 'Find 3 things with cool textures and film them close up',
    emoji: '🧱',
    suggestedClips: 3,
    maxSecondsPerClip: 5,
  ),
  DuckMission(
    id: 'shadow_hunt',
    title: 'Shadow Hunt',
    prompt: 'Find cool shadows and film them',
    emoji: '👤',
    suggestedClips: 3,
    maxSecondsPerClip: 5,
  ),
  DuckMission(
    id: 'favorite_spot',
    title: 'My Favorite Spot',
    prompt: 'Show your favorite place and tell us why you love it',
    emoji: '📍',
    suggestedClips: 3,
    maxSecondsPerClip: 6,
  ),
  DuckMission(
    id: 'what_i_see',
    title: 'What I See Right Now',
    prompt: 'Look around — film everything interesting you can see',
    emoji: '👀',
    suggestedClips: 4,
    maxSecondsPerClip: 4,
  ),
  DuckMission(
    id: 'one_word',
    title: 'One Word Story',
    prompt: 'Each clip = one word. Tell a story one word at a time!',
    emoji: '💬',
    suggestedClips: 6,
    maxSecondsPerClip: 2,
  ),
  DuckMission(
    id: 'matching',
    title: 'Match the Colors',
    prompt: 'Find things that match in color — film pairs of them',
    emoji: '🎨',
    suggestedClips: 4,
    maxSecondsPerClip: 4,
  ),
  DuckMission(
    id: 'action_shots',
    title: 'Action Shots',
    prompt: 'Film things that are moving — people, pets, wheels, wind',
    emoji: '🏃',
    suggestedClips: 3,
    maxSecondsPerClip: 5,
  ),
];
