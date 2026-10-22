import 'package:flutter/material.dart';

/// The faint background grid behind [LoveStoryScreen]'s tabs. Moved out of
/// the screen file into its own file as part of Migration audit item 6 --
/// it was already a proper class, just living inline in the screen.
class DashboardGridPainter extends CustomPainter {
  final Color gridColor;
  DashboardGridPainter({this.gridColor = const Color(0x05000000)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;
    const double step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
