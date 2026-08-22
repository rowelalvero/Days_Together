import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ConsumerWidget, WidgetRef;

import 'package:days_together/features/relationship/license_controller.dart';
import 'package:days_together/features/relationship/license_details.dart';
import 'package:days_together/features/relationship/presentation/license/cards/flippable_license_card.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/services/date_helper.dart';

/// Renders either partner's [FlippableLicenseCard], resolving
/// `LicenseDetails`' per-partner fields down to the flattened,
/// display-ready values the card expects. Extracted during Migration
/// Phase 8 after the same resolution logic turned up duplicated three
/// times in `RelationshipLicenseScreenState` (the main card display, the
/// enlarged-view dialog, and the export studio's preview) with no shared
/// home -- consolidating it here removes the duplication these
/// extractions kept surfacing, not just relocating it a fourth time.
class FlippableLicensePreview extends ConsumerWidget {
  const FlippableLicensePreview({
    super.key,
    this.cardKey,
    required this.isYourLicense,
    required this.rp,
    required this.onAvatarTap,
  });

  /// Forwarded to the underlying [FlippableLicenseCard] so callers can
  /// reach its `FlippableLicenseCardState` (e.g. to trigger a flip
  /// programmatically). Not named `key` to avoid confusion with this
  /// widget's own identity key.
  final Key? cardKey;

  final bool isYourLicense;
  final RelationshipProvider rp;
  final VoidCallback onAvatarTap;

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

    if (isYourLicense) {
      return FlippableLicenseCard(
        key: cardKey,
        holderName: myName,
        holderGender: license.yourGender,
        holderAvatar: rp.yourAvatarPath,
        holderBirthdate: license.yourBirthdate,
        holderAddress: license.yourAddress,
        holderNationality: (license.yourNationality ?? 'Love Land'),
        holderWeight: (license.yourWeight ?? '—'),
        holderHeight: (license.yourHeight ?? '—'),
        holderBloodType: (license.yourBloodType ?? '—'),
        holderEyeColor: (license.yourEyeColor ?? '—'),
        holderConditions: (license.yourConditions ?? 'Madly in Love'),
        holderDateIssued: license.yourDateIssued,
        holderSignature: license.yourSignature,
        startDate: rp.startDate,
        calculatedAge: DateHelper.calculateAge(license.yourBirthdate),
        isYourLicense: true,
        onAvatarTap: onAvatarTap,
        emergencyName: partnerName,
        emergencyPhone: partnerPhone,
        emergencyAddress: license.partnerAddress,
      );
    } else {
      return FlippableLicenseCard(
        key: cardKey,
        holderName: partnerName,
        holderGender: license.partnerGender,
        holderAvatar: rp.partnerAvatarPath,
        holderBirthdate: license.partnerBirthdate,
        holderAddress: license.partnerAddress,
        holderNationality: (license.partnerNationality ?? 'Love Land'),
        holderWeight: (license.partnerWeight ?? '—'),
        holderHeight: (license.partnerHeight ?? '—'),
        holderBloodType: (license.partnerBloodType ?? '—'),
        holderEyeColor: (license.partnerEyeColor ?? '—'),
        holderConditions: (license.partnerConditions ?? 'Madly in Love'),
        holderDateIssued: license.partnerDateIssued,
        holderSignature: license.partnerSignature,
        startDate: rp.startDate,
        calculatedAge: DateHelper.calculateAge(license.partnerBirthdate),
        isYourLicense: false,
        onAvatarTap: onAvatarTap,
        emergencyName: myName,
        emergencyPhone: myPhone,
        emergencyAddress: license.yourAddress,
      );
    }
  }
}
