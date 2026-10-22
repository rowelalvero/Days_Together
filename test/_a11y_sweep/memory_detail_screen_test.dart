// Widget tests for MemoryDetailScreen and its EditItemDialog, written
// before extracting the screen's inline SliverAppBar/hero-image/header
// blocks and the dialog's ~6 _buildX methods into real widget classes --
// these pin the current rendered behavior so the extraction can be verified
// rather than assumed safe.
//
// TimelineController is seeded through a subclass whose build() returns a
// fixed state, so no Supabase client or realtime subscription is involved --
// the same technique calendar_screen_test.dart uses. Both screens are
// reached via Navigator.push from a wrapper route (matching how the app
// actually opens them), so their own Navigator.pop calls -- including
// EditItemDialog's delete flow, which pops twice -- land on a real
// underlying route instead of trying to pop a MaterialApp's only route.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart' as ft show testWidgets;
import 'dart:async' show Completer, runZonedGuarded;
import 'dart:convert' show jsonEncode;
import 'dart:io' show File, FileMode;
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;
import 'package:days_together/shared/models/app_settings.dart' show AppSettings, ThemeType;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/timeline/presentation/pages/memory_detail_screen.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/features/timeline/timeline_state.dart';
import 'package:days_together/shared/models/timeline_model.dart';

class _SeededTimeline extends TimelineController {
  _SeededTimeline(this._seed);
  final TimelineState _seed;
  @override
  TimelineState build() => _seed;
}

final _testItem = TimelineItemData(
  id: 'memory-1',
  title: 'Beach Day',
  description: 'We watched the sunset together.',
  location: 'Santa Monica',
  date: DateTime(2024, 6, 15, 18, 30),
  isImageCard: false,
  position: 0,
  mood: '😍',
);

Future<void> _pumpDetail(
  WidgetTester tester, {
  TimelineItemData? item,
  TimelineState timeline = const TimelineState(isLoading: false),
}) async {
  final resolvedItem = item ?? _testItem;
  // The detail screen's hero image + header + description card overflow
  // the default 800x600 test surface -- a real phone screen is taller.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleSessionProvider.overrideWithValue(CoupleSession()),
        timelineControllerProvider.overrideWith(
          () => _SeededTimeline(timeline.copyWith(items: [resolvedItem])),
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemoryDetailScreen(item: resolvedItem),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MemoryDetailScreen', () {
    testWidgets('renders the title, date, mood, location, and description', (
      tester,
    ) async {
      await _pumpDetail(tester);

      expect(find.text('Beach Day'), findsOneWidget);
      expect(find.text('June 15, 2024'), findsOneWidget);
      expect(find.text('Santa Monica'), findsOneWidget);
      expect(find.text('We watched the sunset together.'), findsOneWidget);
      expect(find.text('😍'), findsOneWidget);
    });

    testWidgets('tapping the edit icon opens the pre-filled edit dialog', (
      tester,
    ) async {
      await _pumpDetail(tester);

      await tester.tap(find.byIcon(Icons.edit_note_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Edit Memory'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Beach Day'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Santa Monica'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'We watched the sunset together.'),
        findsOneWidget,
      );
    });

    testWidgets('editing the title and saving updates the detail screen', (
      tester,
    ) async {
      await _pumpDetail(tester);

      await tester.tap(find.byIcon(Icons.edit_note_rounded));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Beach Day'),
        'Beach Day Revisited',
      );
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Edit Memory'), findsNothing);
      expect(find.text('Beach Day Revisited'), findsOneWidget);
    });

    testWidgets('selecting a different mood and saving updates the mood', (
      tester,
    ) async {
      await _pumpDetail(tester);

      await tester.tap(find.byIcon(Icons.edit_note_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('🥳'));
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      expect(find.text('🥳'), findsOneWidget);
    });

    testWidgets(
      'deleting a memory confirms, then closes both the dialog and the detail screen',
      (tester) async {
        await _pumpDetail(tester);

        await tester.tap(find.byIcon(Icons.edit_note_rounded));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Delete Memory'));
        await tester.pumpAndSettle();

        expect(find.text('Delete Memory?'), findsOneWidget);

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Edit Memory'), findsNothing);
        expect(find.text('Beach Day'), findsNothing);
        expect(find.text('Open'), findsOneWidget);
      },
    );
  });
}

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'memory_detail_screen_test.dart';

void testWidgets(
  String description,
  WidgetTesterCallback callback, {
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  TestVariant<Object?> variant = const DefaultTestVariant(),
  dynamic tags,
  int? retry,
}) {
  ft.testWidgets(description, (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'app_settings',
      jsonEncode(
        AppSettings(currentTheme: ThemeType.values.byName(_sweepTheme)).toJson(),
      ),
    );
    await callback(tester);
    final done = Completer<void>();
    runZonedGuarded(() async {
      try {
        await _evaluate(tester, description);
      } finally {
        done.complete();
      }
    }, (e, _) {
      // google_fonts can't download in tests; its failed loads surface
      // during the contrast check's real-async rendering. Anything else is
      // a genuine failure.
      if (!'$e'.contains('Failed to load font')) throw e;
    });
    await done.future;
  }, skip: skip, timeout: timeout, semanticsEnabled: semanticsEnabled, variant: variant, tags: tags);
}

Future<void> _evaluate(WidgetTester tester, String description) async {
    final handle = tester.ensureSemantics();
    await tester.pump();
    for (final g in <String, AccessibilityGuideline>{
      'tap-android': androidTapTargetGuideline,
      'tap-ios': iOSTapTargetGuideline,
      'labeled': labeledTapTargetGuideline,
      'contrast': textContrastGuideline,
    }.entries) {
      Evaluation result;
      try {
        result = await g.value.evaluate(tester);
      } catch (e) {
        result = Evaluation.fail('evaluate threw: $e');
      }
      if (!result.passed) {
        File('build/a11y_sweep.txt').writeAsStringSync(
          '${[_sweepTheme, _sweepFile, description, g.key, (result.reason ?? '').replaceAll('\n', ' | ')].join('\t')}\n',
          mode: FileMode.append,
        );
      }
    }
    handle.dispose();
}
