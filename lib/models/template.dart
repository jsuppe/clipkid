import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'choreography.dart';

/// A single slot in a template — a placeholder for a clip the kid will pick.
class TemplateSlot {
  final String label; // "Opening", "Main Action"
  final String hint; // "Something dramatic to grab attention"
  final ClipEffects effects;
  final Transition outgoingTransition;
  final int maxSeconds; // cap for guided capture auto-stop

  const TemplateSlot({
    required this.label,
    required this.hint,
    this.effects = const ClipEffects(),
    this.outgoingTransition = const Transition(),
    this.maxSeconds = 5,
  });
}

/// A template is a pre-built project shape — kids pick a template, fill in
/// the slots with their clips, and get a finished video with effects, text,
/// and transitions already applied.
class Template {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final Color accentColor;
  final List<TemplateSlot> slots;

  const Template({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.accentColor,
    required this.slots,
  });

  int get slotCount => slots.length;

  /// Instantiate this template into a real Choreography using the provided
  /// [clipPaths] and their corresponding [clipDurationsMs]. The lists must
  /// match the number of slots in the template.
  Choreography instantiate({
    required List<String> clipPaths,
    required List<int> clipDurationsMs,
  }) {
    assert(clipPaths.length == slots.length);
    assert(clipDurationsMs.length == slots.length);
    const uuid = Uuid();
    final clips = <Clip>[];
    int timelineStart = 0;
    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final duration = clipDurationsMs[i];
      clips.add(
        Clip(
          id: uuid.v4(),
          path: clipPaths[i],
          startMs: timelineStart,
          sourceDurationMs: duration,
          name: slot.label,
          effects: slot.effects,
          outgoingTransition:
              i < slots.length - 1 ? slot.outgoingTransition : const Transition(),
        ),
      );
      timelineStart += duration;
    }
    return Choreography(
      version: 1,
      clips: clips,
      name: name,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );
  }
}

// ============================================================================
// Bundled templates
// ============================================================================

final List<Template> kBundledTemplates = [
  _showAndTell,
  _dance,
  _roomTour,
  _howTo,
  _joke,
  _threeFavorites,
  _spaceAdventure,
  _petShow,
  _unboxing,
  _dayInLife,
];

final _showAndTell = Template(
  id: 'show_and_tell',
  name: 'Show & Tell',
  emoji: '🎤',
  description: 'Introduce something cool in 4 quick shots',
  accentColor: const Color(0xFF007AFF),
  slots: [
    TemplateSlot(
      label: 'Hi, I\'m...',
      hint: 'Say your name and what you\'re showing today',
      maxSeconds: 5,
      effects: ClipEffects(
        textOverlays: [
          TextOverlay(
            text: 'Show & Tell',
            style: TextStylePreset.title,
            timing: OverlayTiming.firstTwoSeconds,
          ),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.fade, durationMs: 400),
    ),
    TemplateSlot(
      label: 'Here it is',
      hint: 'Close-up of the thing — show it clearly',
      maxSeconds: 5,
      effects: ClipEffects(
        textOverlays: [
          TextOverlay(
            text: 'Check it out!',
            style: TextStylePreset.bubble,
            timing: OverlayTiming.firstTwoSeconds,
          ),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.slideLeft, durationMs: 400),
    ),
    TemplateSlot(
      label: 'One cool thing',
      hint: 'Tell us the coolest fact or feature',
      maxSeconds: 6,
      effects: ClipEffects(
        textOverlays: [
          TextOverlay(
            text: 'Did you know?',
            style: TextStylePreset.comic,
            timing: OverlayTiming.firstTwoSeconds,
          ),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.fade, durationMs: 400),
    ),
    TemplateSlot(
      label: 'Sign off',
      hint: 'Wave, say thanks, and sign off',
      maxSeconds: 4,
      effects: ClipEffects(
        filter: VideoFilter.warm,
        textOverlays: [
          TextOverlay(
            text: 'Thanks for watching! 👋',
            style: TextStylePreset.handwritten,
            timing: OverlayTiming.lastTwoSeconds,
          ),
        ],
      ),
    ),
  ],
);

final _dance = Template(
  id: 'dance',
  name: 'Dance Challenge',
  emoji: '💃',
  description: '3-shot dance: pose, bust a move, finish strong',
  accentColor: const Color(0xFFFF2D92),
  slots: [
    TemplateSlot(
      label: 'Strike a pose',
      hint: 'Freeze in your starting pose — make it count',
      maxSeconds: 3,
      effects: ClipEffects(
        filter: VideoFilter.dramatic,
        textOverlays: [
          TextOverlay(
            text: '3... 2... 1...',
            style: TextStylePreset.neon,
            timing: OverlayTiming.firstTwoSeconds,
          ),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.zoom, durationMs: 400),
    ),
    TemplateSlot(
      label: 'Bust a move',
      hint: 'Show your best moves — go big!',
      maxSeconds: 8,
      effects: ClipEffects(
        filter: VideoFilter.cool,
        textOverlays: [
          TextOverlay(
            text: 'Let\'s go!',
            style: TextStylePreset.neon,
            timing: OverlayTiming.firstTwoSeconds,
          ),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.slideLeft, durationMs: 400),
    ),
    TemplateSlot(
      label: 'Finish strong',
      hint: 'Hit a final pose and hold it',
      maxSeconds: 3,
      effects: ClipEffects(
        filter: VideoFilter.dramatic,
        textOverlays: [
          TextOverlay(
            text: '🔥🔥🔥',
            style: TextStylePreset.comic,
            timing: OverlayTiming.lastTwoSeconds,
          ),
        ],
      ),
    ),
  ],
);

final _spaceAdventure = Template(
  id: 'space_adventure',
  name: 'Space Adventure',
  emoji: '🚀',
  description: '3-clip epic space mission with dramatic effects',
  accentColor: const Color(0xFF5856D6),
  slots: [
    TemplateSlot(
      label: 'Takeoff',
      hint: 'Launch countdown or dramatic beginning',
      maxSeconds: 4,
      effects: ClipEffects(
        filter: VideoFilter.dramatic,
        textOverlays: [
          TextOverlay(
            text: '3... 2... 1... GO!',
            style: TextStylePreset.title,
            timing: OverlayTiming.firstTwoSeconds,
          ),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.fade, durationMs: 500),
    ),
    TemplateSlot(
      label: 'Exploration',
      hint: 'The main action — what\'s happening out there?',
      maxSeconds: 6,
      effects: ClipEffects(
        filter: VideoFilter.cool,
        textOverlays: [
          TextOverlay(
            text: 'Mission: GO!',
            style: TextStylePreset.neon,
            timing: OverlayTiming.firstTwoSeconds,
          ),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.zoom, durationMs: 500),
    ),
    TemplateSlot(
      label: 'Landing',
      hint: 'Epic finale or triumphant ending',
      maxSeconds: 4,
      effects: ClipEffects(
        filter: VideoFilter.dramatic,
        textOverlays: [
          TextOverlay(
            text: 'The End 🌟',
            style: TextStylePreset.title,
            timing: OverlayTiming.lastTwoSeconds,
          ),
        ],
      ),
    ),
  ],
);

final _petShow = Template(
  id: 'pet_show',
  name: 'Pet Show',
  emoji: '🐶',
  description: 'Show off your pet in 3 playful clips',
  accentColor: const Color(0xFFFF9500),
  slots: [
    TemplateSlot(
      label: 'Meet the Star',
      hint: 'A cute intro of your pet',
      maxSeconds: 5,
      effects: ClipEffects(
        filter: VideoFilter.sunny,
        textOverlays: [
          TextOverlay(
            text: 'Meet my buddy!',
            style: TextStylePreset.bubble,
            timing: OverlayTiming.firstTwoSeconds,
          ),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.slideLeft, durationMs: 400),
    ),
    TemplateSlot(
      label: 'Showtime',
      hint: 'The main trick or funny moment',
      maxSeconds: 7,
      effects: ClipEffects(
        filter: VideoFilter.warm,
        textOverlays: [
          TextOverlay(
            text: 'Wait for it...',
            style: TextStylePreset.comic,
            timing: OverlayTiming.firstTwoSeconds,
          ),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.slideLeft, durationMs: 400),
    ),
    TemplateSlot(
      label: 'Big Finish',
      hint: 'The awww moment or cute ending',
      maxSeconds: 5,
      effects: ClipEffects(
        filter: VideoFilter.sunny,
        textOverlays: [
          TextOverlay(
            text: 'Best pet ever! 💕',
            style: TextStylePreset.handwritten,
            timing: OverlayTiming.lastTwoSeconds,
          ),
        ],
      ),
    ),
  ],
);

final _unboxing = Template(
  id: 'unboxing',
  name: 'Unboxing',
  emoji: '📦',
  description: 'Build anticipation with a 3-clip unboxing video',
  accentColor: const Color(0xFF34C759),
  slots: [
    TemplateSlot(
      label: 'The Reveal',
      hint: 'Show the mysterious box',
      maxSeconds: 4,
      effects: ClipEffects(
        textOverlays: [
          TextOverlay(
            text: 'What could it be?',
            style: TextStylePreset.title,
            timing: OverlayTiming.firstTwoSeconds,
          ),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.circleClose, durationMs: 500),
    ),
    TemplateSlot(
      label: 'Opening',
      hint: 'Opening the box (the suspense!)',
      maxSeconds: 6,
      effects: ClipEffects(
        textOverlays: [
          TextOverlay(
            text: 'Here we go...',
            style: TextStylePreset.neon,
            timing: OverlayTiming.firstTwoSeconds,
          ),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.fade, durationMs: 500),
    ),
    TemplateSlot(
      label: 'The Item',
      hint: 'Show what was inside!',
      maxSeconds: 5,
      effects: ClipEffects(
        filter: VideoFilter.sunny,
        textOverlays: [
          TextOverlay(
            text: 'WOW! 🤩',
            style: TextStylePreset.comic,
            timing: OverlayTiming.firstTwoSeconds,
          ),
        ],
      ),
    ),
  ],
);

final _roomTour = Template(
  id: 'room_tour',
  name: 'Room Tour',
  emoji: '🏠',
  description: 'Show off your space in 5 quick shots',
  accentColor: const Color(0xFF30B0C7),
  slots: [
    TemplateSlot(
      label: 'Welcome',
      hint: 'Open the door and say hi from the doorway',
      maxSeconds: 4,
      effects: ClipEffects(
        textOverlays: [
          TextOverlay(
            text: 'Room Tour!',
            style: TextStylePreset.title,
            timing: OverlayTiming.firstTwoSeconds,
          ),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.slideLeft, durationMs: 400),
    ),
    TemplateSlot(
      label: 'The overview',
      hint: 'Slow pan across the whole room',
      maxSeconds: 6,
      effects: ClipEffects(filter: VideoFilter.sunny),
      outgoingTransition: const Transition(type: TransitionType.slideLeft, durationMs: 400),
    ),
    TemplateSlot(
      label: 'Favorite spot',
      hint: 'Zoom in on your favorite corner or thing',
      maxSeconds: 5,
      effects: ClipEffects(
        textOverlays: [
          TextOverlay(text: 'My fav spot', style: TextStylePreset.bubble, timing: OverlayTiming.firstTwoSeconds),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.fade, durationMs: 400),
    ),
    TemplateSlot(
      label: 'Secret detail',
      hint: 'Something most people would miss',
      maxSeconds: 5,
      effects: ClipEffects(
        filter: VideoFilter.dramatic,
        textOverlays: [
          TextOverlay(text: 'Bet you didn\'t notice...', style: TextStylePreset.neon, timing: OverlayTiming.firstTwoSeconds),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.fade, durationMs: 400),
    ),
    TemplateSlot(
      label: 'Sign off',
      hint: 'Wave goodbye from your room',
      maxSeconds: 4,
      effects: ClipEffects(
        filter: VideoFilter.warm,
        textOverlays: [
          TextOverlay(text: 'See ya! 👋', style: TextStylePreset.handwritten, timing: OverlayTiming.lastTwoSeconds),
        ],
      ),
    ),
  ],
);

final _howTo = Template(
  id: 'how_to',
  name: 'How To',
  emoji: '🛠️',
  description: 'Teach something in 4 easy steps',
  accentColor: const Color(0xFF34C759),
  slots: [
    TemplateSlot(
      label: 'What we\'re making',
      hint: 'Show the finished thing or say what you\'ll teach',
      maxSeconds: 5,
      effects: ClipEffects(
        textOverlays: [
          TextOverlay(text: 'How To:', style: TextStylePreset.title, timing: OverlayTiming.firstTwoSeconds),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.fade, durationMs: 400),
    ),
    TemplateSlot(
      label: 'Step 1',
      hint: 'First thing to do — show and explain',
      maxSeconds: 8,
      effects: ClipEffects(
        textOverlays: [
          TextOverlay(text: 'Step 1', style: TextStylePreset.bubble, timing: OverlayTiming.firstTwoSeconds),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.slideLeft, durationMs: 400),
    ),
    TemplateSlot(
      label: 'Step 2',
      hint: 'Next step — keep it clear',
      maxSeconds: 8,
      effects: ClipEffects(
        textOverlays: [
          TextOverlay(text: 'Step 2', style: TextStylePreset.bubble, timing: OverlayTiming.firstTwoSeconds),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.slideLeft, durationMs: 400),
    ),
    TemplateSlot(
      label: 'The result',
      hint: 'Show the finished product — ta-da!',
      maxSeconds: 5,
      effects: ClipEffects(
        filter: VideoFilter.sunny,
        textOverlays: [
          TextOverlay(text: 'Ta-da!', style: TextStylePreset.comic, timing: OverlayTiming.firstTwoSeconds),
        ],
      ),
    ),
  ],
);

final _joke = Template(
  id: 'joke',
  name: 'Tell a Joke',
  emoji: '😂',
  description: '3 shots: setup, punchline, reaction',
  accentColor: const Color(0xFFFF9500),
  slots: [
    TemplateSlot(
      label: 'The setup',
      hint: 'Look at the camera and start your joke',
      maxSeconds: 6,
      effects: ClipEffects(
        textOverlays: [
          TextOverlay(text: 'Joke Time!', style: TextStylePreset.comic, timing: OverlayTiming.firstTwoSeconds),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.zoom, durationMs: 400),
    ),
    TemplateSlot(
      label: 'The punchline',
      hint: 'Deliver the punchline — timing is everything',
      maxSeconds: 5,
      effects: ClipEffects(
        textOverlays: [
          TextOverlay(text: 'Wait for it...', style: TextStylePreset.neon, timing: OverlayTiming.firstTwoSeconds),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.fade, durationMs: 300),
    ),
    TemplateSlot(
      label: 'The reaction',
      hint: 'Laugh, make a face, drop the mic',
      maxSeconds: 4,
      effects: ClipEffects(
        filter: VideoFilter.sunny,
        textOverlays: [
          TextOverlay(text: '🤣🤣🤣', style: TextStylePreset.title, timing: OverlayTiming.wholeClip),
        ],
      ),
    ),
  ],
);

final _threeFavorites = Template(
  id: 'three_favorites',
  name: '3 Favorites',
  emoji: '⭐',
  description: 'Show your top 3 of anything',
  accentColor: const Color(0xFFAF52DE),
  slots: [
    TemplateSlot(
      label: 'The topic',
      hint: 'Say what your top 3 is about — foods, games, songs, whatever',
      maxSeconds: 4,
      effects: ClipEffects(
        textOverlays: [
          TextOverlay(text: 'My Top 3', style: TextStylePreset.title, timing: OverlayTiming.firstTwoSeconds),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.slideLeft, durationMs: 400),
    ),
    TemplateSlot(
      label: '#3',
      hint: 'Third favorite — show it or talk about it',
      maxSeconds: 5,
      effects: ClipEffects(
        textOverlays: [
          TextOverlay(text: '#3', style: TextStylePreset.neon, timing: OverlayTiming.firstTwoSeconds),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.slideLeft, durationMs: 400),
    ),
    TemplateSlot(
      label: '#2',
      hint: 'Second favorite — getting closer',
      maxSeconds: 5,
      effects: ClipEffects(
        textOverlays: [
          TextOverlay(text: '#2', style: TextStylePreset.neon, timing: OverlayTiming.firstTwoSeconds),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.zoom, durationMs: 500),
    ),
    TemplateSlot(
      label: '#1',
      hint: 'Number one! Make it big!',
      maxSeconds: 6,
      effects: ClipEffects(
        filter: VideoFilter.dramatic,
        textOverlays: [
          TextOverlay(text: '#1 !!!', style: TextStylePreset.comic, timing: OverlayTiming.firstTwoSeconds),
        ],
      ),
    ),
  ],
);

final _dayInLife = Template(
  id: 'day_in_life',
  name: 'My Day',
  emoji: '🌅',
  description: '4 clips that show what you did today',
  accentColor: const Color(0xFFFF2D92),
  slots: [
    TemplateSlot(
      label: 'Morning',
      hint: 'How you started the day',
      maxSeconds: 6,
      effects: ClipEffects(
        filter: VideoFilter.sunny,
        textOverlays: [
          TextOverlay(
            text: 'Morning! ☀️',
            style: TextStylePreset.handwritten,
            timing: OverlayTiming.firstTwoSeconds,
          ),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.fade, durationMs: 400),
    ),
    TemplateSlot(
      label: 'Afternoon',
      hint: 'Something fun you did',
      maxSeconds: 6,
      effects: ClipEffects(
        textOverlays: [
          TextOverlay(
            text: 'Afternoon 🎉',
            style: TextStylePreset.handwritten,
            timing: OverlayTiming.firstTwoSeconds,
          ),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.fade, durationMs: 400),
    ),
    TemplateSlot(
      label: 'Evening',
      hint: 'Winding down',
      maxSeconds: 6,
      effects: ClipEffects(
        filter: VideoFilter.warm,
        textOverlays: [
          TextOverlay(
            text: 'Evening 🌆',
            style: TextStylePreset.handwritten,
            timing: OverlayTiming.firstTwoSeconds,
          ),
        ],
      ),
      outgoingTransition: const Transition(type: TransitionType.fade, durationMs: 400),
    ),
    TemplateSlot(
      label: 'Night',
      hint: 'The end of the day',
      maxSeconds: 5,
      effects: ClipEffects(
        filter: VideoFilter.cool,
        textOverlays: [
          TextOverlay(
            text: 'Goodnight 🌙',
            style: TextStylePreset.handwritten,
            timing: OverlayTiming.lastTwoSeconds,
          ),
        ],
      ),
    ),
  ],
);
