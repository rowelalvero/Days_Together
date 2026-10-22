import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';

/// One tab button in [UnifiedFloatingBar]'s bottom nav row. Extracted from
/// [LoveStoryScreenState]'s `_buildNavItem` (Migration audit item 6).
///
/// The visible pill is icon-only, so [label] is what screen readers announce
/// (with the selected state) and what the long-press tooltip shows. The tap
/// area is at least 48x48 -- the Android minimum -- around the 48x40 pill.
class NavItem extends StatelessWidget {
  const NavItem({
    super.key,
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  /// Minimum tap-target edge, per Android's 48dp guideline.
  static const double minTapTarget = 48;

  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool isSelected;
  final LoveStoryTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: minTapTarget,
              minHeight: minTapTarget,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.accentColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  // 0.6, not 0.4: an unselected tab is still a meaningful
                  // control and needs 3:1 non-text contrast. At 0.4 the
                  // light (Off-White) theme measured 2.2:1.
                  color: isSelected
                      ? theme.accentColor
                      : theme.textColor.withValues(alpha: 0.6),
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
