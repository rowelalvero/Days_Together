import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The "OR" divider between [AuthScreen]'s form and its Google sign-in
/// button. Extracted from the screen's `build()` (Migration audit item 6).
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: theme.textColor.withValues(alpha: 0.1),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: AppTypography.caption(
              color: theme.textColor.withValues(alpha: 0.3),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ).copyWith(letterSpacing: 1.1),
          ),
        ),
        Expanded(
          child: Divider(
            color: theme.textColor.withValues(alpha: 0.1),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}
