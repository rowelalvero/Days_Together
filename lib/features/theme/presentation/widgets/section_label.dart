import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// A small caps section heading in the custom theme designer ("COLOR
/// SLOTS", "PICK A COLOR", "MODE"). Extracted from
/// `_CustomThemeDesignerState._buildSectionLabel` (Migration audit item 6).
class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.text, required this.theme});

  final String text;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.caption(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: theme.textColor.withValues(alpha: 0.6),
      ).copyWith(letterSpacing: 1.5),
    );
  }
}
