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

    test('no file under lib/widgets/ imports supabase_flutter', () {
      final violations = <String>[];
      for (final file in _dartFilesUnder('lib/widgets')) {
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
}
