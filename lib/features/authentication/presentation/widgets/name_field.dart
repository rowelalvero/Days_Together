import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The labeled name text field on [AvatarCreationScreen]. Extracted from
/// its `_buildNameField` method (Migration audit item 6).
class NameField extends StatelessWidget {
  const NameField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    required this.theme,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.caption(
            color: theme.textColor.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ).copyWith(letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: AppTypography.body(color: theme.textColor, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.body(
              color: theme.textColor.withValues(alpha: 0.3),
            ),
            filled: true,
            fillColor: theme.textColor.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.textColor.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.textColor.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.accentColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
      ],
    );
  }
}
