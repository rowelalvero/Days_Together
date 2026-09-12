import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The "Complete Setup" submit button on [AvatarCreationScreen]. Extracted
/// from its inline `build()` (Migration audit item 6).
class CompleteSetupButton extends StatelessWidget {
  const CompleteSetupButton({
    super.key,
    required this.isSaving,
    required this.onPressed,
    required this.theme,
  });

  final bool isSaving;
  final VoidCallback? onPressed;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isSaving ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.accentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Complete Setup',
                style: AppTypography.button(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
