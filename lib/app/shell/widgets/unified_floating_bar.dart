import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:days_together/app/shell/widgets/nav_item.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The margin between the floating nav bar and the bottom of the screen,
/// accounting for the device's safe-area inset. Shared with
/// [LoveStoryScreenState]'s own `AnimatedFabLocation` offset calculation,
/// which needs the same value to keep the FAB aligned with this bar.
double floatingBarMarginBottom(BuildContext context) =>
    16.0 + MediaQuery.of(context).padding.bottom;

/// The glassy bottom navigation bar on [LoveStoryScreen], with an optional
/// scrubber row (the timeline tab's date scrubber) that slides in above
/// the tab icons. Extracted from [LoveStoryScreenState]'s
/// `_buildUnifiedFloatingBar` (Migration audit item 6) -- [scrubberRow] is
/// computed by the screen itself (it needs the `GlobalKey<TimelineTabState>`
/// that only the screen holds) and passed straight through.
class UnifiedFloatingBar extends StatelessWidget {
  const UnifiedFloatingBar({
    super.key,
    required this.currentIndex,
    required this.onIndexSelected,
    required this.scrubberRow,
    required this.theme,
  });

  final int currentIndex;
  final ValueChanged<int> onIndexSelected;
  final Widget? scrubberRow;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    final double marginBot = floatingBarMarginBottom(context);

    final isLight = Theme.of(context).brightness == Brightness.light;
    final overlayColor = isLight ? Colors.black : Colors.white;
    final borderColor = isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.2);
    const double opacity = 0.15;

    final showScrubber = currentIndex == 1 && scrubberRow != null;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, marginBot),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        tween: Tween<double>(begin: 35.0, end: showScrubber ? 24.0 : 35.0),
        builder: (context, radius, child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: overlayColor.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: borderColor, width: 1.5),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      overlayColor.withValues(alpha: opacity * 2),
                      overlayColor.withValues(alpha: opacity),
                    ],
                  ),
                ),
                child: child,
              ),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRect(
              child: AnimatedAlign(
                alignment: Alignment.topCenter,
                heightFactor: showScrubber ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                child: AnimatedOpacity(
                  opacity: showScrubber ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  child: scrubberRow ?? const SizedBox(height: 78),
                ),
              ),
            ),
            SizedBox(
              height: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  NavItem(
                    activeIcon: Icons.home_rounded,
                    inactiveIcon: Icons.home_outlined,
                    isSelected: currentIndex == 0,
                    theme: theme,
                    onTap: () => onIndexSelected(0),
                  ),
                  NavItem(
                    activeIcon: Icons.auto_awesome_motion_rounded,
                    inactiveIcon: Icons.auto_awesome_motion_outlined,
                    isSelected: currentIndex == 1,
                    theme: theme,
                    onTap: () => onIndexSelected(1),
                  ),
                  NavItem(
                    activeIcon: Icons.favorite_rounded,
                    inactiveIcon: Icons.favorite_outline_rounded,
                    isSelected: currentIndex == 2,
                    theme: theme,
                    onTap: () => onIndexSelected(2),
                  ),
                  NavItem(
                    activeIcon: Icons.palette_rounded,
                    inactiveIcon: Icons.palette_outlined,
                    isSelected: currentIndex == 3,
                    theme: theme,
                    onTap: () => onIndexSelected(3),
                  ),
                  NavItem(
                    activeIcon: Icons.person_rounded,
                    inactiveIcon: Icons.person_outline_rounded,
                    isSelected: currentIndex == 4,
                    theme: theme,
                    onTap: () => onIndexSelected(4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
