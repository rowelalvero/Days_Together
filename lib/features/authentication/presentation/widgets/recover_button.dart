import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The "Recover Workspace" submit button on [RecoverRelationshipScreen].
/// Extracted from its inline `build()` (Migration audit item 6).
class RecoverButton extends StatelessWidget {
  const RecoverButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.theme,
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.accentColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: theme.accentColor.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Recover Workspace',
                style: AppTypography.button(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
