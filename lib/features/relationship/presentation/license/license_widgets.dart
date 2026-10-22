import 'package:flutter/material.dart';

/// A thin gold gradient divider line, shared across the license card's
/// front/back faces and the export studio sheet. Extracted out of
/// relationship_license_screen.dart (Migration Phase 8) -- was a top-level
/// private function (`_goldDivider`) used across three of the file's
/// classes with no shared home; made public since it now lives in its own
/// file.
Widget goldDivider() {
  return Container(
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFFD4AF37).withValues(alpha: 0.6),
          const Color(0xFFD4AF37),
          const Color(0xFFD4AF37).withValues(alpha: 0.6),
          Colors.transparent,
        ],
      ),
    ),
  );
}
