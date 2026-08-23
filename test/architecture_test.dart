// Architecture rules, enforced. See docs/architecture/architecture-rules.md
// and docs/architecture/testing-strategy.md for the full rationale.
//
// This suite is a ratchet: rules are added here only once they are actually
// true, as each migration phase makes them so (docs/architecture/
// migration-roadmap.md). It intentionally does NOT check every rule in
// architecture-rules.md yet -- only the two confirmed true as of Phase 0:
//
//   Rule 1 -- UI must not directly access Supabase.
//   Rule 13 (partial) -- no CustomPainter (a Flutter rendering type) lives
//     in lib/models/, since a model importing Flutter's rendering layer is
//     a model->UI layering violation.
//
//   Phase 1 exit criterion -- no lib/providers/ file other than
//     relationship_provider.dart itself references RelationshipProvider;
//     every domain provider depends on CoupleSession instead.
//   Phase 3 exit criteria -- lib/navigator_key.dart is deleted;
//     notification_service.dart imports no screen; MaterialPageRoute is
//     confined to the three files whose Navigator.push sites are dialogs,
//     not navigational destinations, and so are deliberately out of
//     go_router's scope (ADR-007).
//   Phase 4 exit criterion -- every class under lib/models/ has all-`final`
//     fields (ADR-003's "Neutral" consequence; the model-immutability rule
//     folded into Migration Phase 4).
//
// Plain dart:io file-walking and string search -- no new dependency, no
// codegen, consistent with this project's explicit no-over-engineering
// stance (docs/architecture/Days_Together_Architecture_Design_Specification.md
// section 6.3).

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

List<File> _dartFilesUnder(String relativeDir) {
  final dir = Directory(relativeDir);
  if (!dir.existsSync()) return [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

void main() {
  group('Architecture Rule 1 -- UI must not directly access Supabase', () {
    test('no file under lib/screens/ imports supabase_flutter', () {
      final violations = <String>[];
      for (final file in _dartFilesUnder('lib/screens')) {
        final content = file.readAsStringSync();
        if (content.contains("import 'package:supabase_flutter")) {
          violations.add(file.path);
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Screens importing supabase_flutter directly (see ADR-004): $violations',
      );
    });

    test('no widget file under lib/shared/ or lib/features/*/presentation/ imports supabase_flutter', () {
      // Phase 7b relocated lib/widgets/ into lib/shared/ (design-system-tier,
      // feature-agnostic components) and lib/features/<name>/presentation/
      // (feature-specific ones) -- this is their combined successor scope.
      final violations = <String>[];
      final widgetDirs = [
        ..._dartFilesUnder('lib/shared'),
        for (final entry in Directory('lib/features').listSync())
          if (entry is Directory) ..._dartFilesUnder('${entry.path}/presentation'),
      ];
      for (final file in widgetDirs) {
        final content = file.readAsStringSync();
        if (content.contains("import 'package:supabase_flutter")) {
          violations.add(file.path);
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Widgets importing supabase_flutter directly (see ADR-004): $violations',
      );
    });
  });

  group('Architecture Rule 13 -- models must not import Flutter\'s rendering layer', () {
    test('no class under lib/models/ extends CustomPainter', () {
      final violations = <String>[];
      for (final file in _dartFilesUnder('lib/models')) {
        final content = file.readAsStringSync();
        if (content.contains('extends CustomPainter')) {
          violations.add(file.path);
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Model files declaring a CustomPainter (model->UI violation, see migration-roadmap.md Phase 0): $violations',
      );
    });
  });

  group('Migration Phase 1 / item 4 -- RelationshipProvider is gone; everything depends on CoupleSession', () {
    test('no lib/ file has a live code reference to RelationshipProvider', () {
      // RelationshipProvider started as a pass-through facade over
      // CoupleSession (Phase 6b-1) kept alive only so UI files that hadn't
      // converted yet didn't need to change in that phase. The
      // Definition-of-Done sweep's item 4 converted its last direct readers
      // (license/ presentation files, bento_grid.dart, noteit_screen.dart)
      // to CoupleSession directly and deleted relationship_provider.dart
      // outright -- this is the literal exit criterion the item's
      // Definition-of-Done row always promised, finally enforced. Comment
      // lines are skipped deliberately: several files' doc comments
      // accurately narrate RelationshipProvider's history (e.g. "extracted
      // from RelationshipProvider in Phase 5"), which is legitimate
      // documentation, not a regression -- this rule only catches an actual
      // reintroduced import/type/constructor reference.
      final violations = <String>[];
      for (final file in _dartFilesUnder('lib')) {
        for (final rawLine in file.readAsLinesSync()) {
          final line = rawLine.trim();
          if (line.startsWith('//')) continue;
          if (line.contains('RelationshipProvider')) {
            violations.add(file.path);
            break;
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'RelationshipProvider referenced but it was deleted (see migration-roadmap.md item 4): $violations',
      );
    });
  });

  group('Item 3 gap-fix Phase 1 -- the 12 retired domain providers are gone; everything depends on their Riverpod controllers', () {
    test('no lib/ file has a live code reference to any of the 12 retired provider class names', () {
      // The 12 domain providers (TimelineProvider, BucketListProvider,
      // TimeCapsuleProvider, DailyMoodProvider, GiftReminderProvider,
      // VaultProvider, CalendarProvider, TopicCardsProvider, NoteitProvider,
      // LoveChatProvider, CurrentlyProvider, NotificationPreferencesProvider)
      // each had a complete, faithful Riverpod port under lib/features/<name>/
      // before their UI call sites were ever converted -- once every
      // context.watch<X>()/context.read<X>() site was flipped to
      // ref.watch/ref.read on the corresponding *ControllerProvider, the old
      // lib/providers/*.dart files and their main.dart registrations were
      // deleted outright (see migration-roadmap.md's "Corrected on
      // implementation" note for item 3). Comment lines are skipped
      // deliberately -- several files' doc comments accurately narrate these
      // providers' history (e.g. "Riverpod port of TimelineProvider"), which
      // is legitimate documentation, not a regression -- this rule only
      // catches an actual reintroduced import/type/constructor reference.
      const retiredProviderNames = [
        'TimelineProvider',
        'BucketListProvider',
        'TimeCapsuleProvider',
        'DailyMoodProvider',
        'GiftReminderProvider',
        'VaultProvider',
        'CalendarProvider',
        'TopicCardsProvider',
        'NoteitProvider',
        'LoveChatProvider',
        'CurrentlyProvider',
        'NotificationPreferencesProvider',
      ];
      final violations = <String>[];
      for (final file in _dartFilesUnder('lib')) {
        for (final rawLine in file.readAsLinesSync()) {
          final line = rawLine.trim();
          if (line.startsWith('//')) continue;
          for (final name in retiredProviderNames) {
            if (line.contains(name)) {
              violations.add('${file.path}: $name');
              break;
            }
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'A retired provider class name was referenced but it was deleted (see migration-roadmap.md item 3): $violations',
      );
    });
  });

  group('Item 3 gap-fix Phase 2 -- ThemeProvider is gone; everything depends on ThemeController', () {
    test('no lib/ file has a live code reference to ThemeProvider', () {
      // ThemeProvider (lib/providers/theme_provider.dart) was device-local,
      // not couple-scoped, so it needed a Riverpod controller built from
      // scratch (ThemeController/ThemeState under lib/features/theme/)
      // rather than swapping onto an already-existing port, unlike the 12
      // providers in Phase 1 above. Once every context.watch<ThemeProvider>()/
      // context.read<ThemeProvider>()/Provider.of<ThemeProvider>() site was
      // flipped to ref.watch/ref.read on themeControllerProvider, the old
      // lib/providers/theme_provider.dart file and its main.dart registration
      // were deleted outright (see migration-roadmap.md's "Corrected on
      // implementation" note for item 3). Comment lines are skipped
      // deliberately -- theme_state.dart/theme_controller.dart's own doc
      // comments accurately narrate this port's history (e.g. "Riverpod port
      // of ThemeProvider"), which is legitimate documentation, not a
      // regression -- this rule only catches an actual reintroduced
      // import/type/constructor reference.
      final violations = <String>[];
      for (final file in _dartFilesUnder('lib')) {
        for (final rawLine in file.readAsLinesSync()) {
          final line = rawLine.trim();
          if (line.startsWith('//')) continue;
          if (line.contains('ThemeProvider')) {
            violations.add(file.path);
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'ThemeProvider was referenced but it was deleted (see migration-roadmap.md item 3): $violations',
      );
    });
  });

  group('Migration Phase 3 -- go_router owns screen-level navigation (ADR-007)', () {
    test('lib/navigator_key.dart no longer exists', () {
      expect(File('lib/navigator_key.dart').existsSync(), isFalse);
    });

    test('notification_service.dart imports no screen file', () {
      final content = File('lib/services/notification_service.dart').readAsStringSync();
      final violations = RegExp(r"import 'package:days_together/screens/[^']+';")
          .allMatches(content)
          .map((m) => m.group(0)!)
          .toList();
      expect(
        violations,
        isEmpty,
        reason: 'notification_service.dart must resolve payloads to routes, not import screens directly (ADR-007): $violations',
      );
    });

    test('MaterialPageRoute is confined to the three known dialog-shaped call sites', () {
      // AddItemDialog, EditItemDialog, and SignatureDrawingDialog are
      // pushed via Navigator.push rather than showDialog, but are
      // conceptually dialogs (no deep-link/back-button target of their
      // own) -- explicitly out of ADR-007's "distinct screens" scope. Every
      // other MaterialPageRoute site was converted to a named go_router
      // route.
      const exceptions = {
        'lib/screens/love_story_screen.dart',
        'lib/screens/timeline/memory_detail_screen.dart',
        // relationship_license_screen.dart's two SignatureDrawingDialog
        // push sites, post-Phase-8 file split:
        'lib/features/relationship/presentation/license/license_screen.dart',
        'lib/features/relationship/presentation/license/edit/edit_license_sheet.dart',
        // Deliberately preserved as plain Navigator (not dialogs, but a
        // provably-safe conversion couldn't be made -- see the inline
        // comments at each site for the specific redirect-fight risk):
        'lib/screens/onboarding/create_couple_code_screen.dart',
        'lib/screens/onboarding/recover_relationship_screen.dart',
      };
      final violations = <String>[];
      for (final file in _dartFilesUnder('lib')) {
        final normalized = file.path.replaceAll('\\', '/');
        if (exceptions.any((e) => normalized.endsWith(e))) continue;
        final content = file.readAsStringSync();
        if (content.contains('MaterialPageRoute(')) {
          violations.add(normalized);
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'MaterialPageRoute used outside the known, documented exceptions -- convert to a named Routes.* entry (see migration-roadmap.md Phase 3): $violations',
      );
    });
  });

  group('Migration Phase 4 -- every model is immutable (ADR-003)', () {
    test('no class under lib/models/ declares a non-final instance field', () {
      // Plain line-based scan, not a real parser -- consistent with this
      // suite's stated "no codegen" approach. Tracks brace depth so it only
      // inspects lines at a class's top level (depth 1), skipping method/
      // constructor bodies (depth 2+) where a local variable declaration
      // must not be mistaken for a field. A field declaration is
      // recognized as a line ending in `;` with no `(` on it (ruling out
      // method signatures and constructor initializer lists) that doesn't
      // start with `final`/`static`/`const`/an annotation/a comment.
      final fieldDeclaration = RegExp(r'^[A-Za-z_][\w<>?., ]*\s[A-Za-z_]\w*(\s*=\s*[^;]+)?;$');
      final violations = <String>[];

      for (final file in _dartFilesUnder('lib/models')) {
        final lines = file.readAsLinesSync();
        var depth = 0;
        var inClassAtDepth1 = false;

        for (final rawLine in lines) {
          final line = rawLine.trim();

          if (depth == 1 &&
              inClassAtDepth1 &&
              line.isNotEmpty &&
              !line.startsWith('final ') &&
              !line.startsWith('static ') &&
              !line.startsWith('const ') &&
              !line.startsWith('@') &&
              !line.startsWith('//') &&
              !line.contains('(') &&
              !line.contains('=>') &&
              !RegExp(r'\bget\s').hasMatch(line) &&
              fieldDeclaration.hasMatch(line)) {
            violations.add('${file.path}: $line');
          }

          if (RegExp(r'^\s*(?:abstract\s+)?class\s+\w').hasMatch(rawLine) && depth == 0) {
            inClassAtDepth1 = true;
          }

          for (final char in rawLine.split('')) {
            if (char == '{') {
              depth++;
            } else if (char == '}') {
              depth--;
              if (depth == 0) inClassAtDepth1 = false;
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Mutable field found in lib/models/ -- add final and convert call sites to copyWith (see migration-roadmap.md Phase 4): $violations',
      );
    });
  });

  group('Migration Phase 7b -- features depend on each other only through public state (feature-boundaries.md)', () {
    test('no lib/features/<A>/** file imports a non-controller/non-state file from lib/features/<B>/**', () {
      // feature-boundaries.md's cross-feature rule: a feature may depend on
      // another feature only through that feature's public state (a
      // Riverpod provider intentionally exported), never through a
      // private/internal file path. This is checkable today because every
      // feature's public surface follows one of two file-naming
      // conventions established since Phase 6: `*_controller.dart` (the
      // NotifierProvider) or `*_state.dart` (the typed state it exposes).
      final violations = <String>[];
      final importPattern = RegExp(r"import 'package:days_together/features/([a-z_]+)/([^']+)';");

      for (final file in _dartFilesUnder('lib/features')) {
        final normalized = file.path.replaceAll('\\', '/');
        final ownFeatureMatch = RegExp(r'^lib/features/([a-z_]+)/').firstMatch(normalized);
        if (ownFeatureMatch == null) continue;
        final ownFeature = ownFeatureMatch.group(1)!;

        final content = file.readAsStringSync();
        for (final match in importPattern.allMatches(content)) {
          final targetFeature = match.group(1)!;
          if (targetFeature == ownFeature) continue;

          final targetFileName = match.group(2)!.split('/').last;
          final isPublicSurface =
              targetFileName.endsWith('_controller.dart') || targetFileName.endsWith('_state.dart');
          if (!isPublicSurface) {
            violations.add('$normalized -> ${match.group(0)}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: "A feature imported another feature's internal file directly instead of its public controller/state (see feature-boundaries.md's cross-feature rule, migration-roadmap.md Phase 7b): $violations",
      );
    });
  });

  group('Migration Phase 5/8 -- SharedPreferences keys are centralized in PrefsKeys (item 14)', () {
    test('no lib/ file outside prefs_keys.dart calls a SharedPreferences getter/setter with a raw string literal', () {
      // The Definition-of-Done sweep found 2 of 19 in-use keys had never
      // been added to PrefsKeys at all, and several call sites still used
      // raw literals even for keys that already had a constant -- see
      // migration-roadmap.md's Definition-of-Done sweep section. This rule
      // is the promised guard against that regressing silently again.
      final rawLiteralCall = RegExp(r"prefs\.(get|set)[A-Za-z]*\('[a-zA-Z_]+'");
      final violations = <String>[];

      for (final file in _dartFilesUnder('lib')) {
        final normalized = file.path.replaceAll('\\', '/');
        if (normalized.endsWith('lib/core/constants/prefs_keys.dart')) continue;
        final content = file.readAsStringSync();
        if (rawLiteralCall.hasMatch(content)) {
          violations.add(normalized);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'SharedPreferences call using a raw string literal instead of a PrefsKeys constant (see migration-roadmap.md item 14): $violations',
      );
    });
  });
}
