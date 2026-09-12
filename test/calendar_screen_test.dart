// Widget tests for CalendarScreen, written before extracting its ~8 _buildX
// methods and its inline `_showEventSheet` into real widget classes -- these
// pin the screen's current rendered behavior so the extraction can be
// verified rather than assumed safe.
//
// Every controller is seeded through a subclass whose build() returns a
// fixed state, so no Supabase client or realtime subscription is involved --
// the same technique daily_mood_bento_card_test.dart uses.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/bucket_list/bucket_list_controller.dart';
import 'package:days_together/features/bucket_list/bucket_list_state.dart';
import 'package:days_together/features/calendar/calendar_controller.dart';
import 'package:days_together/features/calendar/calendar_state.dart';
import 'package:days_together/features/calendar/domain/entities/calendar_event_model.dart';
import 'package:days_together/features/calendar/presentation/pages/calendar_screen.dart';
import 'package:days_together/features/gift_reminders/gift_reminder_controller.dart';
import 'package:days_together/features/gift_reminders/gift_reminder_state.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/relationship/workspace_state.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/features/timeline/timeline_state.dart';

class _SeededCalendar extends CalendarController {
  _SeededCalendar(this._seed);
  final CalendarState _seed;
  @override
  CalendarState build() => _seed;
}

class _SeededWorkspace extends WorkspaceController {
  _SeededWorkspace(this._seed);
  final WorkspaceState _seed;
  @override
  WorkspaceState build() => _seed;
}

class _SeededTimeline extends TimelineController {
  _SeededTimeline(this._seed);
  final TimelineState _seed;
  @override
  TimelineState build() => _seed;
}

class _SeededBucketList extends BucketListController {
  _SeededBucketList(this._seed);
  final BucketListState _seed;
  @override
  BucketListState build() => _seed;
}

class _SeededGiftReminder extends GiftReminderController {
  _SeededGiftReminder(this._seed);
  final GiftReminderState _seed;
  @override
  GiftReminderState build() => _seed;
}

Future<void> _pump(
  WidgetTester tester, {
  CalendarState calendar = const CalendarState(isLoading: false),
  WorkspaceState workspace = const WorkspaceState(),
}) async {
  // The screen's Column (header + month grid + event list) overflows the
  // default 800x600 test surface -- a real phone screen is taller. A larger
  // surface avoids RenderFlex overflow noise unrelated to what these tests
  // check.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleSessionProvider.overrideWithValue(CoupleSession()),
        calendarControllerProvider.overrideWith(
          () => _SeededCalendar(calendar),
        ),
        workspaceControllerProvider.overrideWith(
          () => _SeededWorkspace(workspace),
        ),
        timelineControllerProvider.overrideWith(
          () => _SeededTimeline(const TimelineState(isLoading: false)),
        ),
        bucketListControllerProvider.overrideWith(
          () => _SeededBucketList(const BucketListState(isLoading: false)),
        ),
        giftReminderControllerProvider.overrideWith(
          () => _SeededGiftReminder(const GiftReminderState(isLoading: false)),
        ),
      ],
      child: const MaterialApp(home: CalendarScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CalendarScreen', () {
    testWidgets('renders the month grid, weekday labels, and add button', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.text('No events for this day.'), findsOneWidget);
    });

    testWidgets('an event on the selected day renders as a card', (
      tester,
    ) async {
      final today = DateTime.now();
      final event = CalendarEvent(
        title: 'Dinner date',
        date: DateTime(today.year, today.month, today.day),
        type: CalendarEventType.date,
      );
      await _pump(
        tester,
        calendar: CalendarState(events: [event], isLoading: false),
      );

      expect(find.text('Dinner date'), findsOneWidget);
      expect(find.text('No events for this day.'), findsNothing);
    });

    testWidgets('tapping an event opens the edit sheet pre-filled', (
      tester,
    ) async {
      final today = DateTime.now();
      final event = CalendarEvent(
        title: 'Dinner date',
        date: DateTime(today.year, today.month, today.day),
        type: CalendarEventType.date,
      );
      await _pump(
        tester,
        calendar: CalendarState(events: [event], isLoading: false),
      );

      await tester.tap(find.text('Dinner date'));
      await tester.pumpAndSettle();

      expect(find.text('📝 Edit Event'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Dinner date'),
        findsOneWidget,
        reason: 'the title field must be pre-filled with the tapped event',
      );
    });

    testWidgets('the anniversary appears on the couple\'s start date', (
      tester,
    ) async {
      final today = DateTime.now();
      await _pump(
        tester,
        workspace: WorkspaceState(
          startDate: DateTime(today.year - 2, today.month, today.day),
        ),
      );

      expect(find.text('2 Year Anniversary'), findsOneWidget);
    });

    testWidgets('the add-event sheet accepts a title and adds a new event', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text('✨ New Event'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Event Title (e.g. First Date)'),
        'Anniversary trip',
      );
      await tester.tap(find.text('Add Event'));
      await tester.pumpAndSettle();

      expect(find.text('✨ New Event'), findsNothing);
      expect(find.text('Anniversary trip'), findsOneWidget);
    });
  });
}
