// Validates Phase 2 of the architecture migration (ADR-002): hosting
// Riverpod's ProviderScope around the existing Provider tree, with
// coupleSessionProvider bridged to the live CoupleSession instance. Per
// docs/architecture/migration-roadmap.md's Phase 2 validation requirement --
// "one new test asserting override identity" -- this pumps buildAppRoot()
// (the exact production wiring, factored out of main.dart's runApp) around
// a plain probe widget rather than MyApp, deliberately avoiding the
// GoogleFonts-in-tests gap documented in test/couple_session_test.dart's
// Phase 1 history: this test only needs to prove the bridge wires to the
// same object, not that any themed screen renders.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/main.dart';
import 'package:days_together/providers/couple_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'coupleSessionProvider resolves to the same CoupleSession instance the Provider tree holds',
    (tester) async {
      late BuildContext probeContext;

      await tester.pumpWidget(
        buildAppRoot(
          child: Builder(
            builder: (context) {
              probeContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      final fromProviderTree = probeContext.read<CoupleSession>();
      final fromRiverpod =
          ProviderScope.containerOf(probeContext).read(coupleSessionProvider);

      expect(
        identical(fromProviderTree, fromRiverpod),
        isTrue,
        reason: 'the nested ProviderScope override must expose the exact '
            'same CoupleSession instance the Provider tree created, not a copy',
      );
    },
  );
}
