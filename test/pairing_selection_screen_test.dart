// PairingSelectionScreen's cards must stay tappable after coming back from
// a screen they opened. go_router drops a push's Future when the router
// refreshes while the pushed screen is open -- the app's router refreshes on
// every session change -- so a "navigating" flag cleared by that Future used
// to stay stuck and make every card ignore taps.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/app/router/route_names.dart';
import 'package:days_together/features/authentication/presentation/pages/pairing_selection_screen.dart';

Widget _stub(String label) => Builder(
  builder: (context) => Scaffold(
    body: TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(label),
    ),
  ),
);

Future<ValueNotifier<int>> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final refresh = ValueNotifier(0);
  addTearDown(refresh.dispose);
  final router = GoRouter(
    initialLocation: Routes.pairing,
    refreshListenable: refresh,
    routes: [
      GoRoute(
        path: Routes.pairing,
        builder: (_, _) => const PairingSelectionScreen(),
      ),
      GoRoute(path: Routes.joinCode, builder: (_, _) => _stub('join page')),
      GoRoute(path: Routes.recover, builder: (_, _) => _stub('recover page')),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
  return refresh;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('cards still work after going back from a pushed screen', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Join with Pairing Code'));
    await tester.pumpAndSettle();
    expect(find.text('join page'), findsOneWidget);

    await tester.tap(find.text('join page'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recover Existing Relationship'));
    await tester.pumpAndSettle();
    expect(find.text('recover page'), findsOneWidget);
  });

  testWidgets('cards still work when the router refreshed meanwhile', (
    tester,
  ) async {
    final refresh = await _pump(tester);

    await tester.tap(find.text('Recover Existing Relationship'));
    await tester.pumpAndSettle();
    expect(find.text('recover page'), findsOneWidget);

    // A session change while the pushed screen is open.
    refresh.value++;
    await tester.pumpAndSettle();

    await tester.tap(find.text('recover page'));
    await tester.pumpAndSettle();
    expect(find.text('recover page'), findsNothing);

    await tester.tap(find.text('Join with Pairing Code'));
    await tester.pumpAndSettle();
    expect(find.text('join page'), findsOneWidget);
  });

  testWidgets('a double tap opens the screen only once', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Join with Pairing Code'));
    await tester.tap(find.text('Join with Pairing Code'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('join page'), findsOneWidget);

    // One pop returns to the selection screen -- there was no second copy.
    await tester.tap(find.text('join page'));
    await tester.pumpAndSettle();
    expect(find.text('Join with Pairing Code'), findsOneWidget);
    expect(find.text('join page'), findsNothing);
  });
}
