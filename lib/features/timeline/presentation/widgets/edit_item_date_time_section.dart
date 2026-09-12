import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The date/time picker row in [EditItemDialog]. Extracted from its
/// `_buildDateTimeSection` (Migration audit item 6) -- [onDateTap]/
/// [onTimeTap] own the actual `showDatePicker`/`showTimePicker` calls and
/// resulting `setState`, matching how the dialog's other extracted pieces
/// keep their state on the dialog's State.
class EditItemDateTimeSection extends StatelessWidget {
  const EditItemDateTimeSection({
    super.key,
    required this.theme,
    required this.selectedDate,
    required this.selectedTime,
    required this.onDateTap,
    required this.onTimeTap,
  });

  final LoveStoryTheme theme;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DATE & TIME',
          style: AppTypography.bodyLarge(
            color: theme.textColor.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ).copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onDateTap,
                child: GlassContainer(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: theme.accentColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM dd, yyyy').format(selectedDate),
                        style: AppTypography.body(
                          color: theme.textColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onTimeTap,
                child: GlassContainer(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: theme.accentColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        selectedTime.format(context),
                        style: AppTypography.body(
                          color: theme.textColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
