import 'package:flutter/material.dart';

import 'package:days_together/features/relationship/presentation/license/painters/watermark_painter.dart';

/// The gold-bordered, watermarked card frame shared by both the license's
/// front and back faces. Extracted out of relationship_license_screen.dart
/// (Migration Phase 8) -- renamed from `_CardShell` since it now needs
/// to be public to be shared across the license/ file split.
class CardShell extends StatelessWidget {
  final Widget child;

  const CardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 85.60 / 53.98,

      child: Container(
        width: double.infinity,

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),

          gradient: const LinearGradient(
            begin: Alignment.topLeft,

            end: Alignment.bottomRight,

            colors: [Color(0xFF1A0A2E), Color(0xFF2D1B4E), Color(0xFF1A0A2E)],
          ),

          border: Border.all(color: const Color(0xFFD4AF37), width: 2),

          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.2),

              blurRadius: 20,

              spreadRadius: 2,
            ),
          ],
        ),

        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),

                child: CustomPaint(painter: WatermarkPainter()),
              ),
            ),

            Padding(padding: const EdgeInsets.all(12), child: child),
          ],
        ),
      ),
    );
  }
}
