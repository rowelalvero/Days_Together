import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/models/user_profile.dart';

void main() {
  group('UserProfile Model', () {
    test('fromMap parses complete dictionary correctly', () {
      final map = {
        'id': 'user-uuid-123',
        'couple_id': 'couple-uuid-456',
        'display_name': 'Alex',
        'avatar_url': 'https://example.com/avatar.jpg',
        'gender': 'Non-binary',
        'phone': '+1234567890',
        'birthdate': '1995-06-15T00:00:00.000Z',
        'address': '123 Love Lane',
        'nationality': 'Love Land',
        'weight': '65kg',
        'height': '175cm',
        'blood_type': 'O+',
        'eye_color': 'Brown',
        'conditions': 'Madly in Love',
        'date_issued': '2024-01-01T00:00:00.000Z',
        'signature': 'data:image/png;base64,...',
        'current_activity': 'Reading',
        'partner_deleted_notice': false,
        'created_at': '2024-01-01T12:00:00.000Z',
      };

      final profile = UserProfile.fromMap(map);

      expect(profile.id, 'user-uuid-123');
      expect(profile.coupleId, 'couple-uuid-456');
      expect(profile.displayName, 'Alex');
      expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
      expect(profile.gender, 'Non-binary');
      expect(profile.birthdate, DateTime.parse('1995-06-15T00:00:00.000Z'));
      expect(profile.partnerDeletedNotice, false);
    });

    test('fromMap handles minimal dictionary safely', () {
      final map = {
        'id': 'user-uuid-999',
      };

      final profile = UserProfile.fromMap(map);

      expect(profile.id, 'user-uuid-999');
      expect(profile.coupleId, isNull);
      expect(profile.displayName, isNull);
      expect(profile.birthdate, isNull);
      expect(profile.partnerDeletedNotice, false);
    });

    test('toMap converts model to JSON-serializable Map correctly', () {
      final profile = UserProfile(
        id: 'u1',
        coupleId: 'c1',
        displayName: 'Jordan',
        birthdate: DateTime.utc(1990, 5, 20),
        partnerDeletedNotice: true,
      );

      final map = profile.toMap();

      expect(map['id'], 'u1');
      expect(map['couple_id'], 'c1');
      expect(map['display_name'], 'Jordan');
      expect(map['birthdate'], '1990-05-20T00:00:00.000Z');
      expect(map['partner_deleted_notice'], true);
    });

    test('copyWith updates specified fields while preserving others', () {
      final profile = UserProfile(
        id: 'u1',
        displayName: 'Original Name',
        phone: '555-0100',
      );

      final updated = profile.copyWith(displayName: 'New Name');

      expect(updated.id, 'u1');
      expect(updated.displayName, 'New Name');
      expect(updated.phone, '555-0100');
    });
  });
}
