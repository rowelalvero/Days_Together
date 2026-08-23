// Validates that buildAppRoot() (the exact production widget-tree wiring,
// factored out of main.dart's runApp) exposes a working coupleSessionProvider.
//
// This test previously validated Phase 2 of the architecture migration
// (ADR-002): a `provider`-package Provider tree bridged into a second,
// nested Riverpod ProviderScope via coupleSessionProvider.overrideWithValue,
// asserting both containers resolved to the identical CoupleSession
// instance. That whole two-container strangler bridge was retired in Item 3
// gap-fix Phase 3 (front 4 of the architecture migration's `provider`-
// removal item): coupleSessionProvider now constructs the single
// CoupleSession instance itself, so there is only ever one container and
// nothing left to compare identity across. This file instead confirms the
// single remaining, actually load-bearing property: reading
// coupleSessionProvider through the production widget tree returns a live,
// stable CoupleSession -- the same instance on every read, not reconstructed
// per call (which would silently break every hub/domain controller's
// `dependencies: [coupleSessionProvider]` wiring).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/main.dart';
import 'package:days_together/providers/couple_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'coupleSessionProvider resolves to a live, stable CoupleSession instance through the production widget tree',
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

      final container = ProviderScope.containerOf(probeContext);
      final first = container.read(coupleSessionProvider);
      final second = container.read(coupleSessionProvider);

      expect(
        identical(first, second),
        isTrue,
        reason: 'coupleSessionProvider must return the same CoupleSession '
            'instance on every read within the same container -- a plain '
            'Provider constructs its value exactly once and caches it.',
      );
    },
  );
}
