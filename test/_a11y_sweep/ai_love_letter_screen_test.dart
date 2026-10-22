// Widget tests for AILoveLetterScreen, written before extracting its 6
// _buildX methods into real widget classes -- these pin the screen's
// current rendered behavior so the extraction can be verified rather than
// assumed safe.
//
// TimelineController is seeded through a subclass whose build() returns a
// fixed state (the same technique memory_detail_screen_test.dart and
// calendar_screen_test.dart use), so no Supabase client or realtime
// subscription is involved. AIService.generateLoveLetter is a pure local
// mock (a canned quote plus a 2-second Future.delayed, no network) so the
// full generate flow is safe to exercise here, unlike this app's
// auth/notification/recovery screens. The share button is never tapped --
// share_plus's platform channel isn't mocked in this suite.

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
import 'package:days_together/features/love_studio/presentation/pages/ai_love_letter_screen.dart';
import 'package:days_together/features/love_studio/presentation/widgets/memory_picker.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/features/timeline/timeline_state.dart';
import 'package:days_together/shared/models/timeline_model.dart';

class _SeededTimeline extends TimelineController {
  _SeededTimeline(this._seed);
  final TimelineState _seed;
  @override
  TimelineState build() => _seed;
}

final _memoryOne = TimelineItemData(
  id: 'memory-1',
  title: 'Beach Day',
  description: 'We watched the sunset together.',
  date: DateTime(2024, 6, 15),
  isImageCard: false,
  position: 0,
  mood: '😍',
);

final _memoryTwo = TimelineItemData(
  id: 'memory-2',
  title: 'Rainy Movie Night',
  description: 'Stayed in and watched old films.',
  date: DateTime(2024, 7, 2),
  isImageCard: false,
  position: 1,
  mood: '😢',
);

Future<void> _pump(
  WidgetTester tester, {
  required List<TimelineItemData> items,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleSessionProvider.overrideWithValue(CoupleSession()),
        timelineControllerProvider.overrideWith(
          () => _SeededTimeline(TimelineState(items: items, isLoading: false)),
        ),
      ],
      child: const MaterialApp(home: AILoveLetterScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AILoveLetterScreen', () {
    testWidgets('shows the empty state when there are no memories', (
      tester,
    ) async {
      await _pump(tester, items: []);

      expect(find.text('No memories logged yet'), findsOneWidget);
      expect(find.text('Write Love Letter'), findsNothing);
    });

    testWidgets('renders the memory dropdown and generate button', (
      tester,
    ) async {
      await _pump(tester, items: [_memoryOne, _memoryTwo]);

      expect(find.text('Love Letter Writer'), findsOneWidget);
      expect(find.byType(MemoryPicker), findsOneWidget);
      expect(find.text('Beach Day'), findsOneWidget);
      expect(find.text('Write Love Letter'), findsOneWidget);
    });

    testWidgets('generating a letter shows a loading state then the letter', (
      tester,
    ) async {
      await _pump(tester, items: [_memoryOne]);

      await tester.tap(find.text('Write Love Letter'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('✍️ Writing your love story...'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('My Dearest,'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    });

    testWidgets('tapping copy shows the copied-to-clipboard confirmation', (
      tester,
    ) async {
      await _pump(tester, items: [_memoryOne]);

      await tester.tap(find.text('Write Love Letter'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pump();

      expect(find.text('Copied to clipboard!'), findsOneWidget);
    });

    testWidgets(
      'selecting a different memory in the picker sheet updates the choice',
      (tester) async {
        await _pump(tester, items: [_memoryOne, _memoryTwo]);

        await tester.tap(find.byType(MemoryPicker));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Rainy Movie Night').last);
        await tester.pumpAndSettle();

        expect(find.text('Rainy Movie Night'), findsOneWidget);
      },
    );
  });
}

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'ai_love_letter_screen_test.dart';

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
