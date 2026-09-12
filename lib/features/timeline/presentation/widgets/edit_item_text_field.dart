import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// A labeled text field in [EditItemDialog] (title, location, or story).
/// Extracted from its `_buildTextField` (Migration audit item 6).
class EditItemTextField extends StatelessWidget {
  const EditItemTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.theme,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final LoveStoryTheme theme;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.bodyLarge(
            color: theme.textColor.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ).copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        GlassContainer(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: AppTypography.bodyLarge(
              color: theme.textColor,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintStyle: AppTypography.body(
                color: theme.textColor.withValues(alpha: 0.24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
