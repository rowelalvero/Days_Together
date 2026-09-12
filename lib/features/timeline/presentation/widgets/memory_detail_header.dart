import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/models/timeline_model.dart';

/// The title, date/time row, mood chip, and (optional) location row at the
/// top of [MemoryDetailScreen]'s body. Extracted from the screen's
/// `build()` (Migration audit item 6).
class MemoryDetailHeader extends StatelessWidget {
  const MemoryDetailHeader({
    super.key,
    required this.item,
    required this.theme,
  });

  final TimelineItemData item;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTypography.display(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: theme.accentColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('MMMM dd, yyyy').format(item.date),
                        style: AppTypography.body(
                          color: theme.textColor.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: theme.accentColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat.jm().format(item.date),
                        style: AppTypography.body(
                          color: theme.textColor.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(item.mood, style: AppTypography.body(fontSize: 28)),
            ),
          ],
        ),
        if (item.location != null && item.location!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 16,
                color: theme.textColor.withValues(alpha: 0.54),
              ),
              const SizedBox(width: 6),
              Text(
                item.location!,
                style: AppTypography.body(
                  color: theme.textColor.withValues(alpha: 0.54),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
