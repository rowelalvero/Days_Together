import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:days_together/app/router/route_names.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/bucket_list/bucket_list_controller.dart';
import 'package:days_together/features/calendar/calendar_state.dart';
import 'package:days_together/features/calendar/domain/calendar_date_utils.dart';
import 'package:days_together/features/calendar/domain/entities/calendar_event_model.dart';
import 'package:days_together/features/calendar/presentation/widgets/calendar_anniversary_card.dart';
import 'package:days_together/features/calendar/presentation/widgets/calendar_event_card.dart';
import 'package:days_together/features/calendar/presentation/widgets/calendar_integrated_card.dart';
import 'package:days_together/features/gift_reminders/gift_reminder_controller.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';

/// Everything on the selected day: the date heading, the couple's
/// anniversary card if applicable, calendar events, and anything from
/// another feature (timeline memories, bucket-list goals, gift reminders)
/// scheduled for the same day. Extracted from [CalendarScreen]'s
/// `_buildEventList` (Migration audit item 6) -- a `ConsumerWidget` for the
/// same reason [CalendarMonthGrid] is: the original reached into four other
/// features' providers directly rather than receiving them as parameters.
class CalendarDayEventList extends ConsumerWidget {
  const CalendarDayEventList({
    super.key,
    required this.theme,
    required this.calendar,
    required this.selectedDay,
    required this.onEditEvent,
  });

  final LoveStoryTheme theme;
  final CalendarState calendar;
  final DateTime selectedDay;
  final ValueChanged<CalendarEvent> onEditEvent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceControllerProvider);
    final timeline = ref.watch(timelineControllerProvider);
    final bucketList = ref.watch(bucketListControllerProvider);
    final giftReminders = ref.watch(giftReminderControllerProvider);

    final events = calendar.eventsForDay(selectedDay);

    // Check for other types
    final timelineItems = timeline.items
        .where((i) => isSameCalendarDay(i.date, selectedDay))
        .toList();
    final bucketItems = bucketList.items
        .where(
          (i) =>
              i.scheduledAt != null &&
              isSameCalendarDay(i.scheduledAt!, selectedDay),
        )
        .toList();
    final giftItems = giftReminders.reminders
        .where((i) => isSameCalendarDay(i.nextOccurrence, selectedDay))
        .toList();

    // Check for anniversary
    final startDate = workspace.startDate;
    final isAnniversary =
        startDate != null &&
        startDate.month == selectedDay.month &&
        startDate.day == selectedDay.day;

    final hasAny =
        events.isNotEmpty ||
        isAnniversary ||
        timelineItems.isNotEmpty ||
        bucketItems.isNotEmpty ||
        giftItems.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMMM dd, yyyy').format(selectedDay),
            style: AppTypography.heading(
              color: theme.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          if (!hasAny)
            Expanded(
              child: Center(
                child: Text(
                  'No events for this day.',
                  style: AppTypography.body(
                    color: theme.textColor.withValues(alpha: 0.3),
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  if (isAnniversary)
                    CalendarAnniversaryCard(
                      theme: theme,
                      years: selectedDay.year - startDate.year,
                    ),
                  ...events.map(
                    (event) => CalendarEventCard(
                      event: event,
                      theme: theme,
                      onTap: () => onEditEvent(event),
                    ),
                  ),
                  ...timelineItems.map(
                    (item) => CalendarIntegratedCard(
                      title: item.title,
                      subtitle:
                          'Story Entry • ${DateFormat.jm().format(item.date)}${item.location != null ? ' • ${item.location}' : ''}',
                      emoji: '📖',
                      color: Colors.blueAccent,
                      // Was Navigator.push(... LoveStoryScreen()) -- pushed a
                      // second, redundant instance of the app's own shell on
                      // top of the stack, since CalendarScreen is already
                      // reached from inside it (ADR-007's confirmed duplicate-
                      // shell finding). context.go returns to the existing
                      // shell instead of stacking a new one.
                      onTap: () => context.go(Routes.home),
                    ),
                  ),
                  ...bucketItems.map(
                    (item) => CalendarIntegratedCard(
                      title: item.title,
                      subtitle:
                          'Bucket List Goal${item.scheduledAt!.hour != 0 || item.scheduledAt!.minute != 0 ? ' • ${DateFormat.jm().format(item.scheduledAt!)}' : ''}',
                      emoji: '✅',
                      color: Colors.greenAccent,
                      onTap: () => context.push(Routes.bucketList),
                    ),
                  ),
                  ...giftItems.map(
                    (item) => CalendarIntegratedCard(
                      title: item.title,
                      subtitle:
                          'Gift Reminder${item.date.hour != 0 || item.date.minute != 0 ? ' • ${DateFormat.jm().format(item.date)}' : ''}',
                      emoji: '🎁',
                      color: Colors.orangeAccent,
                      onTap: () => context.push(Routes.gifts),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
