import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/features/relationship/data/license_qr_codec.dart';

void main() {
  group('LicenseQrCodec.encode', () {
    test('produces the expected banner for a fully-populated license', () {
      final result = LicenseQrCodec.encode(
        holderName: 'Ada Lovelace',
        holderGender: 'female',
        holderBirthdate: DateTime(1990, 12, 10),
        holderAddress: '123 Analytical Engine Way',
        holderNationality: 'british',
        holderWeight: '60kg',
        holderHeight: '165cm',
        holderBloodType: 'o+',
        holderEyeColor: 'brown',
        holderConditions: 'none',
        holderDateIssued: DateTime(2020, 1, 1),
        emergencyName: 'Charles Babbage',
        emergencyPhone: '555-0100',
        startDate: DateTime(2019, 6, 15),
      );

      expect(result, contains('═══ RELATIONSHIP LICENSE ═══'));
      expect(result, contains('HOLDER: ADA LOVELACE'));
      expect(result, contains('SEX: FEMALE'));
      expect(result, contains('BIRTHDATE: 1990-12-10'));
      expect(result, contains('NATIONALITY: BRITISH'));
      expect(result, contains('WEIGHT: 60KG'));
      expect(result, contains('HEIGHT: 165CM'));
      expect(result, contains('ADDRESS: 123 Analytical Engine Way'));
      expect(result, contains('Name: CHARLES BABBAGE'));
      expect(result, contains('Phone: 555-0100'));
      expect(result, contains('BLOOD TYPE: O+'));
      expect(result, contains('EYES COLOR: BROWN'));
      expect(result, contains('CONDITIONS: NONE'));
      expect(result, contains('TOGETHER SINCE: 2019-06-15'));
      expect(result, contains('DATE ISSUED: 2020-01-01'));
      expect(result, contains('STATUS: VALID FOREVER'));
    });

    test('falls back to placeholders for unset optional fields', () {
      final result = LicenseQrCodec.encode(
        holderName: 'Ada',
        holderGender: null,
        holderBirthdate: null,
        holderAddress: null,
        holderNationality: 'unknown',
        holderWeight: 'unknown',
        holderHeight: 'unknown',
        holderBloodType: 'unknown',
        holderEyeColor: 'unknown',
        holderConditions: 'none',
        holderDateIssued: null,
        emergencyName: 'Someone',
        emergencyPhone: 'unknown',
        startDate: null,
      );

      expect(result, contains('SEX: —'));
      expect(result, contains('BIRTHDATE: Not set'));
      expect(result, contains('ADDRESS: Not set'));
      expect(result, contains('TOGETHER SINCE: Not set'));
      expect(result, contains('DATE ISSUED: Not set'));
    });

    test('date issued falls back to start date when unset, matching the original widget logic', () {
      final result = LicenseQrCodec.encode(
        holderName: 'Ada',
        holderGender: null,
        holderBirthdate: null,
        holderAddress: null,
        holderNationality: 'unknown',
        holderWeight: 'unknown',
        holderHeight: 'unknown',
        holderBloodType: 'unknown',
        holderEyeColor: 'unknown',
        holderConditions: 'none',
        holderDateIssued: null,
        emergencyName: 'Someone',
        emergencyPhone: 'unknown',
        startDate: DateTime(2021, 3, 4),
      );

      expect(result, contains('DATE ISSUED: 2021-03-04'));
    });
  });
}
