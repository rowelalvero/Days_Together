import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/theme/presentation/widgets/mode_chip.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The Dark/Light mode toggle in the custom theme designer. Extracted from
/// `_CustomThemeDesignerState._buildDarkLightToggle` (Migration audit item
/// 6).
class DarkLightToggle extends StatelessWidget {
  const DarkLightToggle({
    super.key,
    required this.isDark,
    required this.theme,
    required this.onChanged,
  });

  final bool isDark;
  final LoveStoryTheme theme;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 18,
      opacity: 0.06,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: ModeChip(
              label: 'Dark',
              icon: Icons.dark_mode_rounded,
              isSelected: isDark,
              theme: theme,
              onTap: () => onChanged(true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ModeChip(
              label: 'Light',
              icon: Icons.light_mode_rounded,
              isSelected: !isDark,
              theme: theme,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}
