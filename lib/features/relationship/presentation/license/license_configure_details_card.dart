import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/relationship/presentation/license/edit/edit_license_sheet.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The tappable "Configure License Details" card on the main
/// [RelationshipLicenseScreen] view, opening [EditLicenseSheet]. Extracted
/// from the screen's `build()` (Migration audit item 6).
class LicenseConfigureDetailsCard extends StatelessWidget {
  const LicenseConfigureDetailsCard({super.key, required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => EditLicenseSheet(theme: theme),
        );
      },
      child: GlassContainer(
        borderRadius: 16,
        opacity: 0.06,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note_rounded, color: theme.accentColor, size: 20),
            const SizedBox(width: 10),
            Text(
              'Configure License Details',
              style: AppTypography.body(
                fontSize: 14,
                color: theme.textColor.withValues(alpha: 0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
