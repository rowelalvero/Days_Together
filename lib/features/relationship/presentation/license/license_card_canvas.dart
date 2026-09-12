import 'package:flutter/material.dart';

import 'package:days_together/features/relationship/presentation/license/cards/flippable_license_card.dart';
import 'package:days_together/features/relationship/presentation/license/flippable_license_preview.dart';
import 'package:days_together/features/relationship/profile_state.dart';
import 'package:days_together/features/relationship/workspace_state.dart';

/// The `RepaintBoundary`-wrapped license card display on the main
/// [RelationshipLicenseScreen] view -- either both partners' cards stacked,
/// or whichever single card is currently selected. Extracted from the
/// screen's `build()` (Migration audit item 6); [licenseKey] is the same
/// `RepaintBoundary` key the export studio captures from.
class LicenseCardCanvas extends StatelessWidget {
  const LicenseCardCanvas({
    super.key,
    required this.licenseKey,
    required this.myCardKey,
    required this.partnerCardKey,
    required this.showBoth,
    required this.isYourLicense,
    required this.profileState,
    required this.workspaceState,
    required this.onAvatarTapYour,
    required this.onAvatarTapPartner,
  });

  final GlobalKey licenseKey;
  final GlobalKey<FlippableLicenseCardState> myCardKey;
  final GlobalKey<FlippableLicenseCardState> partnerCardKey;
  final bool showBoth;
  final bool isYourLicense;
  final ProfileState profileState;
  final WorkspaceState workspaceState;
  final VoidCallback onAvatarTapYour;
  final VoidCallback onAvatarTapPartner;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: licenseKey,
      child: Container(
        child: showBoth
            ? Column(
                children: [
                  FlippableLicensePreview(
                    cardKey: myCardKey,
                    isYourLicense: true,
                    profileState: profileState,
                    workspaceState: workspaceState,
                    onAvatarTap: onAvatarTapYour,
                  ),
                  const SizedBox(height: 20),
                  FlippableLicensePreview(
                    cardKey: partnerCardKey,
                    isYourLicense: false,
                    profileState: profileState,
                    workspaceState: workspaceState,
                    onAvatarTap: onAvatarTapPartner,
                  ),
                ],
              )
            : isYourLicense
            ? FlippableLicensePreview(
                cardKey: myCardKey,
                isYourLicense: true,
                profileState: profileState,
                workspaceState: workspaceState,
                onAvatarTap: onAvatarTapYour,
              )
            : FlippableLicensePreview(
                cardKey: partnerCardKey,
                isYourLicense: false,
                profileState: profileState,
                workspaceState: workspaceState,
                onAvatarTap: onAvatarTapPartner,
              ),
      ),
    );
  }
}
