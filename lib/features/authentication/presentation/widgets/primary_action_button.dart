import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The full-width call to action at the bottom of the onboarding screens.
///
/// Its label ink is picked against the accent ([LoveStoryTheme.onAccentColor])
/// so it stays readable on pastel accents, and the disabled state keeps a
/// legible label (text ink on a faint accent wash) instead of white on a
/// half-transparent accent.
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.theme,
    this.icon,
    this.isLoading = false,
    this.loadingLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final LoveStoryTheme theme;

  /// Trailing icon, e.g. an arrow for "next step" actions.
  final IconData? icon;
  final bool isLoading;

  /// Shown beside the spinner while [isLoading]; defaults to [label].
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final disabledInk = theme.textColor.withValues(alpha: 0.55);
    final textStyle = AppTypography.button(
      fontSize: 17,
      fontWeight: FontWeight.bold,
    );

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.accentColor,
          foregroundColor: theme.onAccentColor,
          disabledBackgroundColor: theme.accentColor.withValues(alpha: 0.18),
          disabledForegroundColor: disabledInk,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.radii.md),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: disabledInk,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: _fit(Text(loadingLabel ?? label, style: textStyle)),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: _fit(Text(label, style: textStyle))),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, size: 20),
                  ],
                ],
              ),
      ),
    );
  }

  /// Shrinks a long label at large system text sizes instead of overflowing
  /// a narrow phone's button.
  Widget _fit(Widget text) => FittedBox(fit: BoxFit.scaleDown, child: text);
}
