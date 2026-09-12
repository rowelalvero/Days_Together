import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/gift_reminders/domain/entities/gift_reminder_model.dart';

/// One card in [GiftRemindersScreen]'s list -- title/countdown/next-date,
/// the enabled toggle, and the edit/delete actions (including the delete
/// confirm dialog). Extracted from the screen's `_buildReminderCard`
/// (Migration audit item 6).
class GiftReminderCard extends StatelessWidget {
  const GiftReminderCard({
    super.key,
    required this.reminder,
    required this.theme,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final GiftReminder reminder;
  final LoveStoryTheme theme;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.primaryColor,
        title: Text(
          'Delete Reminder?',
          style: AppTypography.title(color: theme.textColor),
        ),
        content: Text(
          'Are you sure you want to delete this reminder?',
          style: AppTypography.body(
            color: theme.textColor.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTypography.button(
                color: theme.textColor.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: AppTypography.button(color: theme.accentColor),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMMM dd').format(reminder.date);
    final daysLeft = reminder.daysUntil;
    String countdownStr;
    if (daysLeft == 0) {
      countdownStr = '🎉 TODAY!';
    } else if (daysLeft == 1) {
      countdownStr = '⏰ Tomorrow!';
    } else {
      countdownStr = '⏳ $daysLeft days left';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: reminder.isEnabled
              ? theme.textColor.withValues(alpha: 0.1)
              : theme.textColor.withValues(alpha: 0.03),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        (reminder.isEnabled ? Colors.orangeAccent : Colors.grey)
                            .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '🎁',
                    style: AppTypography.body(
                      fontSize: 20,
                      color: reminder.isEnabled
                          ? Colors.white
                          : theme.textColor.withValues(alpha: 0.24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style:
                            AppTypography.body(
                              color: reminder.isEnabled
                                  ? theme.textColor
                                  : theme.textColor.withValues(alpha: 0.38),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ).copyWith(
                              decoration: reminder.isEnabled
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$dateStr${reminder.date.hour != 0 || reminder.date.minute != 0 ? ' at ${DateFormat.jm().format(reminder.date)}' : ''} (Next: ${DateFormat('MMMM dd, yyyy').format(reminder.nextOccurrence)})',
                        style: AppTypography.caption(
                          color: reminder.isEnabled
                              ? theme.textColor.withValues(alpha: 0.6)
                              : theme.textColor.withValues(alpha: 0.24),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: reminder.isEnabled,
                  activeTrackColor: theme.accentColor,
                  onChanged: (_) => onToggle(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: reminder.isEnabled
                        ? (daysLeft <= 14
                                  ? Colors.redAccent
                                  : theme.accentColor)
                              .withValues(alpha: 0.15)
                        : theme.textColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    countdownStr,
                    style: AppTypography.caption(
                      color: reminder.isEnabled
                          ? (daysLeft <= 14
                                ? Colors.redAccent
                                : theme.accentColor)
                          : theme.textColor.withValues(alpha: 0.3),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: theme.textColor.withValues(alpha: 0.38),
                      ),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: theme.textColor.withValues(alpha: 0.38),
                      ),
                      onPressed: () => _confirmDelete(context),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
