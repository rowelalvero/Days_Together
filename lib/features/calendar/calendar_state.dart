import 'package:days_together/models/calendar_event_model.dart';

/// State for `CalendarController` (Phase 6a of the architecture migration)
/// -- a direct Riverpod port of `CalendarProvider`'s `_events`/`_isLoading`
/// fields.
class CalendarState {
  final List<CalendarEvent> events;
  final bool isLoading;

  const CalendarState({this.events = const [], this.isLoading = true});

  CalendarState copyWith({List<CalendarEvent>? events, bool? isLoading}) {
    return CalendarState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<CalendarEvent> eventsForDay(DateTime day) {
    return events.where((event) {
      if (event.isRecurringYearly) {
        return event.date.month == day.month && event.date.day == day.day;
      }
      return event.date.year == day.year && event.date.month == day.month && event.date.day == day.day;
    }).toList();
  }
}
