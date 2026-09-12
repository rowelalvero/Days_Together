import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The shared field chrome (label, icon, filled background, borders) for
/// [AuthScreen]'s email/password/confirm-password fields. Extracted from
/// the screen's `_buildInputDecoration` (Migration audit item 6).
InputDecoration authInputDecoration({
  required String label,
  required IconData icon,
  required LoveStoryTheme theme,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: AppTypography.body(
      color: theme.textColor.withValues(alpha: 0.4),
    ),
    prefixIcon: Icon(icon, color: theme.textColor.withValues(alpha: 0.4)),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: theme.textColor.withValues(alpha: 0.05),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: theme.textColor.withValues(alpha: 0.1)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: theme.textColor.withValues(alpha: 0.1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: theme.accentColor, width: 1.5),
    ),
    errorStyle: AppTypography.caption(color: Colors.redAccent),
  );
}
