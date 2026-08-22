import 'package:flutter/material.dart';

import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/theme_manager.dart';

/// The you/both toggle shown above the license card. Extracted out of
/// `RelationshipLicenseScreenState._buildControlBar` (Migration Phase 8).
class ControlBar extends StatelessWidget {
  const ControlBar({
    super.key,
    required this.theme,
    required this.showBoth,
    required this.onShowBothChanged,
  });

  final LoveStoryTheme theme;
  final bool showBoth;
  final ValueChanged<bool> onShowBothChanged;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 20,
      opacity: 0.05,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _miniToggleButton(
            icon: Icons.person_rounded,
            isActive: !showBoth,
            onTap: () => onShowBothChanged(false),
          ),
          const SizedBox(width: 12),
          _miniToggleButton(
            icon: Icons.people_rounded,
            isActive: showBoth,
            onTap: () => onShowBothChanged(true),
          ),
        ],
      ),
    );
  }

  Widget _miniToggleButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive
              ? theme.accentColor
              : theme.textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isActive
              ? Colors.white
              : theme.textColor.withValues(alpha: 0.6),
          size: 20,
        ),
      ),
    );
  }
}
