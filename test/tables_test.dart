// Mirrors prefs_keys_test.dart: Tables is a registry, and a registry is only
// useful if it stays consistent.

import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/core/constants/tables.dart';

void main() {
  group('Tables', () {
    test('has no duplicate names', () {
      expect(Tables.all.toSet().length, Tables.all.length);
    });

    test('every constant is listed in all', () {
      // `all` is hand-maintained, so a constant added without being listed
      // would silently escape the duplicate check above.
      expect(Tables.all, contains(Tables.users));
      expect(Tables.all, contains(Tables.loveNotes));
      expect(Tables.all, contains(Tables.userFcmTokens));
      expect(Tables.all.length, 17);
    });

    test('names are snake_case, matching Postgres', () {
      for (final name in Tables.all) {
        expect(
          RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name),
          isTrue,
          reason: '"$name" is not a valid unquoted Postgres identifier',
        );
      }
    });
  });
}
