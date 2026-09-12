import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';

/// One tab button in [UnifiedFloatingBar]'s bottom nav row. Extracted from
/// [LoveStoryScreenState]'s `_buildNavItem` (Migration audit item 6).
class NavItem extends StatelessWidget {
  const NavItem({
    super.key,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool isSelected;
  final LoveStoryTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.accentColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected
                  ? theme.accentColor
                  : theme.textColor.withValues(alpha: 0.4),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
