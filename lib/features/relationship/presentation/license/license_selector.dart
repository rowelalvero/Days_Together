import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ConsumerWidget, WidgetRef;

import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The "My License" / "Partner's License" tab selector. Extracted out of
/// `RelationshipLicenseScreenState._buildLicenseSelector` (Migration
/// Phase 8).
class LicenseSelector extends ConsumerWidget {
  const LicenseSelector({
    super.key,
    required this.theme,
    required this.isYourLicense,
    required this.onChanged,
  });

  final LoveStoryTheme theme;
  final bool isYourLicense;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Both names came in on a prop-drilled `CoupleSession` that
    // `LicenseScreen` resolved with `ref.read`, so the tab labels here went
    // stale the moment either partner renamed themselves -- nothing marked
    // this widget dirty. Watching `profileControllerProvider` directly makes
    // the labels track renames and drops the prop.
    final profile = ref.watch(profileControllerProvider);
    final myName = profile.yourName?.isNotEmpty == true ? profile.yourName! : "My";
    final partnerName = profile.partnerName?.isNotEmpty == true
        ? profile.partnerName!
        : "Partner";

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _selectorTab(
              title: "$myName's License",
              isActive: isYourLicense,
              onTap: () {
                if (!isYourLicense) onChanged(true);
              },
            ),
          ),
          Expanded(
            child: _selectorTab(
              title: "$partnerName's License",
              isActive: !isYourLicense,
              onTap: () {
                if (isYourLicense) onChanged(false);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectorTab({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? theme.accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: theme.accentColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.bold, color: isActive
                  ? Colors.white
                  : theme.textColor.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }
}
