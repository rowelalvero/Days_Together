import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// A single Dark/Light selector chip in the custom theme designer's mode
/// toggle. Moved out of the screen file into its own file as part of
/// Migration audit item 6 -- it was already a proper widget class, just
/// living inline in the screen.
class ModeChip extends StatelessWidget {
  const ModeChip({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final LoveStoryTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.accentColor.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? theme.accentColor
                  : theme.textColor.withValues(alpha: 0.08),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? theme.accentColor
                    : theme.textColor.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.caption(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? theme.accentColor
                      : theme.textColor.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
