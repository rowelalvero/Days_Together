import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:days_together/routing/routes.dart';
import 'package:days_together/features/calendar/calendar_controller.dart';
import 'package:days_together/features/calendar/calendar_state.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Bento card for the Shared Calendar on the dashboard.
/// Displays the next upcoming milestone/event and countdown badge.
class SharedCalendarBentoCard extends StatelessWidget {
  final LoveStoryTheme theme;

  const SharedCalendarBentoCard({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final calendar = ref.watch(calendarControllerProvider);
        final count = calendar.events.length;

        return InkWell(
          onTap: () => context.push(Routes.calendar),
          borderRadius: BorderRadius.circular(24),
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'CALENDAR',
                        style: AppTypography.cardCategory(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: theme.accentColor,
                        ).copyWith(letterSpacing: 0.5),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.accentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.calendar_month_outlined,
                          color: theme.accentColor,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Shared Calendar',
                  style: AppTypography.title(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.textColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildCalendarContent(context, calendar),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$count Events Scheduled',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.captionMono(
                          fontSize: 10,
                          color: theme.textColor.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Text(
                          'View Calendar',
                          style: AppTypography.button(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: theme.accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9,
                          color: theme.accentColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarContent(BuildContext context, CalendarState calendar) {
    final events = calendar.events.toList();
    final now = DateTime.now();
    events.sort((a, b) => a.date.compareTo(b.date));
    final upcoming = events
        .where(
          (e) =>
              e.date.isAfter(now) ||
              (e.date.year == now.year &&
                  e.date.month == now.month &&
                  e.date.day == now.day),
        )
        .toList();

    if (upcoming.isEmpty) {
      return Text(
        'No upcoming dates or anniversaries. Plan a romantic day together! 📅',
        style: AppTypography.bodyMedium(
          fontSize: 12,
          color: theme.textColor.withValues(alpha: 0.7),
          height: 1.4,
        ),
      );
    }

    final event = upcoming.first;
    final formattedDate = DateFormat('MMM dd, yyyy').format(event.date);

    final eventDateOnly = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
    );
    final nowDateOnly = DateTime(now.year, now.month, now.day);
    final daysUntil = eventDateOnly.difference(nowDateOnly).inDays;

    String daysText = daysUntil == 0 ? 'Today' : 'In $daysUntil Days';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.heading(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.accentColor,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SOON',
                    style: AppTypography.bodyMono(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ).copyWith(letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formattedDate,
              style: AppTypography.bodyMono(
                fontSize: 11,
                color: theme.textColor.withValues(alpha: 0.35),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              daysText,
              style: AppTypography.bodyMono(
                fontSize: 11.5,
                color: theme.accentColor,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}
