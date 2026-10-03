import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/bucket_list/bucket_list_controller.dart';
import 'package:days_together/features/calendar/calendar_state.dart';
import 'package:days_together/features/calendar/domain/calendar_date_utils.dart';
import 'package:days_together/features/gift_reminders/gift_reminder_controller.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';

/// The day grid for the focused month, with a dot marking any day that has
/// a calendar event, a timeline memory, a bucket-list goal, a gift
/// reminder, or the couple's anniversary. Extracted from [CalendarScreen]'s
/// `_buildCalendar` (Migration audit item 6).
///
/// A `ConsumerWidget` rather than a plain render of its arguments: the
/// original method reached into four other features' providers directly
/// (`ref.watch` inside the screen's own `_buildCalendar`), and threading all
/// four through this widget's constructor as well as `theme`/`calendar`
/// would trade one god-method for a six-parameter god-widget. Watching them
/// here instead keeps the parameter list to what actually varies across the
/// month (focus, selection).
class CalendarMonthGrid extends ConsumerWidget {
  const CalendarMonthGrid({
    super.key,
    required this.theme,
    required this.calendar,
    required this.focusedMonth,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final LoveStoryTheme theme;
  final CalendarState calendar;
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  static const _weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceControllerProvider);
    final timeline = ref.watch(timelineControllerProvider);
    final bucketList = ref.watch(bucketListControllerProvider);
    final giftReminders = ref.watch(giftReminderControllerProvider);

    final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(
      focusedMonth.year,
      focusedMonth.month + 1,
      0,
    );
    final daysInMonth = lastDayOfMonth.day;
    final firstDayOfWeek = firstDayOfMonth.weekday % 7; // Sunday = 0

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weekDays
                .map(
                  (d) => Text(
                    d,
                    style: AppTypography.caption(
                      color: theme.textColor.withValues(alpha: 0.38),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: ((firstDayOfWeek + daysInMonth) / 7).ceil() * 7,
            itemBuilder: (context, index) {
              final dayNum = index - firstDayOfWeek + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(
                focusedMonth.year,
                focusedMonth.month,
                dayNum,
              );
              final isSelected = isSameCalendarDay(date, selectedDay);
              final isToday = isSameCalendarDay(date, DateTime.now());

              // Event checking
              final calendarEvents = calendar.eventsForDay(date);
              // Covers memories outside the timeline's page window too
              // (CalendarScreen loads the focused month).
              final hasTimeline = timeline.memoriesOn(date).isNotEmpty;
              final hasBucket = bucketList.items.any(
                (i) =>
                    i.scheduledAt != null &&
                    isSameCalendarDay(i.scheduledAt!, date),
              );
              final hasGift = giftReminders.reminders.any(
                (i) => isSameCalendarDay(i.nextOccurrence, date),
              );

              final startDate = workspace.startDate;
              final isAnniversary =
                  startDate != null &&
                  startDate.month == date.month &&
                  startDate.day == date.day;

              final hasAnyEvent =
                  calendarEvents.isNotEmpty ||
                  isAnniversary ||
                  hasTimeline ||
                  hasBucket ||
                  hasGift;

              return GestureDetector(
                onTap: () => onDaySelected(date),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.accentColor
                        : (isToday
                              ? theme.accentColor.withValues(alpha: 0.2)
                              : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    border: isToday && !isSelected
                        ? Border.all(
                            color: theme.accentColor.withValues(alpha: 0.5),
                          )
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: AppTypography.body(
                          color: isSelected
                              ? Colors.white
                              : (isToday
                                    ? theme.accentColor
                                    : theme.textColor.withValues(alpha: 0.7)),
                          fontWeight: (isSelected || isToday)
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (hasAnyEvent && !isSelected)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isAnniversary
                                  ? Colors.pinkAccent
                                  : theme.accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
