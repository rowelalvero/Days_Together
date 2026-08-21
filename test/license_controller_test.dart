// Tests for LicenseController (Phase 5 of the architecture migration,
// unit 2 -- extracted from relationship_provider.dart's 24 license fields,
// 10 dead setters, and updateLicense method). No network: isSupabaseAvailable
// is false throughout (no Supabase.initialize() call), matching every other
// offline test in this suite -- CoupleSession.isSupabaseAvailable gates the
// Supabase push half of updateFields, so these tests exercise the
// local-state/SharedPreferences half only, same scope as
// relationship_provider_test.dart's existing coverage.

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/core/constants/prefs_keys.dart';
import 'package:days_together/features/relationship/license_controller.dart';
import 'package:days_together/features/relationship/license_details.dart';
import 'package:days_together/providers/couple_session.dart';

void main() {
  group('LicenseController', () {
    test('build() hydrates an empty LicenseDetails when no keys are set', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final license = await container.read(licenseControllerProvider.future);

      expect(license.yourGender, isNull);
      expect(license.partnerConditions, isNull);
    });

    test('build() hydrates every field from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.yourGender: 'Female',
        PrefsKeys.partnerGender: 'Male',
        PrefsKeys.yourBirthdate: DateTime(1995, 3, 10).toIso8601String(),
        PrefsKeys.yourWeight: '55kg',
        PrefsKeys.partnerSignature: 'sig-data',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final license = await container.read(licenseControllerProvider.future);

      expect(license.yourGender, 'Female');
      expect(license.partnerGender, 'Male');
      expect(license.yourBirthdate, DateTime(1995, 3, 10));
      expect(license.yourWeight, '55kg');
      expect(license.partnerSignature, 'sig-data');
    });

    test('updateFields persists only the provided fields, leaving others untouched', () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.yourGender: 'Female',
        PrefsKeys.partnerGender: 'Male',
      });
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
      );
      addTearDown(container.dispose);
      await container.read(licenseControllerProvider.future);

      await container.read(licenseControllerProvider.notifier).updateFields(
            yourPhone: '555-0100',
          );

      final license = container.read(licenseControllerProvider).value!;
      expect(license.yourPhone, '555-0100');
      // Untouched fields, set before the update, must survive it -- this is
      // the direct regression guard for the sentinel pattern updateFields
      // inherited from the old updateLicense.
      expect(license.yourGender, 'Female');
      expect(license.partnerGender, 'Male');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PrefsKeys.yourPhone), '555-0100');
      expect(prefs.getString(PrefsKeys.yourGender), 'Female');
    });

    test('updateFields(field: null) explicitly clears a field, distinct from omitting it', () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.yourSignature: 'old-signature',
      });
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
      );
      addTearDown(container.dispose);
      await container.read(licenseControllerProvider.future);

      await container.read(licenseControllerProvider.notifier).updateFields(
            yourSignature: null,
          );

      final license = container.read(licenseControllerProvider).value!;
      expect(license.yourSignature, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(PrefsKeys.yourSignature), isFalse);
    });

    test('updateFields only ever writes "your" or "partner" fields as given -- both sides work independently', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
      );
      addTearDown(container.dispose);
      await container.read(licenseControllerProvider.future);

      await container.read(licenseControllerProvider.notifier).updateFields(
            yourBloodType: 'O+',
            partnerBloodType: 'A+',
          );

      final license = container.read(licenseControllerProvider).value!;
      expect(license.yourBloodType, 'O+');
      expect(license.partnerBloodType, 'A+');
    });
  });

  group('LicenseDetails', () {
    test('copyWith preserves untouched fields and supports clearing them', () {
      const original = LicenseDetails(
        yourGender: 'Female',
        yourPhone: '555-0100',
      );

      final kept = original.copyWith(yourGender: 'Non-binary');
      expect(kept.yourPhone, '555-0100');
      expect(kept.yourGender, 'Non-binary');

      final cleared = original.copyWith(yourPhone: null);
      expect(cleared.yourPhone, isNull);
      expect(cleared.yourGender, 'Female');
    });
  });
}
