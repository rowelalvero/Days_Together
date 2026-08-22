import 'package:flutter/material.dart';

/// Decorative watermark overlay for the relationship license card faces.
/// Extracted out of relationship_license_screen.dart (Migration Phase 8) --
/// renamed from `_WatermarkPainter` since it now needs to be public to be
/// shared across the license/ file split.
class WatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (double i = -size.height; i < size.width + size.height; i += 20) {
      canvas.drawLine(
        Offset(i, 0),

        Offset(i + size.height, size.height),

        paint,
      );
    }

    final cornerPaint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawArc(
      const Rect.fromLTWH(8, 8, 40, 40),
      3.14,
      1.57,
      false,
      cornerPaint,
    );

    canvas.drawArc(
      Rect.fromLTWH(size.width - 48, 8, 40, 40),
      -1.57,
      1.57,

      false,
      cornerPaint,
    );

    canvas.drawArc(
      Rect.fromLTWH(8, size.height - 48, 40, 40),
      1.57,
      1.57,

      false,
      cornerPaint,
    );

    canvas.drawArc(
      Rect.fromLTWH(size.width - 48, size.height - 48, 40, 40),
      0,

      1.57,
      false,
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
