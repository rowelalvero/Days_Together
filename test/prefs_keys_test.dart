import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/core/constants/prefs_keys.dart';

void main() {
  group('PrefsKeys', () {
    test('contains exactly 41 entries (Phase 0 exit criterion)', () {
      expect(PrefsKeys.all.length, 41);
    });

    test('has no duplicate keys', () {
      expect(PrefsKeys.all.toSet().length, PrefsKeys.all.length);
    });

    test('every key matches a string literal that exists in relationship_provider.dart', () {
      final source = File('lib/providers/relationship_provider.dart').readAsStringSync();
      final missing = <String>[];
      for (final key in PrefsKeys.all) {
        if (!source.contains("'$key'")) {
          missing.add(key);
        }
      }
      expect(
        missing,
        isEmpty,
        reason: 'PrefsKeys entries with no matching literal in relationship_provider.dart: $missing',
      );
    });
  });
}
