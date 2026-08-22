import 'package:flutter/material.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';

class GridBackgroundDrawable extends BackgroundDrawable {
  final Color gridColor;
  final Color backgroundColor;
  final double step;

  const GridBackgroundDrawable({
    this.gridColor = const Color(0xFFE0E0E0),
    this.backgroundColor = Colors.white,
    this.step = 25,
  });

  @override
  void draw(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = backgroundColor);

    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
}

class DotsBackgroundDrawable extends BackgroundDrawable {
  final Color dotColor;
  final Color backgroundColor;
  final double step;

  const DotsBackgroundDrawable({
    this.dotColor = const Color(0xFFC0C0C0),
    this.backgroundColor = Colors.white,
    this.step = 25,
  });

  @override
  void draw(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = backgroundColor);

    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }
}

class NotebookBackgroundDrawable extends BackgroundDrawable {
  final Color lineColor;
  final Color marginColor;
  final Color backgroundColor;
  final double step;

  const NotebookBackgroundDrawable({
    this.lineColor = const Color(0xFFD6E4F0),
    this.marginColor = const Color(0xFFFFB3B3),
    this.backgroundColor = const Color(0xFFF9F9FB),
    this.step = 30,
  });

  @override
  void draw(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = backgroundColor);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8;

    for (double y = step * 2; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final marginPaint = Paint()
      ..color = marginColor
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(60, 0), Offset(60, size.height), marginPaint);
  }
}

class GradientBackgroundDrawable extends BackgroundDrawable {
  final List<Color> colors;

  const GradientBackgroundDrawable({
    required this.colors,
  });

  @override
  void draw(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    final paint = Paint();
    if (colors.length == 1) {
      paint.color = colors.first;
    } else {
      paint.shader = LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }
}
