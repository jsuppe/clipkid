import 'package:flutter/material.dart';

/// First-launch onboarding with the duck guide. Shows 3 pages explaining
/// how ClipKid works, then navigates to the home screen.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPage(
      emoji: '🦆',
      title: 'Hi! I\'m Duck!',
      body: 'I\'ll be your video director. I\'ll tell you what to film, count you down, and help you make awesome videos.',
      color: Color(0xFFFF9500),
    ),
    _OnboardingPage(
      emoji: '🎬',
      title: 'Pick a Template',
      body: 'Choose from Show & Tell, Dance Challenge, Room Tour, and more. Each one breaks your video into easy short shots.',
      color: Color(0xFF667eea),
    ),
    _OnboardingPage(
      emoji: '🚀',
      title: 'Record & Share!',
      body: 'Follow my prompts, press record, and I\'ll stitch your clips together with transitions and effects. Then share with one tap!',
      color: Color(0xFFFF2D92),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _pages[_page].color.withValues(alpha: 0.8),
                  _pages[_page].color.withValues(alpha: 0.4),
                  Colors.black,
                ],
              ),
            ),
          ),
          // Pages
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (ctx, i) => _buildPage(_pages[i]),
                  ),
                ),
                // Dots + button
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Skip
                      TextButton(
                        onPressed: widget.onComplete,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 16,
                          ),
                        ),
                      ),
                      // Dots
                      Row(
                        children: List.generate(
                          _pages.length,
                          (i) => Container(
                            width: i == _page ? 24 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i == _page ? Colors.white : Colors.white38,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      // Next / Get Started
                      ElevatedButton(
                        onPressed: _page == _pages.length - 1
                            ? widget.onComplete
                            : () => _controller.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _pages[_page].color,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          _page == _pages.length - 1 ? 'Let\'s go!' : 'Next',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(page.emoji, style: const TextStyle(fontSize: 100)),
          const SizedBox(height: 32),
          Text(
            page.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 17,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String emoji;
  final String title;
  final String body;
  final Color color;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.body,
    required this.color,
  });
}
