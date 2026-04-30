import 'package:flutter/material.dart';
import '../models/choreography.dart';

/// Picker for speed ramp presets. Returns selected [SpeedRamp].
class SpeedRampScreen extends StatelessWidget {
  final SpeedRamp current;
  const SpeedRampScreen({super.key, required this.current});

  static const _curves = {
    SpeedRamp.none: [1.0, 1.0, 1.0, 1.0, 1.0],
    SpeedRamp.slowStart: [0.25, 0.5, 0.75, 1.0, 1.0],
    SpeedRamp.slowEnd: [1.0, 1.0, 0.75, 0.5, 0.25],
    SpeedRamp.speedBurst: [0.3, 0.6, 2.0, 0.6, 0.3],
    SpeedRamp.dramaticSlowmo: [1.0, 0.5, 0.2, 0.5, 1.0],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
        title: const Text('Speed Ramp ⚡'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Variable speed within the clip — applied during export',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          for (final ramp in SpeedRamp.values)
            _RampCard(
              ramp: ramp,
              selected: ramp == current,
              curve: _curves[ramp]!,
              onTap: () => Navigator.pop(context, ramp),
            ),
        ],
      ),
    );
  }
}

class _RampCard extends StatelessWidget {
  final SpeedRamp ramp;
  final bool selected;
  final List<double> curve;
  final VoidCallback onTap;

  const _RampCard({required this.ramp, required this.selected, required this.curve, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? Colors.orange.withValues(alpha: 0.2) : Colors.grey[850],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.orange : Colors.grey[700]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Mini speed curve visualization
            SizedBox(
              width: 60,
              height: 36,
              child: CustomPaint(painter: _CurvePainter(curve, selected ? Colors.orange : Colors.white38)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ramp.displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(ramp.description, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: Colors.orange, size: 28),
          ],
        ),
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _CurvePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    for (int i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y = size.height - (values[i] / maxVal) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) => false;
}
