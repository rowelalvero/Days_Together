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
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/love_studio/presentation/pages/ai_love_letter_screen.dart';
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
      expect(find.byType(DropdownButton<String>), findsOneWidget);
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

    testWidgets('selecting a different memory updates the dropdown value', (
      tester,
    ) async {
      await _pump(tester, items: [_memoryOne, _memoryTwo]);

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rainy Movie Night').last);
      await tester.pumpAndSettle();

      expect(find.text('Rainy Movie Night'), findsOneWidget);
    });
  });
}
