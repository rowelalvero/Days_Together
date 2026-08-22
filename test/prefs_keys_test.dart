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

    test('every key matches a string literal or a PrefsKeys.* reference in its current owning file', () {
      // Originally checked only relationship_provider.dart for the raw
      // string literal (Phase 0, when it owned all 41 keys and didn't yet
      // reference PrefsKeys itself). Phase 5 moved the 24 license keys to
      // LicenseController, which *does* reference PrefsKeys.yourGender etc.
      // instead of the raw literal -- exactly what prefs_keys.dart's own
      // header says happens "naturally as each field is extracted into its
      // owning controller". So a key now counts as covered if its owning
      // file contains either the raw literal or `PrefsKeys.<constantName>`.
      // Phase 6b-1 moved the remaining 17 keys' literals (session/pairing
      // identity + workspace + profile) from relationship_provider.dart to
      // couple_session.dart, which now owns the real engine --
      // relationship_provider.dart is a pass-through facade with no
      // SharedPreferences access of its own. Add a file here each time a
      // further extraction moves another group's literals to a new owner.
      final sources = [
        'lib/providers/relationship_provider.dart',
        'lib/providers/couple_session.dart',
        'lib/features/relationship/license_controller.dart',
      ].map((path) => File(path).readAsStringSync()).toList();

      // Recover the value -> constant-name mapping directly from
      // prefs_keys.dart, rather than hand-maintaining a second copy of it
      // here, so this test can't silently drift from the real registry.
      final prefsKeysSource = File('lib/core/constants/prefs_keys.dart').readAsStringSync();
      final constantNameFor = <String, String>{};
      for (final match in RegExp(r"static const String (\w+) = '([^']+)';").allMatches(prefsKeysSource)) {
        constantNameFor[match.group(2)!] = match.group(1)!;
      }

      final missing = <String>[];
      for (final key in PrefsKeys.all) {
        final constantName = constantNameFor[key];
        final found = sources.any((source) =>
            source.contains("'$key'") || (constantName != null && source.contains('PrefsKeys.$constantName')));
        if (!found) missing.add(key);
      }
      expect(
        missing,
        isEmpty,
        reason: 'PrefsKeys entries with no matching literal or PrefsKeys.* reference in any current owning file: $missing',
      );
    });
  });
}
