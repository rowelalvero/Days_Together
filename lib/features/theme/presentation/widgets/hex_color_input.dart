import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The "#RRGGBB" text field in the custom theme designer. Extracted from
/// `_CustomThemeDesignerState._buildHexInput` (Migration audit item 6) --
/// [controller]'s lifecycle stays owned by the designer's State, same as
/// before the extraction.
class HexColorInput extends StatelessWidget {
  const HexColorInput({
    super.key,
    required this.controller,
    required this.theme,
    required this.onColorSubmitted,
  });

  final TextEditingController controller;
  final LoveStoryTheme theme;
  final ValueChanged<int> onColorSubmitted;

  void _submit() {
    final hex = controller.text.replaceAll('#', '').trim();
    if (hex.length == 6) {
      final colorInt = int.tryParse('FF$hex', radix: 16);
      if (colorInt != null) {
        onColorSubmitted(colorInt);
        controller.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 18,
      opacity: 0.06,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            '#',
            style: AppTypography.bodyMono(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.accentColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTypography.bodyMono(
                fontSize: 14,
                color: theme.textColor,
              ),
              decoration: InputDecoration(
                hintText: 'Enter hex (e.g. FF4D6D)',
                hintStyle: AppTypography.bodyMono(
                  fontSize: 14,
                  color: theme.textColor.withValues(alpha: 0.25),
                ),
                border: InputBorder.none,
              ),
              maxLength: 6,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              onSubmitted: (_) => _submit(),
            ),
          ),
          IconButton(
            onPressed: _submit,
            icon: Icon(Icons.check_circle_rounded, color: theme.accentColor),
          ),
        ],
      ),
    );
  }
}
