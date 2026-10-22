import 'package:flutter/material.dart';

import 'package:days_together/shared/widgets/glass_container.dart';
import 'package:days_together/app/theme/theme_manager.dart';

import 'package:days_together/shared/widgets/semantic_tap.dart';

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
            label: 'Show one license',
            isActive: !showBoth,
            onTap: () => onShowBothChanged(false),
          ),
          const SizedBox(width: 12),
          _miniToggleButton(
            icon: Icons.people_rounded,
            label: 'Show both licenses',
            isActive: showBoth,
            onTap: () => onShowBothChanged(true),
          ),
        ],
      ),
    );
  }

  Widget _miniToggleButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return SemanticTap(
      label: label,
      selected: isActive,
      minTapTarget: 48,
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
