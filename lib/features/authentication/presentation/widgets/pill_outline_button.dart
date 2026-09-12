import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';

/// The rounded outlined icon+label button shared by [CodeActionsRow]'s
/// two buttons. Extracted from [CreateCoupleCodeScreen]'s `_buildButton`
/// (Migration audit item 6).
class PillOutlineButton extends StatelessWidget {
  const PillOutlineButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.theme,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.textColor,
        side: BorderSide(color: theme.textColor.withValues(alpha: 0.15)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
