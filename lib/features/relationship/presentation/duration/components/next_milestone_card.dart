import 'package:flutter/material.dart';
import 'package:days_together/features/relationship/workspace_state.dart';
import 'package:days_together/services/date_helper.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Bento card tracking progress toward the next major relationship milestone and listing upcoming ones.
class NextMilestoneCard extends StatelessWidget {
  final WorkspaceState workspace;
  final LoveStoryTheme theme;

  const NextMilestoneCard({
    super.key,
    required this.workspace,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final milestones = DateHelper.nextRelationshipMilestones(workspace.startDate, workspace.startTime);
    if (milestones.isEmpty) return const SizedBox.shrink();

    final next = milestones.first;
    // Extract target days from title
    int target = 100;
    final numMatch = RegExp(r'\d+').firstMatch(next.title);
    if (numMatch != null) {
      target = int.tryParse(numMatch.group(0)!) ?? 100;
    }

    final currentDays = DateHelper.relationshipTotalDays(workspace.startDate);
    final progress = next.progress;
    final percent = (progress * 100).round();

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEXT MILESTONE',
                    style: AppTypography.cardCategory(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: theme.accentColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    next.title,
                    style: AppTypography.title(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.textColor,
                    ),
                  ),
                ],
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: percent.toDouble()),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${value.toInt()}%',
                      style: AppTypography.captionMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.accentColor,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: theme.textColor.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$currentDays / $target Days',
                style: AppTypography.caption(
                  fontSize: 11,
                  color: theme.textColor.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${next.daysUntil} days remaining',
                style: AppTypography.caption(
                  fontSize: 11,
                  color: theme.accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          // List remaining 4 milestones
          if (milestones.length > 1) ...[
            const Divider(height: 24, thickness: 0.5),
            Text(
              'Upcoming Milestones',
              style: AppTypography.captionMono(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: theme.textColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 10),
            Column(
              children: List.generate(milestones.length - 1, (index) {
                final milestone = milestones[index + 1];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.star_border_rounded,
                            size: 14,
                            color: theme.textColor.withValues(alpha: 0.35),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            milestone.title,
                            style: AppTypography.bodyMedium(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: theme.textColor.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'in ${milestone.daysUntil} days',
                        style: AppTypography.caption(
                          fontSize: 11,
                          color: theme.textColor.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
