import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ConsumerWidget, WidgetRef;
import 'package:provider/provider.dart';

import 'package:days_together/features/relationship/presentation/license/flippable_license_preview.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/providers/theme_provider.dart';
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
    final rp = context.read<RelationshipProvider>();

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
                  rp: rp,
                  onAvatarTap: () {},
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '💡 Pinch to zoom • Tap card to flip',
            style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w500, color: context.watch<ThemeProvider>().currentLoveTheme.textColor.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}
