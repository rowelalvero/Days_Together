import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:days_together/features/relationship/presentation/license/export/license_card_preview.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// The export studio's square post template (1080x1080). Extracted out of
/// `ExportStudioBottomSheetState._buildPostTemplate` (Migration Phase 8).
class PostExportTemplate extends StatelessWidget {
  const PostExportTemplate({
    super.key,
    required this.theme,
    required this.rp,
    required this.showBoth,
    required this.isYourLicense,
    required this.exportFront,
  });

  final LoveStoryTheme theme;
  final CoupleSession rp;
  final bool showBoth;
  final bool isYourLicense;
  final bool exportFront;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final startDateStr = rp.startDate != null
        ? dateFormat.format(rp.startDate!)
        : 'FOREVER';

    return Container(
      width: 1080,
      height: 1080,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F051D), Color(0xFF260D3E), Color(0xFF0F051D)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 140,
            top: 140,
            child: Container(
              width: 800,
              height: 800,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.accentColor.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Text(
                      'DEPARTMENT OF LOVE',
                      style: AppTypography.body(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFD4AF37)).copyWith(letterSpacing: 5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'OFFICIAL RELATIONSHIP CERTIFICATE',
                      style: AppTypography.body(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.4)).copyWith(letterSpacing: 2),
                    ),
                  ],
                ),
                showBoth
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: ScaledLicenseCardPreview(
                              isYourLicense: true,
                              showFront: exportFront,
                              rp: rp,
                              targetWidth: 660,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: ScaledLicenseCardPreview(
                              isYourLicense: false,
                              showFront: exportFront,
                              rp: rp,
                              targetWidth: 660,
                            ),
                          ),
                        ],
                      )
                    : Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.55),
                              blurRadius: 35,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: ScaledLicenseCardPreview(
                          isYourLicense: isYourLicense,
                          showFront: exportFront,
                          rp: rp,
                          targetWidth: 860,
                        ),
                      ),
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFD4AF37),
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'VALID FOREVER',
                          style: AppTypography.body(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFFD4AF37)).copyWith(letterSpacing: 3),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFD4AF37),
                          size: 14,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ANNIVERSARY DATE: $startDateStr',
                      style: AppTypography.body(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.4)).copyWith(letterSpacing: 1.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
