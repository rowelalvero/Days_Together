import 'package:flutter/material.dart';

import 'package:days_together/features/relationship/presentation/license/export/license_card_preview.dart';
import 'package:days_together/providers/couple_session.dart';

/// The export studio's transparent-background template -- just the license
/// card(s), no decorative frame, for pasting into other designs. Extracted
/// out of `ExportStudioBottomSheetState._buildTransparentTemplate`
/// (Migration Phase 8).
class TransparentExportTemplate extends StatelessWidget {
  const TransparentExportTemplate({
    super.key,
    required this.rp,
    required this.showBoth,
    required this.isYourLicense,
    required this.exportFront,
  });

  final CoupleSession rp;
  final bool showBoth;
  final bool isYourLicense;
  final bool exportFront;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 800,
      height: showBoth ? 1040 : 504,
      color: Colors.transparent,
      child: showBoth
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaledLicenseCardPreview(
                  isYourLicense: true,
                  showFront: exportFront,
                  rp: rp,
                  targetWidth: 760,
                ),
                const SizedBox(height: 32),
                ScaledLicenseCardPreview(
                  isYourLicense: false,
                  showFront: exportFront,
                  rp: rp,
                  targetWidth: 760,
                ),
              ],
            )
          : ScaledLicenseCardPreview(
              isYourLicense: isYourLicense,
              showFront: exportFront,
              rp: rp,
              targetWidth: 800,
            ),
    );
  }
}
