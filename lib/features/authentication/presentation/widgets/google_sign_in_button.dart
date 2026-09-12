import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The "Continue with Google" button on [AuthScreen]. Extracted from the
/// screen's `build()` (Migration audit item 6).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.theme,
  });

  final bool isLoading;
  final VoidCallback onPressed;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: theme.textColor.withValues(alpha: 0.15),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          foregroundColor: theme.textColor,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://www.gstatic.com/images/branding/product/2x/googleg_64dp.png',
              width: 24,
              height: 24,
              errorBuilder: (context, error, stackTrace) => Text(
                'G',
                style: AppTypography.button(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: theme.textColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: AppTypography.button(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
