import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/core/constants/prefs_keys.dart';

void main() {
  group('PrefsKeys', () {
    test('contains exactly 43 entries (Phase 0 exit criterion, +2 from the item-14 sweep fix)', () {
      expect(PrefsKeys.all.length, 43);
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
      // couple_session.dart, which now owns the real engine. Definition-of-
      // Done sweep item 4 later deleted relationship_provider.dart entirely
      // once its last direct readers converted to CoupleSession, so it's no
      // longer in this list. Add a file here each time a further extraction
      // moves another group's literals to a new owner. The item-14
      // Definition-of-Done fix added timelineIsAscending and
      // vaultPinFallback, originally owned by both timeline_controller.dart/
      // timeline_provider.dart and vault_controller.dart/vault_provider.dart
      // -- the item-3 gap-fix (Phase 1) later deleted timeline_provider.dart
      // and vault_provider.dart outright once their Riverpod controllers
      // fully superseded them, so only the two controller files remain here.
      final sources = [
        'lib/providers/couple_session.dart',
        'lib/features/relationship/license_controller.dart',
        'lib/features/timeline/timeline_controller.dart',
        'lib/features/vault/vault_controller.dart',
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
