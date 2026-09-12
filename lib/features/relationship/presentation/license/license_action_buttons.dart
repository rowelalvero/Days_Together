import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The "tap to flip" helper text and the Flip/Enlarge/Share buttons below
/// the license card canvas on the main [RelationshipLicenseScreen] view.
/// Extracted from the screen's `build()` (Migration audit item 6).
class LicenseActionButtons extends StatelessWidget {
  const LicenseActionButtons({
    super.key,
    required this.theme,
    required this.onFlip,
    required this.onEnlarge,
    required this.onShare,
  });

  final LoveStoryTheme theme;
  final VoidCallback onFlip;
  final VoidCallback onEnlarge;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '💡 Tap any license card directly to flip it!',
          style: AppTypography.body(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.textColor.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onFlip,
                icon: Icon(Icons.flip_rounded, color: theme.accentColor),
                label: Text(
                  'Flip Cards',
                  style: AppTypography.body(
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: theme.textColor.withValues(alpha: 0.15),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEnlarge,
                icon: Icon(Icons.zoom_in_rounded, color: theme.accentColor),
                label: Text(
                  'Enlarge ID',
                  style: AppTypography.body(
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: theme.textColor.withValues(alpha: 0.15),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_rounded),
            label: Text(
              'Share License',
              style: AppTypography.body(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: theme.accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 6,
              shadowColor: theme.accentColor.withValues(alpha: 0.3),
            ),
          ),
        ),
      ],
    );
  }
}
