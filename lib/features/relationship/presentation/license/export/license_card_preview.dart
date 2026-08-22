import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ConsumerWidget, WidgetRef;

import 'package:days_together/features/relationship/license_controller.dart';
import 'package:days_together/features/relationship/license_details.dart';
import 'package:days_together/features/relationship/presentation/license/cards/license_back.dart';
import 'package:days_together/features/relationship/presentation/license/cards/license_front.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/services/date_helper.dart';

/// Renders either partner's license face (front or back) for the export
/// studio's preview -- resolves `LicenseDetails`' per-partner fields down
/// to the flattened, display-ready values `LicenseFront`/`LicenseBack`
/// expect. Extracted out of `ExportStudioBottomSheetState._buildCard`
/// (Migration Phase 8).
class LicenseCardPreview extends ConsumerWidget {
  const LicenseCardPreview({
    super.key,
    required this.isYourLicense,
    required this.showFront,
    required this.rp,
  });

  final bool isYourLicense;
  final bool showFront;
  final CoupleSession rp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final license = ref.watch(licenseControllerProvider).value ?? const LicenseDetails();
    final myName = rp.yourName ?? 'You';
    final partnerName = rp.partnerName ?? 'Partner';
    final myPhone = license.yourPhone?.isNotEmpty == true
        ? license.yourPhone!
        : 'Not provided';
    final partnerPhone = license.partnerPhone?.isNotEmpty == true
        ? license.partnerPhone!
        : 'Not provided';

    final name = isYourLicense ? myName : partnerName;
    final gender = isYourLicense ? license.yourGender : license.partnerGender;
    final avatar = isYourLicense ? rp.yourAvatarPath : rp.partnerAvatarPath;
    final birthdate = isYourLicense ? license.yourBirthdate : license.partnerBirthdate;
    final address = isYourLicense ? license.yourAddress : license.partnerAddress;
    final nationality = isYourLicense
        ? (license.yourNationality ?? 'Love Land')
        : (license.partnerNationality ?? 'Love Land');
    final weight = isYourLicense ? (license.yourWeight ?? '—') : (license.partnerWeight ?? '—');
    final height = isYourLicense ? (license.yourHeight ?? '—') : (license.partnerHeight ?? '—');
    final bloodType = isYourLicense ? (license.yourBloodType ?? '—') : (license.partnerBloodType ?? '—');
    final eyeColor = isYourLicense ? (license.yourEyeColor ?? '—') : (license.partnerEyeColor ?? '—');
    final conditions = isYourLicense ? (license.yourConditions ?? 'Madly in Love') : (license.partnerConditions ?? 'Madly in Love');
    final dateIssued = isYourLicense ? license.yourDateIssued : license.partnerDateIssued;
    final signature = isYourLicense ? license.yourSignature : license.partnerSignature;

    final age = isYourLicense
        ? DateHelper.calculateAge(license.yourBirthdate)
        : DateHelper.calculateAge(license.partnerBirthdate);
    final emergencyN = isYourLicense ? partnerName : myName;
    final emergencyP = isYourLicense ? partnerPhone : myPhone;
    final emergencyA = isYourLicense ? license.partnerAddress : license.yourAddress;

    if (showFront) {
      return LicenseFront(
        holderName: name,
        holderGender: gender,
        holderAvatar: avatar,
        holderBirthdate: birthdate,
        holderAddress: address,
        holderNationality: nationality,
        holderWeight: weight,
        holderHeight: height,
        holderBloodType: bloodType,
        holderEyeColor: eyeColor,
        holderConditions: conditions,
        holderDateIssued: dateIssued,
        holderSignature: signature,
        startDate: rp.startDate,
        calculatedAge: age,
        isYourLicense: isYourLicense,
        onAvatarTap: () {},
      );
    } else {
      return LicenseBack(
        holderName: name,
        holderGender: gender,
        holderBirthdate: birthdate,
        holderAddress: address,
        holderNationality: nationality,
        holderWeight: weight,
        holderHeight: height,
        holderBloodType: bloodType,
        holderEyeColor: eyeColor,
        holderConditions: conditions,
        holderDateIssued: dateIssued,
        emergencyName: emergencyN,
        emergencyPhone: emergencyP,
        emergencyAddress: emergencyA,
        startDate: rp.startDate,
      );
    }
  }
}

/// A [LicenseCardPreview] scaled to fit [targetWidth] while preserving the
/// license's real aspect ratio -- used to lay out the same card at
/// different sizes across the export studio's three templates. Extracted
/// out of `ExportStudioBottomSheetState._buildScaledCard` (Migration
/// Phase 8).
class ScaledLicenseCardPreview extends StatelessWidget {
  const ScaledLicenseCardPreview({
    super.key,
    required this.isYourLicense,
    required this.showFront,
    required this.rp,
    required this.targetWidth,
  });

  final bool isYourLicense;
  final bool showFront;
  final CoupleSession rp;
  final double targetWidth;

  @override
  Widget build(BuildContext context) {
    final double targetHeight = targetWidth / (85.60 / 53.98);
    return SizedBox(
      width: targetWidth,
      height: targetHeight,
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: 350,
          height: 350 / (85.60 / 53.98),
          child: LicenseCardPreview(
            isYourLicense: isYourLicense,
            showFront: showFront,
            rp: rp,
          ),
        ),
      ),
    );
  }
}
