import 'package:flutter/material.dart';
import 'package:days_together/models/noteit_model.dart' show ColorfulStroke;

/// Renders a set of strokes (drawing/doodle) scaled and centered to fit
/// [size], preserving aspect ratio. Used for preview thumbnails of scrapbook
/// drawings.
///
/// Previously defined in lib/models/noteit_model.dart -- moved here as part
/// of architecture Phase 0 (a CustomPainter is a Flutter rendering type and
/// does not belong in the model layer; see
/// docs/architecture/migration-roadmap.md and architecture-rules.md Rule 13).
class ScaleDrawingPainter extends CustomPainter {
  final List<List<Offset>>? strokes;
  final List<ColorfulStroke>? colorfulStrokes;
  final Color color;
  final double strokeWidth;

  ScaleDrawingPainter({
    this.strokes,
    this.colorfulStrokes,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final List<ColorfulStroke> finalStrokes = colorfulStrokes ??
        (strokes?.map((s) => ColorfulStroke(points: s, color: color, strokeWidth: strokeWidth)).toList() ?? []);

    if (finalStrokes.isEmpty) return;

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    bool hasPoints = false;

    for (final stroke in finalStrokes) {
      for (final p in stroke.points) {
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

    const padding = 8.0; // Reduced padding for small preview widgets
    final targetW = size.width - 2 * padding;
    final targetH = size.height - 2 * padding;

    final scaleX = targetW / w;
    final scaleY = targetH / h;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final targetCenterX = size.width / 2;
    final targetCenterY = size.height / 2;
    final sourceCenterX = minX + w / 2;
    final sourceCenterY = minY + h / 2;

    for (final stroke in finalStrokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.strokeWidth * scale
        ..style = PaintingStyle.stroke;

      final firstPoint = stroke.points.first;
      final startX = targetCenterX + (firstPoint.dx - sourceCenterX) * scale;
      final startY = targetCenterY + (firstPoint.dy - sourceCenterY) * scale;

      final path = Path()..moveTo(startX, startY);
      for (int i = 1; i < stroke.points.length; i++) {
        final p = stroke.points[i];
        final px = targetCenterX + (p.dx - sourceCenterX) * scale;
        final py = targetCenterY + (p.dy - sourceCenterY) * scale;
        path.lineTo(px, py);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ScaleDrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.colorfulStrokes != colorfulStrokes ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
