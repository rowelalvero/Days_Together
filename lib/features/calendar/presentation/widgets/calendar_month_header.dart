import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The "< Month Year >" header at the top of [CalendarScreen] -- a back
/// button, the focused month/year, and previous/next month navigation.
/// Extracted from that screen's `_buildHeader` (Migration audit item 6).
///
/// Purely a render of its arguments: [focusedMonth] is owned by the screen
/// (it is the only reason to navigate months), so this widget only forwards
/// taps back up via [onPreviousMonth]/[onNextMonth].
class CalendarMonthHeader extends StatelessWidget {
  const CalendarMonthHeader({
    super.key,
    required this.theme,
    required this.focusedMonth,
    required this.onBack,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final LoveStoryTheme theme;
  final DateTime focusedMonth;
  final VoidCallback onBack;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: theme.textColor,
            ),
            onPressed: onBack,
          ),
          Text(
            DateFormat('MMMM yyyy').format(focusedMonth),
            style: AppTypography.display(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: theme.textColor),
                onPressed: onPreviousMonth,
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: theme.textColor),
                onPressed: onNextMonth,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
