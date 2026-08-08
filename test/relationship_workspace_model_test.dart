import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/models/relationship_workspace.dart';

void main() {
  group('RelationshipWorkspace Model', () {
    test('fromMap parses valid workspace record correctly', () {
      final map = {
        'id': 'couple-123',
        'partner_a_id': 'user-a',
        'partner_b_id': 'user-b',
        'partner_a_email': 'a@example.com',
        'partner_b_email': 'b@example.com',
        'status': 'active',
        'pairing_code': 'PAIR12',
        'recovery_lookup_key': 'REC123',
        'is_premium': true,
        'start_date': '2022-02-14T00:00:00.000Z',
        'start_time_hour': 18,
        'start_time_minute': 30,
        'story_title': 'Our Journey',
        'created_at': '2022-02-14T10:00:00.000Z',
      };

      final workspace = RelationshipWorkspace.fromMap(map);

      expect(workspace.id, 'couple-123');
      expect(workspace.partnerAId, 'user-a');
      expect(workspace.partnerBId, 'user-b');
      expect(workspace.status, 'active');
      expect(workspace.isPremium, true);
      expect(workspace.startTimeHour, 18);
      expect(workspace.startTimeMinute, 30);
      expect(workspace.storyTitle, 'Our Journey');
    });

    test('fromMap applies default status "waiting" if omitted', () {
      final map = {'id': 'couple-999'};
      final workspace = RelationshipWorkspace.fromMap(map);

      expect(workspace.id, 'couple-999');
      expect(workspace.status, 'waiting');
      expect(workspace.isPremium, false);
    });

    test('toMap produces valid Map representation', () {
      final workspace = RelationshipWorkspace(
        id: 'c-1',
        partnerAId: 'u-1',
        status: 'active',
        isPremium: false,
        storyTitle: 'Love Story',
      );

      final map = workspace.toMap();

      expect(map['id'], 'c-1');
      expect(map['partner_a_id'], 'u-1');
      expect(map['status'], 'active');
      expect(map['story_title'], 'Love Story');
      expect(map['is_premium'], false);
    });

    test('copyWith allows modifying individual properties', () {
      final original = RelationshipWorkspace(
        id: 'c-1',
        status: 'waiting',
        pairingCode: 'XYZ123',
      );

      final updated = original.copyWith(status: 'active', pairingCode: null);

      expect(updated.id, 'c-1');
      expect(updated.status, 'active');
    });
  });
}
