// Widget tests for WrappedArchiveScreen, written before extracting its
// `_buildYearCard` and `_emptyState` methods into real widget classes --
// these pin the screen's current rendered behavior so the extraction can
// be verified rather than assumed safe.
//
// WrappedService is a pure SharedPreferences-backed service (no network),
// so archived years are seeded directly via
// SharedPreferences.setMockInitialValues -- a raw placeholder string is
// enough for getArchivedYears() to find them, since loadArchive() (which
// would need to parse real WrappedData JSON) is only called when a year
// card is tapped. Year cards are never tapped here: doing so calls
// context.push, and this suite deliberately never mounts a real
// GoRouter, matching this app's other screen tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/features/wrapped/presentation/pages/wrapped_archive_screen.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: WrappedArchiveScreen()));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WrappedArchiveScreen', () {
    testWidgets('shows the empty state when there are no archives', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester);

      expect(find.text('❤️ Wrapped Archive'), findsOneWidget);
      expect(find.text('No archives yet'), findsOneWidget);
    });

    testWidgets('renders archived years sorted newest-first', (tester) async {
      SharedPreferences.setMockInitialValues({
        'wrapped_archive_2023': 'placeholder',
        'wrapped_archive_2024': 'placeholder',
      });
      await _pump(tester);

      expect(find.text('Wrapped 2024'), findsOneWidget);
      expect(find.text('Wrapped 2023'), findsOneWidget);
      expect(find.text('Your year in review'), findsNWidgets(2));

      final firstYear = tester.getTopLeft(find.text('Wrapped 2024'));
      final secondYear = tester.getTopLeft(find.text('Wrapped 2023'));
      expect(firstYear.dy, lessThan(secondYear.dy));
    });

    testWidgets('the back button pops the screen', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WrappedArchiveScreen(),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('❤️ Wrapped Archive'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('❤️ Wrapped Archive'), findsNothing);
    });
  });
}
