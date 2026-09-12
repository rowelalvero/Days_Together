import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The "Generate New Code" text button on [CreateCoupleCodeScreen].
/// Extracted from its inline `build()` (Migration audit item 6).
class GenerateNewCodeButton extends StatelessWidget {
  const GenerateNewCodeButton({
    super.key,
    required this.theme,
    required this.onPressed,
  });

  final LoveStoryTheme theme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.refresh_rounded, size: 18, color: theme.accentColor),
        label: Text(
          'Generate New Code',
          style: AppTypography.body(
            fontSize: 14,
            color: theme.accentColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
