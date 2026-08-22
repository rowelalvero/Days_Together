import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:days_together/features/relationship/presentation/license/export/license_card_preview.dart';
import 'package:days_together/features/relationship/presentation/license/license_widgets.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// The export studio's Instagram Story template (1080x1920, portrait).
/// Extracted out of `ExportStudioBottomSheetState._buildStoryTemplate`
/// (Migration Phase 8).
class StoryExportTemplate extends StatelessWidget {
  const StoryExportTemplate({
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
      height: 1920,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A0314),
            Color(0xFF1B072B),
            Color(0xFF2E0942),
            Color(0xFF0A0314),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 200,
            left: -150,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.accentColor.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 300,
            right: -150,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD4AF37).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 1,
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFD4AF37),
                        size: 24,
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 1,
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'OFFICIAL RELATIONSHIP LICENSE',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFFD4AF37)).copyWith(letterSpacing: 4),
                ),
                const SizedBox(height: 10),
                Text(
                  'CERTIFIED BY THE DEPARTMENT OF LOVE',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFD4AF37).withValues(alpha: 0.6)).copyWith(letterSpacing: 1.5),
                ),
                const Spacer(),
                showBoth
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: ScaledLicenseCardPreview(
                              isYourLicense: true,
                              showFront: exportFront,
                              rp: rp,
                              targetWidth: 920,
                            ),
                          ),
                          const SizedBox(height: 60),
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: ScaledLicenseCardPreview(
                              isYourLicense: false,
                              showFront: exportFront,
                              rp: rp,
                              targetWidth: 920,
                            ),
                          ),
                        ],
                      )
                    : Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: ScaledLicenseCardPreview(
                          isYourLicense: isYourLicense,
                          showFront: exportFront,
                          rp: rp,
                          targetWidth: 920,
                        ),
                      ),
                const Spacer(),
                goldDivider(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFFD4AF37),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'STATUS: VALID FOREVER',
                      style: AppTypography.body(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFD4AF37)).copyWith(letterSpacing: 2),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'TOGETHER SINCE $startDateStr',
                  style: AppTypography.body(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.5)).copyWith(letterSpacing: 1.5),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
