import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'choreography.dart';

/// A single slot in a template — a placeholder for a clip the kid will pick.
class TemplateSlot {
  final String label; // "Opening", "Main Action"
  final String hint; // "Something dramatic to grab attention"
  final ClipEffects effects;
  final Transition outgoingTransition;

  const TemplateSlot({
    required this.label,
    required this.hint,
    this.effects = const ClipEffects(),
    this.outgoingTransition = const Transition(),
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
  _spaceAdventure,
  _petShow,
  _unboxing,
  _dayInLife,
];

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
