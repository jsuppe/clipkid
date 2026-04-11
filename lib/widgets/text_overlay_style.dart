import 'package:flutter/material.dart';
import '../models/choreography.dart';

/// Renders a text overlay in its chosen style. One widget, one style,
/// everything baked in — no font/color/stroke pickers exposed to kids.
class StyledOverlayText extends StatelessWidget {
  final String text;
  final TextStylePreset style;
  final double baseFontSize;

  const StyledOverlayText({
    super.key,
    required this.text,
    required this.style,
    this.baseFontSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case TextStylePreset.title:
        return _TitleStyle(text: text, size: baseFontSize);
      case TextStylePreset.bubble:
        return _BubbleStyle(text: text, size: baseFontSize);
      case TextStylePreset.comic:
        return _ComicStyle(text: text, size: baseFontSize);
      case TextStylePreset.rainbow:
        return _RainbowStyle(text: text, size: baseFontSize);
      case TextStylePreset.spooky:
        return _SpookyStyle(text: text, size: baseFontSize);
      case TextStylePreset.neon:
        return _NeonStyle(text: text, size: baseFontSize);
      case TextStylePreset.caption:
        return _CaptionStyle(text: text, size: baseFontSize);
      case TextStylePreset.handwritten:
        return _HandwrittenStyle(text: text, size: baseFontSize);
    }
  }
}

// ---------- Style implementations ----------
// Each style is a self-contained widget. Every style has:
// - A baked-in TextStyle (font weight, color, italic, etc.)
// - An optional background / stroke / glow effect
// - No parameters exposed except text and size

class _TitleStyle extends StatelessWidget {
  final String text;
  final double size;
  const _TitleStyle({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Black outline via shadow duplication
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size * 1.4,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..color = Colors.black,
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size * 1.4,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFFDE00), // bright yellow
            shadows: const [
              Shadow(blurRadius: 6, color: Colors.black54, offset: Offset(2, 2)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BubbleStyle extends StatelessWidget {
  final String text;
  final double size;
  const _BubbleStyle({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.6, vertical: size * 0.35),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 1.2),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(2, 4)),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _ComicStyle extends StatelessWidget {
  final String text;
  final double size;
  const _ComicStyle({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.08,
      child: Stack(
        children: [
          // Drop shadow offset
          Transform.translate(
            offset: Offset(size * 0.1, size * 0.1),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: size * 1.5,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: Colors.black,
              ),
            ),
          ),
          // Main text
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size * 1.5,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 5
                ..color = Colors.black,
            ),
          ),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size * 1.5,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: const Color(0xFFFF3B30),
            ),
          ),
        ],
      ),
    );
  }
}

class _RainbowStyle extends StatelessWidget {
  final String text;
  final double size;
  const _RainbowStyle({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFFFF3B30),
          Color(0xFFFF9500),
          Color(0xFFFFCC00),
          Color(0xFF34C759),
          Color(0xFF007AFF),
          Color(0xFF5856D6),
          Color(0xFFAF52DE),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      child: Stack(
        children: [
          // Outline
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size * 1.4,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4
                ..color = Colors.white,
            ),
          ),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size * 1.4,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpookyStyle extends StatelessWidget {
  final String text;
  final double size;
  const _SpookyStyle({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: size * 1.3,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        color: const Color(0xFF7CFF00), // zombie green
        shadows: const [
          Shadow(blurRadius: 0, color: Color(0xFF6A0DAD), offset: Offset(3, 3)),
          Shadow(blurRadius: 0, color: Color(0xFF6A0DAD), offset: Offset(-1, -1)),
          Shadow(blurRadius: 12, color: Color(0xFF7CFF00), offset: Offset(0, 0)),
        ],
      ),
    );
  }
}

class _NeonStyle extends StatelessWidget {
  final String text;
  final double size;
  const _NeonStyle({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.4, vertical: size * 0.2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: size * 1.2,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFFF2D92), // hot pink
          shadows: const [
            Shadow(blurRadius: 10, color: Color(0xFFFF2D92)),
            Shadow(blurRadius: 20, color: Color(0xFFFF2D92)),
            Shadow(blurRadius: 30, color: Color(0xFFFF2D92)),
          ],
        ),
      ),
    );
  }
}

class _CaptionStyle extends StatelessWidget {
  final String text;
  final double size;
  const _CaptionStyle({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.5, vertical: size * 0.25),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: size * 0.9,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.2,
        ),
      ),
    );
  }
}

class _HandwrittenStyle extends StatelessWidget {
  final String text;
  final double size;
  const _HandwrittenStyle({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: size * 1.3,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
        color: const Color(0xFF2B4F81), // ink blue
        shadows: const [
          Shadow(blurRadius: 1, color: Colors.white, offset: Offset(1, 1)),
        ],
      ),
    );
  }
}
