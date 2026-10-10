import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The shared layout of the pairing/recovery onboarding screens: the theme
/// gradient, a 48dp back button, a heading + supporting line, scrolling
/// content, and an optional action pinned to the bottom so the primary
/// button never scrolls out of reach (it rides above the keyboard instead).
class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({
    super.key,
    required this.theme,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.children,
    this.bottom,
  });

  final LoveStoryTheme theme;
  final Gradient gradient;
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final List<Widget> children;

  /// Pinned below the scrolling content -- the screen's primary action.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: IconButton(
                  onPressed: onBack,
                  tooltip: 'Back',
                  iconSize: 22,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: theme.textColor,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: AppTypography.cormorant(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor,
                            height: 1.15,
                          ),
                        ),
                      ),
                      SizedBox(height: theme.spacing.sm + 4),
                      Text(
                        subtitle,
                        style: AppTypography.spectral(
                          fontSize: 16,
                          color: theme.textColor.withValues(alpha: 0.8),
                        ).copyWith(height: 1.45),
                      ),
                      SizedBox(height: theme.spacing.xl),
                      ...children,
                    ],
                  ),
                ),
              ),
              if (bottom != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: bottom,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A numbered step label ("1  Share your code") that splits a multi-part
/// onboarding screen into scannable sections.
class AuthStepHeader extends StatelessWidget {
  const AuthStepHeader({
    super.key,
    required this.number,
    required this.title,
    required this.theme,
  });

  final int number;
  final String title;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Step $number: $title',
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.accentColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: AppTypography.body(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.onAccentColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: AppTypography.body(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The near-solid surface the onboarding cards sit on: readable over any
/// theme gradient, unlike a few-percent tint of the text color.
BoxDecoration authCardDecoration(LoveStoryTheme theme, {Color? border}) =>
    BoxDecoration(
      color: theme.isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(theme.radii.lg - 4),
      border: Border.all(
        color: border ?? theme.textColor.withValues(alpha: 0.12),
        width: 1.5,
      ),
    );
