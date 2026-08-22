// The single highest-ROI test in the Phase 5 migration
// (docs/architecture/migration-roadmap.md): a realistic 41-key
// SharedPreferences snapshot, captured once here, that every state-ownership
// extraction must continue to hydrate identically. Written before extracting
// LicenseController (the roadmap's explicit ordering requirement), so it
// exists as a regression baseline from the very first extraction onward.
//
// As each field's owning controller changes across Phase 5's extractions,
// this file's per-field assertions are updated to read the new controller
// instead of RelationshipProvider -- but the *raw* SharedPreferences
// assertions (the bottom half of the test) never change: they are the
// controller-agnostic ground truth that hydration is lossless regardless of
// which class currently owns which field, exactly what PrefsKeys exists to
// protect (docs/architecture/caching-strategy.md).
//
// The seeded map below matches a real device that has: completed onboarding,
// paired, is the workspace creator, filled in every license field, and has a
// custom favorite-themes-style profile. It intentionally omits nothing from
// PrefsKeys.all so a silently-dropped key is caught immediately.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/core/constants/prefs_keys.dart';
import 'package:days_together/features/relationship/license_controller.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/providers/relationship_provider.dart';

/// A realistic 41-key hydration snapshot. Every key in [PrefsKeys.all] has
/// an entry here -- the "no key silently dropped" property this test
/// exists to guard is checked directly against this map's own keys, not
/// hand-copied, so PrefsKeys and this fixture can't silently drift apart.
Map<String, Object> _realDeviceSnapshot() {
  final startDate = DateTime(2022, 6, 15).toIso8601String();
  final birthdate = DateTime(1995, 3, 10).toIso8601String();
  final partnerBirthdate = DateTime(1994, 11, 22).toIso8601String();
  final dateIssued = DateTime(2024, 1, 1).toIso8601String();
  final joinDate = DateTime(2022, 6, 1).toIso8601String();

  return {
    // Session / pairing identity
    PrefsKeys.coupleId: 'couple-fixture-1',
    PrefsKeys.partnerId: 'partner-fixture-1',
    PrefsKeys.isPaired: true,
    PrefsKeys.isCreator: true,
    PrefsKeys.onboardingCompleted: true,

    // Workspace fields
    PrefsKeys.coupleCode: 'ABC123',
    PrefsKeys.isPremium: true,
    PrefsKeys.storyTitle: 'Our Love Story',
    PrefsKeys.relationshipStartDate: startDate,
    PrefsKeys.relationshipStartHour: 14,
    PrefsKeys.relationshipStartMinute: 30,

    // Profile fields
    PrefsKeys.yourName: 'Ashwel',
    PrefsKeys.partnerName: 'Rowel',
    PrefsKeys.yourAvatarPath: 'couples/c1/avatars/u1_1700000000.jpg',
    PrefsKeys.partnerAvatarPath: 'couples/c1/avatars/u2_1700000001.jpg',
    PrefsKeys.yourJoinDate: joinDate,
    PrefsKeys.partnerJoinDate: joinDate,

    // License fields (28 paired your_*/partner_* fields)
    PrefsKeys.yourGender: 'Female',
    PrefsKeys.partnerGender: 'Male',
    PrefsKeys.yourPhone: '+1-555-0100',
    PrefsKeys.partnerPhone: '+1-555-0101',
    PrefsKeys.yourBirthdate: birthdate,
    PrefsKeys.partnerBirthdate: partnerBirthdate,
    PrefsKeys.yourAddress: '123 Love Lane',
    PrefsKeys.partnerAddress: '456 Heart Ave',
    PrefsKeys.yourNationality: 'Filipino',
    PrefsKeys.partnerNationality: 'Filipino',
    PrefsKeys.yourWeight: '55kg',
    PrefsKeys.partnerWeight: '70kg',
    PrefsKeys.yourHeight: '160cm',
    PrefsKeys.partnerHeight: '175cm',
    PrefsKeys.yourBloodType: 'O+',
    PrefsKeys.partnerBloodType: 'A+',
    PrefsKeys.yourEyeColor: 'Brown',
    PrefsKeys.partnerEyeColor: 'Black',
    PrefsKeys.yourConditions: 'Madly in Love',
    PrefsKeys.partnerConditions: 'Hopelessly Devoted',
    PrefsKeys.yourDateIssued: dateIssued,
    PrefsKeys.partnerDateIssued: dateIssued,
    PrefsKeys.yourSignature: 'data:image/png;base64,AAA',
    PrefsKeys.partnerSignature: 'data:image/png;base64,BBB',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (MethodCall methodCall) async => null,
    );
  });

  group('Hydration fixture -- the 41-key snapshot survives a fresh load', () {
    test('the fixture itself covers exactly PrefsKeys.all, nothing more or less', () {
      final snapshot = _realDeviceSnapshot();
      expect(
        snapshot.keys.toSet(),
        PrefsKeys.all.toSet(),
        reason: 'the fixture must be updated whenever PrefsKeys.all changes, '
            'or this test stops actually covering all 41 keys',
      );
    });

    test('RelationshipProvider hydrates every currently-owned field from the snapshot', () async {
      // Since Phase 6b-1, RelationshipProvider is a pass-through facade over
      // CoupleSession, which now owns the hydration -- see
      // couple_session_test.dart for the equivalent coverage at the source.
      SharedPreferences.setMockInitialValues(_realDeviceSnapshot());
      final session = CoupleSession();
      final provider = RelationshipProvider(session);
      await Future.delayed(Duration.zero);

      // Session / pairing identity
      expect(provider.coupleId, 'couple-fixture-1');
      expect(provider.isPaired, true);
      expect(provider.isCreator, true);
      expect(provider.isOnboardingComplete, true);

      // Workspace fields
      expect(provider.coupleCode, 'ABC123');
      expect(provider.isPremium, true);
      expect(provider.storyTitle, 'Our Love Story');
      expect(provider.startDate, DateTime(2022, 6, 15));
      expect(provider.startTime?.hour, 14);
      expect(provider.startTime?.minute, 30);

      // Profile fields
      expect(provider.yourName, 'Ashwel');
      expect(provider.partnerName, 'Rowel');
      expect(provider.yourAvatarPath, 'couples/c1/avatars/u1_1700000000.jpg');
      expect(provider.partnerAvatarPath, 'couples/c1/avatars/u2_1700000001.jpg');

      provider.dispose();
    });

    test('LicenseController hydrates the 24 license fields from the same snapshot', () async {
      // The 24 license fields moved off RelationshipProvider to
      // LicenseController in Phase 5 -- see
      // lib/features/relationship/license_controller.dart. Spot-checked
      // across the pairs, not exhaustively (exhaustive coverage of these
      // specific fields lives in test/license_controller_test.dart); this
      // test's job is proving the full-map hydration path still reaches
      // LicenseController after the extraction, not per-field behavior.
      SharedPreferences.setMockInitialValues(_realDeviceSnapshot());
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final license = await container.read(licenseControllerProvider.future);

      expect(license.yourGender, 'Female');
      expect(license.partnerGender, 'Male');
      expect(license.yourBloodType, 'O+');
      expect(license.partnerBloodType, 'A+');
      expect(license.yourSignature, 'data:image/png;base64,AAA');
      expect(license.partnerSignature, 'data:image/png;base64,BBB');
    });

    test('every one of the 41 raw SharedPreferences keys survives a load unchanged', () async {
      // The controller-agnostic ground truth (see file doc comment): this
      // must keep passing across every Phase 5 extraction regardless of
      // which controller currently owns a given field, since none of them
      // are permitted to rename a PrefsKeys entry.
      final snapshot = _realDeviceSnapshot();
      SharedPreferences.setMockInitialValues(snapshot);
      final session = CoupleSession();
      final provider = RelationshipProvider(session);
      await Future.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      for (final key in PrefsKeys.all) {
        final expected = snapshot[key];
        final Object? actual;
        if (expected is bool) {
          actual = prefs.getBool(key);
        } else if (expected is int) {
          actual = prefs.getInt(key);
        } else {
          actual = prefs.getString(key);
        }
        expect(
          actual,
          expected,
          reason: 'key "$key" did not survive hydration unchanged',
        );
      }

      provider.dispose();
    });
  });
}
