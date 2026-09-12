import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The back button, title, and subtitle at the top of [AuthScreen],
/// switching copy between sign-in and sign-up. Extracted from the
/// screen's `build()` (Migration audit item 6).
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.isSignUp, required this.theme});

  final bool isSignUp;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
        ),
        const SizedBox(height: 32),
        Text(
          isSignUp ? 'Create Your Shared Space' : 'Welcome Back',
          style: AppTypography.cormorant(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isSignUp
              ? 'Begin your exclusive space to capture memories and stay in sync.'
              : 'Step back into your shared world.',
          style: AppTypography.spectral(
            fontSize: 16,
            color: theme.textColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
