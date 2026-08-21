// Tests for CalendarController (Phase 6a of the architecture migration, the
// third of the 12 domain providers ported to Riverpod). No network:
// coupleSessionProvider is overridden with an unpaired CoupleSession()
// throughout (coupleId == null), matching bucket_list_controller_test.dart's
// convention -- these tests exercise the local-only write path.

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/calendar/calendar_controller.dart';
import 'package:days_together/models/calendar_event_model.dart';
import 'package:days_together/providers/couple_session.dart';

/// calendarControllerProvider is `autoDispose` -- see
/// bucket_list_controller_test.dart's identical helper doc comment for why
/// a persistent `container.listen` is required, not just `container.read`.
ProviderContainer _unpairedContainer() {
  final container = ProviderContainer(
    overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
  );
  container.listen(calendarControllerProvider, (prev, next) {});
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CalendarController', () {
    test('build() starts empty when there is no cached data', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(calendarControllerProvider);
      expect(state.events, isEmpty);
      expect(state.isLoading, false);
    });

    test('addEvent appends locally and persists when unpaired', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      await container.read(calendarControllerProvider.notifier).addEvent(
            CalendarEvent(title: 'Dinner date', date: DateTime(2026, 10, 10), type: CalendarEventType.date),
          );

      final state = container.read(calendarControllerProvider);
      expect(state.events, hasLength(1));
      expect(state.events.first.title, 'Dinner date');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('calendar_events'), contains('Dinner date'));
    });

    test('updateEvent replaces the event locally when unpaired', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(calendarControllerProvider.notifier);

      final event = CalendarEvent(title: 'Old', date: DateTime(2026, 1, 1));
      await notifier.addEvent(event);

      await notifier.updateEvent(event.copyWith(title: 'New'));

      final state = container.read(calendarControllerProvider);
      expect(state.events, hasLength(1));
      expect(state.events.first.title, 'New');
    });

    test('deleteEvent removes locally when unpaired', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(calendarControllerProvider.notifier);

      final event = CalendarEvent(title: 'Trip', date: DateTime(2026, 6, 6));
      await notifier.addEvent(event);

      await notifier.deleteEvent(event.id);

      expect(container.read(calendarControllerProvider).events, isEmpty);
    });

    test('eventsForDay matches non-recurring events by exact date', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(calendarControllerProvider.notifier);

      await notifier.addEvent(CalendarEvent(title: 'Today', date: DateTime(2026, 7, 4)));
      await notifier.addEvent(CalendarEvent(title: 'Another day', date: DateTime(2026, 7, 5)));

      final matches = container.read(calendarControllerProvider).eventsForDay(DateTime(2026, 7, 4));
      expect(matches, hasLength(1));
      expect(matches.first.title, 'Today');
    });

    test('eventsForDay matches recurring-yearly events by month/day regardless of year', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(calendarControllerProvider.notifier);

      await notifier.addEvent(
        CalendarEvent(
          title: 'Anniversary',
          date: DateTime(2020, 3, 15),
          type: CalendarEventType.anniversary,
          isRecurringYearly: true,
        ),
      );

      final matches = container.read(calendarControllerProvider).eventsForDay(DateTime(2026, 3, 15));
      expect(matches, hasLength(1));
      expect(matches.first.title, 'Anniversary');
    });

    test('purgeCache clears events and the SharedPreferences cache', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(calendarControllerProvider.notifier);
      await notifier.addEvent(CalendarEvent(title: 'Something', date: DateTime(2026, 8, 8)));

      await notifier.purgeCache();

      final state = container.read(calendarControllerProvider);
      expect(state.events, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('calendar_events'), isFalse);
    });
  });
}
