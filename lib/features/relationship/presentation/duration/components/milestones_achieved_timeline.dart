import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:days_together/features/relationship/data/relationship_milestones.dart';
import 'package:days_together/services/date_helper.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Vertical timeline displaying all relationship milestones and anniversaries achieved so far.
class MilestonesAchievedTimeline extends StatelessWidget {
  final DateTime startDate;
  final int totalDays;
  final LoveStoryTheme theme;

  const MilestonesAchievedTimeline({
    super.key,
    required this.startDate,
    required this.totalDays,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Filter to completed ones
    final achievedList = relationshipMilestoneCatalog.where((a) {
      if (a.isAnniversary) {
        final date = DateHelper.getAnniversaryDate(startDate, a.annivYear);
        final days = DateHelper.calendarDaysBetween(startDate, date);
        return totalDays >= days;
      }
      return totalDays >= a.targetDays;
    }).toList();

    DateTime getAchievementDate(AchievedMilestone item) {
      if (item.isAnniversary) {
        return DateHelper.getAnniversaryDate(startDate, item.annivYear);
      }
      return startDate.add(Duration(days: item.targetDays));
    }

    if (achievedList.isEmpty) return const SizedBox.shrink();

    // Sort descending (newest achieved first)
    achievedList.sort((a, b) {
      final dateA = getAchievementDate(a);
      final dateB = getAchievementDate(b);
      return dateB.compareTo(dateA);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: theme.accentColor, size: 16),
            const SizedBox(width: 8),
            Text(
              'Milestones Achieved',
              style: AppTypography.title(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: achievedList.length,
          itemBuilder: (context, index) {
            final item = achievedList[index];
            final date = getAchievementDate(item);
            final formattedDate = DateFormat('MMMM dd, yyyy').format(date);
            final isLast = index == achievedList.length - 1;

            return IntrinsicHeight(
              child: Row(
                children: [
                  // Timeline Node
                  Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: theme.accentColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.accentColor.withValues(alpha: 0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.check, color: Colors.white, size: 8),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: theme.textColor.withValues(alpha: 0.15),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Timeline Card
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GlassContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        borderRadius: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: AppTypography.bodyLarge(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: theme.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formattedDate,
                                    style: AppTypography.caption(
                                      fontSize: 10.5,
                                      color: theme.textColor.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.textColor.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.isAnniversary
                                    ? '${item.annivYear} Yr'
                                    : '${item.targetDays}d',
                                style: AppTypography.captionMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textColor.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
