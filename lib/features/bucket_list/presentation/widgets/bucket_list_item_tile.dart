import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/bucket_list/domain/entities/bucket_list_model.dart';

/// One row in [BucketListScreen]'s reorderable list -- the completion
/// toggle, title/scheduled-date, and edit/delete/drag actions (including
/// the delete confirm dialog). Extracted from the screen's
/// `_buildListItem` (Migration audit item 6).
class BucketListItemTile extends StatelessWidget {
  const BucketListItemTile({
    super.key,
    required this.item,
    required this.theme,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final BucketListItem item;
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
          'Delete Adventure?',
          style: AppTypography.title(color: theme.textColor),
        ),
        content: Text(
          'Are you sure you want to remove this dream from your bucket list?',
          style: AppTypography.body(
            color: theme.textColor.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(
          alpha: item.isCompleted ? 0.02 : 0.05,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.isCompleted
              ? theme.accentColor.withValues(alpha: 0.2)
              : theme.textColor.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: GestureDetector(
          key: ValueKey('bucket-item-toggle-${item.id}'),
          onTap: onToggle,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: item.isCompleted
                    ? theme.accentColor
                    : theme.textColor.withValues(alpha: 0.38),
                width: 2,
              ),
              color: item.isCompleted
                  ? theme.accentColor.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
            child: item.isCompleted
                ? Icon(Icons.favorite, size: 16, color: theme.accentColor)
                : null,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style:
                  AppTypography.body(
                    color: item.isCompleted
                        ? theme.textColor.withValues(alpha: 0.54)
                        : theme.textColor,
                    fontSize: 16,
                    fontWeight: item.isCompleted
                        ? FontWeight.normal
                        : FontWeight.w500,
                  ).copyWith(
                    decoration: item.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
            ),
            if (item.scheduledAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 10,
                      color: theme.accentColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('MMM dd, yyyy').format(item.scheduledAt!)}${item.scheduledAt!.hour != 0 || item.scheduledAt!.minute != 0 ? ' at ${DateFormat.jm().format(item.scheduledAt!)}' : ''}',
                      style: AppTypography.caption(
                        fontSize: 11,
                        color: theme.accentColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
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
            Icon(
              Icons.drag_indicator_rounded,
              color: theme.textColor.withValues(alpha: 0.38),
            ),
          ],
        ),
      ),
    );
  }
}
