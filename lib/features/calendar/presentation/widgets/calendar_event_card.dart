import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/calendar/domain/entities/calendar_event_model.dart';

/// The day-detail row for a user-created calendar event -- tapping it opens
/// the edit sheet. Extracted from [CalendarScreen]'s `_buildEventCard`
/// (Migration audit item 6), along with the type->color/emoji mappings that
/// method's siblings `_getEventColor`/`_getEventEmoji` provided.
class CalendarEventCard extends StatelessWidget {
  const CalendarEventCard({
    super.key,
    required this.event,
    required this.theme,
    required this.onTap,
  });

  final CalendarEvent event;
  final LoveStoryTheme theme;
  final VoidCallback onTap;

  static Color colorFor(CalendarEventType type, LoveStoryTheme theme) {
    switch (type) {
      case CalendarEventType.anniversary:
        return Colors.pinkAccent;
      case CalendarEventType.birthday:
        return Colors.orangeAccent;
      case CalendarEventType.date:
        return Colors.redAccent;
      case CalendarEventType.travel:
        return Colors.lightBlueAccent;
      case CalendarEventType.other:
        return theme.accentColor;
    }
  }

  static String emojiFor(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.anniversary:
        return '💑';
      case CalendarEventType.birthday:
        return '🎂';
      case CalendarEventType.date:
        return '🌹';
      case CalendarEventType.travel:
        return '✈️';
      case CalendarEventType.other:
        return '✨';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorFor(event.type, theme).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                emojiFor(event.type),
                style: AppTypography.body(fontSize: 18),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTypography.body(
                      color: theme.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (event.description?.isNotEmpty ?? false)
                    Text(
                      event.description!,
                      style: AppTypography.caption(
                        color: theme.textColor.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (event.time != null)
              Text(
                event.time!.format(context),
                style: AppTypography.caption(
                  color: theme.accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
