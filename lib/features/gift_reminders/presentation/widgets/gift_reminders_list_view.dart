import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/gift_reminders/domain/entities/gift_reminder_model.dart';
import 'package:days_together/features/gift_reminders/gift_reminder_controller.dart';
import 'package:days_together/features/gift_reminders/gift_reminder_state.dart';
import 'package:days_together/features/gift_reminders/presentation/widgets/gift_reminder_card.dart';

/// The list of reminder cards on [GiftRemindersScreen], soonest first.
/// Extracted from its `_buildListView` (Migration audit item 6).
class GiftRemindersListView extends StatelessWidget {
  const GiftRemindersListView({
    super.key,
    required this.state,
    required this.notifier,
    required this.theme,
    required this.onEditReminder,
  });

  final GiftReminderState state;
  final GiftReminderController notifier;
  final LoveStoryTheme theme;
  final ValueChanged<GiftReminder> onEditReminder;

  @override
  Widget build(BuildContext context) {
    final sortedList = state.upcomingReminders;
    return ListView.builder(
      itemCount: sortedList.length,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
      itemBuilder: (context, index) {
        final reminder = sortedList[index];
        return GiftReminderCard(
          reminder: reminder,
          theme: theme,
          onToggle: () => notifier.toggleReminder(reminder.id),
          onEdit: () => onEditReminder(reminder),
          onDelete: () => notifier.deleteReminder(reminder.id),
        );
      },
    );
  }
}
