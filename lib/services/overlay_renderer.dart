import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/choreography.dart';

/// The result of rendering a text overlay to a PNG file.
class RenderedOverlayPng {
  final String path;
  final int width;
  final int height;
  const RenderedOverlayPng({
    required this.path,
    required this.width,
    required this.height,
  });
}

/// Renders TextOverlay models into PNG files that ffmpeg can composite
/// onto exported videos. The visual output matches the Flutter preview
/// as closely as possible so kids get WYSIWYG results.
class OverlayRenderer {
  /// Render a text overlay into a PNG file and return its path + pixel size.
  /// [videoWidth] is the width of the output video in pixels — overlay size
  /// scales relative to that, matching the preview's sizing logic.
  static Future<RenderedOverlayPng> renderTextOverlayToPng(
    TextOverlay overlay, {
    required int videoWidth,
  }) async {
    final recorder = ui.PictureRecorder();
    // Base font size matches preview: videoWidth / 12 clamped, then times scale
    final baseFontSize =
        (videoWidth / 12).clamp(14.0, 60.0) * overlay.scale;

    // Layout the text first to measure it so we can size the canvas exactly.
    final layout = _layoutText(overlay, baseFontSize);
    final totalSize = layout.totalSize;

    // Paint onto a recording canvas
    final canvas = Canvas(recorder);
    _paintStyled(canvas, overlay, layout);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      totalSize.width.ceil(),
      totalSize.height.ceil(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    // Write to temp file
    final dir = await getTemporaryDirectory();
    final overlayDir = Directory('${dir.path}/overlays');
    if (!await overlayDir.exists()) await overlayDir.create(recursive: true);
    final file = File(
      '${overlayDir.path}/overlay_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);
    return RenderedOverlayPng(
      path: file.path,
      width: totalSize.width.ceil(),
      height: totalSize.height.ceil(),
    );
  }

  /// Clean up a previously rendered PNG file.
  static Future<void> cleanup(List<RenderedOverlayPng> rendered) async {
    for (final r in rendered) {
      try {
        await File(r.path).delete();
      } catch (_) {}
    }
  }

  static _TextLayout _layoutText(TextOverlay overlay, double baseFontSize) {
    final style = _textStyleFor(overlay.style, baseFontSize);
    final painter = TextPainter(
      text: TextSpan(text: overlay.text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    // Compute padding / background box per style
    final (padX, padY) = _paddingFor(overlay.style, baseFontSize);
    final totalWidth = painter.width + padX * 2;
    final totalHeight = painter.height + padY * 2;

    return _TextLayout(
      painter: painter,
      padX: padX,
      padY: padY,
      totalSize: Size(totalWidth, totalHeight),
    );
  }

  /// Returns (horizontal padding, vertical padding) for a style's background box.
  static (double, double) _paddingFor(TextStylePreset style, double size) {
    switch (style) {
      case TextStylePreset.bubble:
        return (size * 0.6, size * 0.35);
      case TextStylePreset.caption:
        return (size * 0.5, size * 0.25);
      case TextStylePreset.neon:
        return (size * 0.4, size * 0.2);
      default:
        return (size * 0.4, size * 0.4); // room for shadows / strokes
    }
  }

  /// Build a TextStyle matching the preview style. Note: we can't use
  /// ShaderMask here (it's a widget), so gradient styles fall back to a
  /// bright color approximation.
  static TextStyle _textStyleFor(TextStylePreset style, double size) {
    switch (style) {
      case TextStylePreset.title:
        return TextStyle(
          fontSize: size * 1.4,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFFFDE00),
          shadows: const [
            Shadow(blurRadius: 6, color: Colors.black54, offset: Offset(2, 2)),
          ],
        );
      case TextStylePreset.bubble:
        return TextStyle(
          fontSize: size,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        );
      case TextStylePreset.comic:
        return TextStyle(
          fontSize: size * 1.5,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          color: const Color(0xFFFF3B30),
        );
      case TextStylePreset.rainbow:
        // TextPainter doesn't support gradient shaders directly; use white
        // with a colorful shadow to approximate. Perfect rainbow requires
        // painting multiple slices or using Paint shader (more complex).
        return TextStyle(
          fontSize: size * 1.4,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          shadows: const [
            Shadow(blurRadius: 0, color: Color(0xFFFF3B30), offset: Offset(-4, -4)),
            Shadow(blurRadius: 0, color: Color(0xFFFFCC00), offset: Offset(-2, -2)),
            Shadow(blurRadius: 0, color: Color(0xFF34C759), offset: Offset(2, 2)),
            Shadow(blurRadius: 0, color: Color(0xFF007AFF), offset: Offset(4, 4)),
          ],
        );
      case TextStylePreset.spooky:
        return TextStyle(
          fontSize: size * 1.3,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          color: const Color(0xFF7CFF00),
          shadows: const [
            Shadow(blurRadius: 0, color: Color(0xFF6A0DAD), offset: Offset(3, 3)),
            Shadow(blurRadius: 0, color: Color(0xFF6A0DAD), offset: Offset(-1, -1)),
            Shadow(blurRadius: 12, color: Color(0xFF7CFF00)),
          ],
        );
      case TextStylePreset.neon:
        return TextStyle(
          fontSize: size * 1.2,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFFF2D92),
          shadows: const [
            Shadow(blurRadius: 10, color: Color(0xFFFF2D92)),
            Shadow(blurRadius: 20, color: Color(0xFFFF2D92)),
            Shadow(blurRadius: 30, color: Color(0xFFFF2D92)),
          ],
        );
      case TextStylePreset.caption:
        return TextStyle(
          fontSize: size * 0.9,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.2,
        );
      case TextStylePreset.handwritten:
        return TextStyle(
          fontSize: size * 1.3,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: const Color(0xFF2B4F81),
          shadows: const [
            Shadow(blurRadius: 1, color: Colors.white, offset: Offset(1, 1)),
          ],
        );
    }
  }

  /// Paint the styled text onto a canvas, including background boxes where needed.
  static void _paintStyled(Canvas canvas, TextOverlay overlay, _TextLayout layout) {
    final size = layout.totalSize;

    // Draw background box first for styles that have one
    switch (overlay.style) {
      case TextStylePreset.bubble:
        _drawRoundedRect(canvas, size, Colors.white, borderColor: Colors.black, borderWidth: 3);
        break;
      case TextStylePreset.caption:
        _drawRoundedRect(canvas, size, Colors.black.withValues(alpha: 0.7));
        break;
      case TextStylePreset.neon:
        _drawRoundedRect(canvas, size, Colors.black.withValues(alpha: 0.5));
        break;
      default:
        break;
    }

    // Paint the text centered in the box
    final offset = Offset(layout.padX, layout.padY);
    layout.painter.paint(canvas, offset);
  }

  static void _drawRoundedRect(
    Canvas canvas,
    Size size,
    Color fill, {
    Color? borderColor,
    double borderWidth = 0,
  }) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.height * 0.3),
    );
    canvas.drawRRect(rect, Paint()..color = fill);
    if (borderColor != null) {
      canvas.drawRRect(
        rect,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth,
      );
    }
  }
}

class _TextLayout {
  final TextPainter painter;
  final double padX;
  final double padY;
  final Size totalSize;

  _TextLayout({
    required this.painter,
    required this.padX,
    required this.padY,
    required this.totalSize,
  });
}
