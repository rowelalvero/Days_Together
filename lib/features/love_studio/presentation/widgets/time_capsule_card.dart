import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/love_studio/domain/entities/time_capsule_model.dart';

/// One card in [TimeCapsuleScreen]'s ready/sealed/opened sections --
/// status icon, message or "Time Capsule" placeholder, unlock/opened date,
/// and the open/delete actions (including the delete confirm dialog).
/// Extracted from the screen's `_buildCapsuleCard` (Migration audit item
/// 6).
class TimeCapsuleCard extends StatelessWidget {
  const TimeCapsuleCard({
    super.key,
    required this.capsule,
    required this.theme,
    required this.isOpenable,
    required this.onOpen,
    required this.onDelete,
  });

  final TimeCapsule capsule;
  final LoveStoryTheme theme;
  final bool isOpenable;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.primaryColor,
        title: Text(
          'Delete Time Capsule?',
          style: AppTypography.title(color: theme.textColor),
        ),
        content: Text(
          'Are you sure you want to delete this time capsule? Its contents will be permanently lost.',
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
    final formattedOpenDate = DateFormat(
      'MMMM dd, yyyy',
    ).format(capsule.openDate);
    final daysLeft = capsule.openDate.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOpenable
              ? Colors.green.withValues(alpha: 0.3)
              : theme.textColor.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                (capsule.isOpened
                        ? Colors.pinkAccent
                        : (isOpenable ? Colors.green : Colors.grey))
                    .withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            capsule.isOpened
                ? Icons.drafts_rounded
                : (isOpenable ? Icons.lock_open_rounded : Icons.lock_rounded),
            color: capsule.isOpened
                ? Colors.pinkAccent
                : (isOpenable
                      ? Colors.green
                      : theme.textColor.withValues(alpha: 0.6)),
            size: 20,
          ),
        ),
        title: Text(
          capsule.isOpened ? capsule.message : 'Time Capsule',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: capsule.isOpened
              ? AppTypography.lora(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                )
              : AppTypography.body(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            capsule.isOpened
                ? 'Opened: $formattedOpenDate'
                : (isOpenable
                      ? 'Ready to open now!'
                      : 'Unlocks: $formattedOpenDate ($daysLeft days)'),
            style: AppTypography.bodyMedium(
              color: isOpenable
                  ? Colors.green
                  : theme.textColor.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOpenable || capsule.isOpened)
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: theme.textColor.withValues(alpha: 0.7),
                  size: 16,
                ),
                onPressed: onOpen,
              )
            else
              Icon(
                Icons.timer_outlined,
                color: theme.textColor.withValues(alpha: 0.38),
                size: 18,
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
      ),
    );
  }
}
