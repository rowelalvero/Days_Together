import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:days_together/features/relationship/data/license_qr_codec.dart';
import 'package:days_together/features/relationship/presentation/license/cards/card_shell.dart';
import 'package:days_together/features/relationship/presentation/license/license_widgets.dart';
import 'package:days_together/themes/app_typography.dart';

/// The relationship license card's back face -- emergency contact info
/// and a QR code encoding the license details. Extracted out of
/// relationship_license_screen.dart (Migration Phase 8) -- renamed from
/// `_LicenseBack` since it now needs to be public to be shared across
/// the license/ file split.
class LicenseBack extends StatelessWidget {
  final String holderName;

  final String? holderGender;

  final DateTime? holderBirthdate;

  final String? holderAddress;

  final String holderNationality;

  final String holderWeight;

  final String holderHeight;

  final String holderBloodType;

  final String holderEyeColor;

  final String holderConditions;

  final DateTime? holderDateIssued;

  final String emergencyName;

  final String emergencyPhone;

  final String? emergencyAddress;

  final DateTime? startDate;

  const LicenseBack({
    super.key,
    required this.holderName,

    required this.holderGender,

    required this.holderBirthdate,

    required this.holderAddress,

    required this.holderNationality,

    required this.holderWeight,

    required this.holderHeight,

    required this.holderBloodType,

    required this.holderEyeColor,

    required this.holderConditions,

    required this.holderDateIssued,

    required this.emergencyName,

    required this.emergencyPhone,

    this.emergencyAddress,

    required this.startDate,
  });

  String _buildQrData() => LicenseQrCodec.encode(
    holderName: holderName,
    holderGender: holderGender,
    holderBirthdate: holderBirthdate,
    holderAddress: holderAddress,
    holderNationality: holderNationality,
    holderWeight: holderWeight,
    holderHeight: holderHeight,
    holderBloodType: holderBloodType,
    holderEyeColor: holderEyeColor,
    holderConditions: holderConditions,
    holderDateIssued: holderDateIssued,
    emergencyName: emergencyName,
    emergencyPhone: emergencyPhone,
    startDate: startDate,
  );

  @override
  Widget build(BuildContext context) {
    return CardShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,

        children: [
          // Left portion: Rotated Emergency Details
          SizedBox(
            width: 125,
            height: double.infinity,
            child: RotatedBox(
              quarterTurns: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'EMERGENCY INFORMATION',
                    style: AppTypography.body(fontSize: 8, fontWeight: FontWeight.w900, color: const Color(0xFFD4AF37)).copyWith(letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 4),
                  goldDivider(),
                  const SizedBox(height: 4),
                  Text(
                    'IN CASE OF EMERGENCY CONTACT:',
                    style: AppTypography.body(fontSize: 7, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 4),
                  _emergencyContact(
                    name: emergencyName,
                    phone: emergencyPhone,
                    address: emergencyAddress,
                    icon: Icons.favorite_rounded,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Divider line (runs vertically)
          Container(
            width: 1,
            height: double.infinity,
            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
          ),

          const SizedBox(width: 12),

          // Right portion: QR Code
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(6),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.circular(12),

                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.2),

                      blurRadius: 10,
                    ),
                  ],
                ),

                child: QrImageView(
                  data: _buildQrData(),

                  version: QrVersions.auto,

                  size: 150, // Enlarged size

                  backgroundColor: Colors.white,

                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,

                    color: Color(0xFF1A0A2E),
                  ),

                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,

                    color: Color(0xFF1A0A2E),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emergencyContact({
    required String name,
    required String phone,
    String? address,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
        ),
      ),

      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),

            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.15),

              shape: BoxShape.circle,
            ),

            child: Icon(icon, color: const Color(0xFFD4AF37), size: 16),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              mainAxisSize: MainAxisSize.min,

              children: [
                Text(
                  name.toUpperCase(),

                  style: AppTypography.body(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white).copyWith(letterSpacing: 1),
                ),

                if (address != null && address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    address.toUpperCase(),

                    style: AppTypography.body(fontSize: 8, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ],

                const SizedBox(height: 4),

                Text(
                  phone,

                  style: AppTypography.bodyMono(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFD4AF37)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
