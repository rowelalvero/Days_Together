import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ConsumerWidget, WidgetRef;

import 'package:days_together/features/relationship/presentation/license/flippable_license_preview.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/themes/app_typography.dart';

/// A pinch-to-zoom, tap-to-flip enlarged view of one partner's license
/// card. Extracted out of
/// `RelationshipLicenseScreenState._showEnlargedDialog` (Migration
/// Phase 8).
class EnlargedLicenseDialog extends ConsumerWidget {
  const EnlargedLicenseDialog({super.key, required this.isYourLicense});

  final bool isYourLicense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);
    final workspaceState = ref.watch(workspaceControllerProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InteractiveViewer(
            minScale: 1.0,
            maxScale: 3.5,
            child: SizedBox(
              width: double.infinity,
              child: AspectRatio(
                aspectRatio: 85.60 / 53.98,
                child: FlippableLicensePreview(
                  isYourLicense: isYourLicense,
                  profileState: profileState,
                  workspaceState: workspaceState,
                  onAvatarTap: () {},
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '💡 Pinch to zoom • Tap card to flip',
            style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w500, color: ref.watch(themeControllerProvider).currentLoveTheme.textColor.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}
