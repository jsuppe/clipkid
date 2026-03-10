import 'package:flutter/foundation.dart';

/// The steps in the guided editing journey
enum GuideStep {
  welcome,      // "Want help making something awesome?"
  addClips,     // "First, grab some videos!"
  reviewClips,  // "Let's see what you've got!"
  pickVibe,     // "What's the vibe?"
  starMoment,   // "Which clip is the star?"
  trimClips,    // "Let's cut to the good stuff!"
  orderClips,   // "What order tells your story?"
  polish,       // "Want me to smooth the shaky parts?"
  export,       // "Ready to share?"
  completed,    // Done!
}

/// State of the duck guide
enum GuideState {
  notStarted,   // Fresh project, hasn't offered help yet
  offered,      // "Want help?" prompt shown
  active,       // Walking through steps
  dismissed,    // Kid said "I got this"
  completed,    // Finished the journey
}

/// A quick reply option for the kid to tap
class QuickReply {
  final String label;
  final String value;
  final String? emoji;

  const QuickReply({
    required this.label,
    required this.value,
    this.emoji,
  });
}

/// A message from the duck
class DuckMessage {
  final String text;
  final List<QuickReply>? replies;
  final String? conceptId; // For tracking what concepts we've taught

  const DuckMessage({
    required this.text,
    this.replies,
    this.conceptId,
  });
}

/// Manages the duck guide state and conversation flow
class DuckGuide extends ChangeNotifier {
  GuideState _state = GuideState.notStarted;
  GuideStep _currentStep = GuideStep.welcome;
  String? _selectedVibe;
  int? _starClipIndex;

  GuideState get state => _state;
  GuideStep get currentStep => _currentStep;
  String? get selectedVibe => _selectedVibe;
  int? get starClipIndex => _starClipIndex;
  
  bool get isActive => _state == GuideState.active;
  bool get isDismissed => _state == GuideState.dismissed;
  bool get isOffered => _state == GuideState.offered;

  /// Get the current message to display
  DuckMessage get currentMessage => _getMessageForStep(_currentStep);

  /// Offer help to the user (called when project created)
  void offer() {
    _state = GuideState.offered;
    _currentStep = GuideStep.welcome;
    notifyListeners();
  }

  /// Start the guided flow (user accepted help)
  void start() {
    _state = GuideState.active;
    _currentStep = GuideStep.addClips;
    notifyListeners();
  }

  /// User wants to do it themselves
  void dismiss() {
    _state = GuideState.dismissed;
    notifyListeners();
  }

  /// User wants help again
  void resume() {
    _state = GuideState.active;
    notifyListeners();
  }

  /// Move to the next step
  void nextStep() {
    final nextIndex = GuideStep.values.indexOf(_currentStep) + 1;
    if (nextIndex < GuideStep.values.length) {
      _currentStep = GuideStep.values[nextIndex];
      if (_currentStep == GuideStep.completed) {
        _state = GuideState.completed;
      }
      notifyListeners();
    }
  }

  /// Go to a specific step
  void goToStep(GuideStep step) {
    _currentStep = step;
    notifyListeners();
  }

  /// Handle a quick reply selection
  void handleReply(String value) {
    switch (_currentStep) {
      case GuideStep.welcome:
        if (value == 'yes') {
          start();
        } else {
          dismiss();
        }
        break;
      case GuideStep.pickVibe:
        _selectedVibe = value;
        nextStep();
        break;
      case GuideStep.polish:
        // Value is 'yes' or 'no' - parent handles the action
        nextStep();
        break;
      default:
        nextStep();
    }
  }

  /// Set the star clip (user's favorite)
  void setStarClip(int index) {
    _starClipIndex = index;
    notifyListeners();
  }

  /// Called when clips are added - advances if we're waiting for clips
  void onClipsAdded(int count) {
    if (_state == GuideState.active && _currentStep == GuideStep.addClips && count > 0) {
      nextStep();
    }
  }

  /// Called when a clip is trimmed
  void onClipTrimmed() {
    if (_state == GuideState.active && _currentStep == GuideStep.trimClips) {
      nextStep();
    }
  }

  /// Called when clips are reordered
  void onClipsReordered() {
    if (_state == GuideState.active && _currentStep == GuideStep.orderClips) {
      nextStep();
    }
  }

  /// Reset for a new project
  void reset() {
    _state = GuideState.notStarted;
    _currentStep = GuideStep.welcome;
    _selectedVibe = null;
    _starClipIndex = null;
    notifyListeners();
  }

  DuckMessage _getMessageForStep(GuideStep step) {
    switch (step) {
      case GuideStep.welcome:
        return const DuckMessage(
          text: "Want me to help you make something awesome? 🎬",
          replies: [
            QuickReply(label: "Yeah, let's go!", value: 'yes', emoji: '🚀'),
            QuickReply(label: "I got this", value: 'no', emoji: '👋'),
          ],
        );
      
      case GuideStep.addClips:
        return const DuckMessage(
          text: "First, grab some videos! Tap the + button to pick clips from your camera roll.",
        );
      
      case GuideStep.reviewClips:
        return const DuckMessage(
          text: "Nice! Let's see what you've got. Tap a clip to preview it.",
          replies: [
            QuickReply(label: "I've watched them", value: 'done', emoji: '👀'),
          ],
        );
      
      case GuideStep.pickVibe:
        return const DuckMessage(
          text: "What's the vibe you're going for?",
          conceptId: 'tone',
          replies: [
            QuickReply(label: "Funny", value: 'funny', emoji: '😂'),
            QuickReply(label: "Cool", value: 'cool', emoji: '😎'),
            QuickReply(label: "Exciting", value: 'exciting', emoji: '🔥'),
            QuickReply(label: "Chill", value: 'chill', emoji: '✨'),
          ],
        );
      
      case GuideStep.starMoment:
        return const DuckMessage(
          text: "Every good video has a STAR moment — the part people remember. Tap the clip that has yours!",
          conceptId: 'hook',
          replies: [
            QuickReply(label: "They're all good!", value: 'skip', emoji: '✨'),
          ],
        );
      
      case GuideStep.trimClips:
        return const DuckMessage(
          text: "Now let's cut to the good stuff! Tap a clip and use 'Trim' to keep just the best part.",
          conceptId: 'pacing',
        );
      
      case GuideStep.orderClips:
        return const DuckMessage(
          text: "What order tells your story best? Hold and drag clips to rearrange them.",
          conceptId: 'sequencing',
        );
      
      case GuideStep.polish:
        return const DuckMessage(
          text: "Almost done! Want me to smooth out any shaky footage?",
          conceptId: 'stabilization',
          replies: [
            QuickReply(label: "Yes please!", value: 'yes', emoji: '✨'),
            QuickReply(label: "Keep it raw", value: 'no', emoji: '🎥'),
          ],
        );
      
      case GuideStep.export:
        return const DuckMessage(
          text: "Your video is ready! Tap export to save it and share with the world. 🌟",
          replies: [
            QuickReply(label: "Let's do it!", value: 'export', emoji: '🚀'),
          ],
        );
      
      case GuideStep.completed:
        return const DuckMessage(
          text: "Amazing work! You just made a real video. Go share it! 🎉",
        );
    }
  }
}
