import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/relationship/presentation/profile/regenerate_recovery_code_dialog.dart';

/// The "Regenerate Recovery Code" row on [RelationshipProfileScreen].
/// Extracted from its `_buildRegenerateRecoveryCodeButton` (Migration audit
/// item 6).
class RegenerateRecoveryCodeButton extends StatelessWidget {
  const RegenerateRecoveryCodeButton({super.key, required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.15)),
      ),
      child: TextButton.icon(
        onPressed: () => RegenerateRecoveryCodeDialog.show(context, theme),
        icon: Icon(Icons.security_rounded, color: theme.textColor, size: 20),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        label: Text(
          'Regenerate Recovery Code',
          style: AppTypography.body(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
