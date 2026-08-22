import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:days_together/features/relationship/data/signature_codec.dart';
import 'package:days_together/features/relationship/presentation/license/cards/card_shell.dart';
import 'package:days_together/features/relationship/presentation/license/license_widgets.dart';
import 'package:days_together/features/relationship/presentation/license/painters/signature_painter.dart';
import 'package:days_together/services/storage_url_service.dart';
import 'package:days_together/shared/storage_image.dart';
import 'package:days_together/themes/app_typography.dart';

/// The relationship license card's front face -- photo ID layout with
/// avatar, name, and vital-stats fields. Extracted out of
/// relationship_license_screen.dart (Migration Phase 8) -- renamed from
/// `_LicenseFront` since it now needs to be public to be shared across
/// the license/ file split.
class LicenseFront extends StatelessWidget {
  final String holderName;

  final String? holderGender;

  final String? holderAvatar;

  final DateTime? holderBirthdate;

  final String? holderAddress;

  final String holderNationality;

  final String holderWeight;

  final String holderHeight;

  final String holderBloodType;

  final String holderEyeColor;

  final String holderConditions;

  final DateTime? holderDateIssued;

  final String? holderSignature;

  final DateTime? startDate;

  final int? calculatedAge;

  final bool isYourLicense;

  final VoidCallback onAvatarTap;

  const LicenseFront({
    super.key,
    required this.holderName,

    required this.holderGender,

    required this.holderAvatar,

    required this.holderBirthdate,

    required this.holderAddress,

    required this.holderNationality,

    required this.holderWeight,

    required this.holderHeight,

    required this.holderBloodType,

    required this.holderEyeColor,

    required this.holderConditions,

    required this.holderDateIssued,

    required this.holderSignature,

    required this.startDate,

    required this.calculatedAge,

    required this.isYourLicense,

    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    final dobStr = holderBirthdate != null
        ? dateFormat.format(holderBirthdate!)
        : 'Not set';

    final relDateStr = startDate != null
        ? dateFormat.format(startDate!)
        : 'Not set';

    final issuedDateStr = holderDateIssued != null
        ? dateFormat.format(holderDateIssued!)
        : (startDate != null ? dateFormat.format(startDate!) : 'Not set');

    return CardShell(
      child: _buildLandscapeLayout(
        dateFormat,
        dobStr,
        relDateStr,
        issuedDateStr,
      ),
    );
  }

  Widget _buildLandscapeLayout(
    DateFormat dateFormat,
    String dobStr,
    String relDateStr,
    String issuedDateStr,
  ) {
    final strokes = SignatureCodec.decode(holderSignature);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(isCompact: true),
        const SizedBox(height: 4),
        goldDivider(),
        const SizedBox(height: 6),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 70,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: onAvatarTap,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 70,
                            height: 85,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFD4AF37),
                                width: 1.2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6.8),
                              child: holderAvatar != null
                                  ? StorageImage(
                                      bucket: StorageBuckets.avatars,
                                      storageRef: holderAvatar,
                                      fit: BoxFit.cover,
                                      errorWidget: (context) => Container(
                                        color: Colors.white10,
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.white30,
                                          size: 28,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.white10,
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white30,
                                        size: 28,
                                      ),
                                    ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFFD4AF37),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Color(0xFF1A0A2E),
                              size: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 70,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3.5),
                        child: CustomPaint(
                          painter: ScaleSignaturePainter(
                            strokes: strokes,
                            color: const Color(0xFFD4AF37),
                            strokeWidth: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'SIGNATURE',
                      style: AppTypography.body(fontSize: 5, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.35)).copyWith(letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 1,
                color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      holderName.toUpperCase(),
                      style: AppTypography.heading(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white).copyWith(letterSpacing: 0.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _infoField(
                            'NATIONALITY',
                            holderNationality,
                            isCompact: true,
                          ),
                        ),
                        Expanded(
                          child: _infoField(
                            'SEX',
                            holderGender ?? '—',
                            isCompact: true,
                          ),
                        ),
                        Expanded(
                          child: _infoField(
                            'BLOOD TYPE',
                            holderBloodType,
                            isCompact: true,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _infoField(
                            'DATE OF BIRTH',
                            dobStr,
                            isCompact: true,
                          ),
                        ),
                        Expanded(
                          child: _infoField(
                            'AGE',
                            calculatedAge != null ? '$calculatedAge YRS' : '—',
                            isCompact: true,
                          ),
                        ),
                        Expanded(
                          child: _infoField(
                            'EYE COLOR',
                            holderEyeColor,
                            isCompact: true,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _infoField(
                            'HEIGHT',
                            holderHeight,
                            isCompact: true,
                          ),
                        ),
                        Expanded(
                          child: _infoField(
                            'WEIGHT',
                            holderWeight,
                            isCompact: true,
                          ),
                        ),
                        Expanded(
                          child: _infoField(
                            'CONDITIONS',
                            holderConditions,
                            isCompact: true,
                          ),
                        ),
                      ],
                    ),
                    _infoField(
                      'ADDRESS',
                      holderAddress?.isNotEmpty == true
                          ? holderAddress!
                          : 'NOT SET',
                      isCompact: true,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _infoField(
                            'RELATIONSHIP DATE',
                            relDateStr,
                            isCompact: true,
                          ),
                        ),
                        Expanded(
                          child: _infoField(
                            'DATE ISSUED',
                            issuedDateStr,
                            isCompact: true,
                          ),
                        ),
                        Expanded(
                          child: _infoField(
                            'EXPIRATION DATE',
                            'NO EXPIRY ∞',
                            isCompact: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({required bool isCompact}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_rounded,
              color: const Color(0xFFD4AF37),
              size: isCompact ? 10 : 12,
            ),
            const SizedBox(width: 8),
            Text(
              'OFFICIAL RELATIONSHIP ID CARD',
              style: AppTypography.body(fontSize: isCompact ? 8 : 9, fontWeight: FontWeight.w900, color: const Color(0xFFD4AF37)).copyWith(letterSpacing: isCompact ? 2 : 3),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.favorite_rounded,
              color: const Color(0xFFD4AF37),
              size: isCompact ? 10 : 12,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'CERTIFIED BY THE DEPARTMENT OF LOVE',
          style: AppTypography.body(fontSize: isCompact ? 6 : 7, fontWeight: FontWeight.w800, color: const Color(0xFFD4AF37).withValues(alpha: 0.6)).copyWith(letterSpacing: 1),
        ),
      ],
    );
  }

  Widget _infoField(String label, String value, {required bool isCompact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.body(fontSize: isCompact ? 5.5 : 7, fontWeight: FontWeight.w800, color: const Color(0xFFD4AF37).withValues(alpha: 0.65)).copyWith(letterSpacing: 0.6),
        ),
        const SizedBox(height: 1),
        Text(
          value.toUpperCase(),
          style: AppTypography.body(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
