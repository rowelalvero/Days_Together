import 'package:flutter/material.dart';

/// Free-drawn signature painters for the relationship license's
/// signature-capture dialog (`SignaturePainter`) and its scaled-down
/// preview on the license card face (`ScaleSignaturePainter`, which
/// rescales/recenters the same stroke data to fit a smaller canvas).
/// Extracted out of relationship_license_screen.dart (Migration Phase 8).
class SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  final Color color;

  final double strokeWidth;

  SignaturePainter({
    required this.strokes,

    required this.color,

    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;

      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);

      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class ScaleSignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  final Color color;

  final double strokeWidth;

  ScaleSignaturePainter({
    required this.strokes,

    required this.color,

    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;

    // 1. Find bounding box of all points

    double minX = double.infinity;

    double maxX = double.negativeInfinity;

    double minY = double.infinity;

    double maxY = double.negativeInfinity;

    bool hasPoints = false;

    for (final stroke in strokes) {
      for (final p in stroke) {
        if (p.dx < minX) minX = p.dx;

        if (p.dx > maxX) maxX = p.dx;

        if (p.dy < minY) minY = p.dy;

        if (p.dy > maxY) maxY = p.dy;

        hasPoints = true;
      }
    }

    if (!hasPoints) return;

    final w = maxX - minX;

    final h = maxY - minY;

    if (w == 0 || h == 0) return;

    // Apply padding of 4.0 pixels around the signature

    const padding = 4.0;

    final targetW = size.width - 2 * padding;

    final targetH = size.height - 2 * padding;

    final scaleX = targetW / w;

    final scaleY = targetH / h;

    final scale = scaleX < scaleY ? scaleX : scaleY;

    final targetCenterX = size.width / 2;

    final targetCenterY = size.height / 2;

    final sourceCenterX = minX + w / 2;

    final sourceCenterY = minY + h / 2;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;

      final firstPoint = stroke.first;

      final startX = targetCenterX + (firstPoint.dx - sourceCenterX) * scale;

      final startY = targetCenterY + (firstPoint.dy - sourceCenterY) * scale;

      final path = Path()..moveTo(startX, startY);

      for (int i = 1; i < stroke.length; i++) {
        final p = stroke[i];

        final px = targetCenterX + (p.dx - sourceCenterX) * scale;

        final py = targetCenterY + (p.dy - sourceCenterY) * scale;

        path.lineTo(px, py);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ScaleSignaturePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
