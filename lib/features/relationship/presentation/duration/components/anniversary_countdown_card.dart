import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:days_together/services/date_helper.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Bento card showing the countdown in days to the next couple anniversary.
class AnniversaryCountdownCard extends StatelessWidget {
  final DateTime startDate;
  final int currentYears;
  final LoveStoryTheme theme;

  const AnniversaryCountdownCard({
    super.key,
    required this.startDate,
    required this.currentYears,
    required this.theme,
  });

  String _getOrdinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextAnniversaryYear = currentYears + 1;
    final nextAnniversaryDate = DateHelper.getAnniversaryDate(startDate, nextAnniversaryYear);
    final daysUntil = DateHelper.daysUntil(nextAnniversaryDate);
    final label = '${_getOrdinal(nextAnniversaryYear)} Anniversary';

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.favorite_rounded, color: theme.accentColor, size: 24),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT ANNIVERSARY',
                  style: AppTypography.cardCategory(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: AppTypography.title(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMMM dd, yyyy').format(nextAnniversaryDate),
                  style: AppTypography.caption(
                    fontSize: 11,
                    color: theme.textColor.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: daysUntil.toDouble()),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Text(
                    '${value.toInt()}',
                    style: AppTypography.heading(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: theme.textColor,
                    ),
                  );
                },
              ),
              Text(
                'Days left',
                style: AppTypography.caption(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
