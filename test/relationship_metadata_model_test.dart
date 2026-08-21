import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/models/relationship_metadata.dart';

void main() {
  group('RelationshipMetadata Model', () {
    // Column set verified against the full migration history -- see
    // lib/data/license_repository.dart's doc comment for the trail
    // (20260712000002_fix_rls_recursion.sql:54-89 both adds these five
    // columns and drops the 30 legacy paired ones).
    test('fromMap parses a complete license_details row correctly', () {
      final map = {
        'couple_id': 'couple-uuid-1',
        'certificate_number': 'DT-2024-000123',
        'issue_date': '2024-01-01T00:00:00.000Z',
        'anniversary': '2022-06-15T00:00:00.000Z',
        'theme': 'classic',
        'relationship_title': 'Together Forever',
      };

      final metadata = RelationshipMetadata.fromMap(map);

      expect(metadata.coupleId, 'couple-uuid-1');
      expect(metadata.certificateNumber, 'DT-2024-000123');
      expect(metadata.issueDate, DateTime.parse('2024-01-01T00:00:00.000Z'));
      expect(metadata.anniversary, DateTime.parse('2022-06-15T00:00:00.000Z'));
      expect(metadata.theme, 'classic');
      expect(metadata.relationshipTitle, 'Together Forever');
    });

    test('fromMap handles a minimal row (only the required couple_id) safely', () {
      final map = {'couple_id': 'couple-uuid-2'};

      final metadata = RelationshipMetadata.fromMap(map);

      expect(metadata.coupleId, 'couple-uuid-2');
      expect(metadata.certificateNumber, isNull);
      expect(metadata.issueDate, isNull);
      expect(metadata.anniversary, isNull);
      expect(metadata.theme, isNull);
      expect(metadata.relationshipTitle, isNull);
    });

    test('toMap converts back to the exact column names the table uses', () {
      final metadata = RelationshipMetadata(
        coupleId: 'couple-uuid-3',
        certificateNumber: 'DT-2024-000456',
        issueDate: DateTime.utc(2024, 3, 10),
        anniversary: DateTime.utc(2021, 12, 25),
        theme: 'midnight',
        relationshipTitle: 'Our Story',
      );

      final map = metadata.toMap();

      expect(map['couple_id'], 'couple-uuid-3');
      expect(map['certificate_number'], 'DT-2024-000456');
      expect(map['issue_date'], '2024-03-10T00:00:00.000Z');
      expect(map['anniversary'], '2021-12-25T00:00:00.000Z');
      expect(map['theme'], 'midnight');
      expect(map['relationship_title'], 'Our Story');
    });

    test('copyWith updates specified fields while preserving others', () {
      final metadata = RelationshipMetadata(
        coupleId: 'couple-uuid-4',
        certificateNumber: 'DT-2024-000789',
        theme: 'classic',
      );

      final updated = metadata.copyWith(theme: 'rose');

      expect(updated.coupleId, 'couple-uuid-4');
      expect(updated.certificateNumber, 'DT-2024-000789');
      expect(updated.theme, 'rose');
    });

    test('a round trip through toMap and back to fromMap is lossless', () {
      final original = RelationshipMetadata(
        coupleId: 'couple-uuid-5',
        certificateNumber: 'DT-2024-000999',
        issueDate: DateTime.utc(2024, 5, 1),
        anniversary: DateTime.utc(2020, 2, 14),
        theme: 'azure',
        relationshipTitle: 'Forever & Always',
      );

      final roundTripped = RelationshipMetadata.fromMap(original.toMap());

      expect(roundTripped.coupleId, original.coupleId);
      expect(roundTripped.certificateNumber, original.certificateNumber);
      expect(roundTripped.issueDate, original.issueDate);
      expect(roundTripped.anniversary, original.anniversary);
      expect(roundTripped.theme, original.theme);
      expect(roundTripped.relationshipTitle, original.relationshipTitle);
    });
  });
}
