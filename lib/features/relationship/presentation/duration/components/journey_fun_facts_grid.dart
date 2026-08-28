import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:days_together/features/relationship/data/relationship_milestones.dart';
import 'package:days_together/features/relationship/license_details.dart';
import 'package:days_together/features/relationship/workspace_state.dart';
import 'package:days_together/services/date_helper.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// 8-cell responsive grid showcasing relationship fun stats (sunrises, nights, weekends, birthdays, etc.).
class JourneyFunFactsGrid extends StatelessWidget {
  final DateTime startDate;
  final WorkspaceState workspace;
  final LicenseDetails license;
  final LoveStoryTheme theme;

  const JourneyFunFactsGrid({
    super.key,
    required this.startDate,
    required this.workspace,
    required this.license,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    final totalDays = DateHelper.relationshipTotalDays(workspace.startDate);
    final weekends = DateHelper.countWeekendDays(startDate, today);
    final valentines = DateHelper.countOccurrencesOfDate(startDate, today, 2, 14);
    final christmases = DateHelper.countOccurrencesOfDate(startDate, today, 12, 25);
    final newYears = DateHelper.countOccurrencesOfDate(startDate, today, 1, 1);

    int birthdays = 0;
    if (license.yourBirthdate != null) {
      birthdays += DateHelper.countOccurrencesOfDate(
        startDate,
        today,
        license.yourBirthdate!.month,
        license.yourBirthdate!.day,
      );
    }
    if (license.partnerBirthdate != null) {
      birthdays += DateHelper.countOccurrencesOfDate(
        startDate,
        today,
        license.partnerBirthdate!.month,
        license.partnerBirthdate!.day,
      );
    }

    final stats = [
      FunStatItem('🌅', 'Sunrises Together', '$totalDays'),
      FunStatItem('🌙', 'Nights Shared', '$totalDays'),
      FunStatItem('🗓', 'Weekend Days Shared', '$weekends'),
      FunStatItem(
        '📆',
        'Months Shared',
        '${DateHelper.relationshipTotalMonths(workspace.startDate)}',
      ),
      if (birthdays > 0) FunStatItem('🎂', 'Birthdays Celebrated', '$birthdays'),
      FunStatItem('💘', 'Valentine\'s Days', '$valentines'),
      FunStatItem('🎄', 'Christmases Spent', '$christmases'),
      FunStatItem('🎆', 'New Years Together', '$newYears'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: theme.accentColor, size: 16),
            const SizedBox(width: 8),
            Text(
              'Journey Fun Facts',
              style: AppTypography.title(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final item = stats[index];
            final targetValue = int.tryParse(item.value) ?? 0;
            return GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              borderRadius: 16,
              child: Row(
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: targetValue.toDouble()),
                          duration: Duration(milliseconds: 1000 + index * 120),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return Text(
                              NumberFormat('#,###').format(value.toInt()),
                              style: AppTypography.heading(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: theme.textColor,
                              ),
                            );
                          },
                        ),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: theme.textColor.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
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
