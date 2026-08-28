import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/routing/routes.dart';
import 'package:days_together/features/bucket_list/bucket_list_controller.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Bento card for the Bucket List feature on the dashboard.
/// Displays overall goal completion progress and highlights the next goal to conquer.
class BucketListBentoCard extends StatelessWidget {
  final LoveStoryTheme theme;

  const BucketListBentoCard({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final items = ref.watch(bucketListControllerProvider).items;

        final completedItems = items.where((i) => i.isCompleted).toList();
        final uncompletedItems = items.where((i) => !i.isCompleted).toList();

        final total = items.length;
        final completedCount = completedItems.length;
        final progress = total > 0 ? (completedCount / total) : 0.0;

        final closestToConquer = uncompletedItems.isNotEmpty
            ? uncompletedItems.first.title
            : (items.isNotEmpty
                  ? 'All goals achieved! 🎉'
                  : 'No goals added yet');

        String completedText = 'No items yet';
        if (items.isNotEmpty) {
          if (completedItems.isNotEmpty) {
            final title = completedItems.first.title;
            final prefix = 'Completed: $title';
            if (prefix.length > 25) {
              completedText = '${prefix.substring(0, 22)}...';
            } else {
              completedText = prefix;
            }
          } else {
            completedText = 'No completed goals yet';
          }
        }

        return InkWell(
          onTap: () => context.push(Routes.bucketList),
          borderRadius: BorderRadius.circular(24),
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ADVENTURES',
                        style: AppTypography.cardCategory(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: theme.accentColor,
                        ).copyWith(letterSpacing: 0.5),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.accentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.explore_outlined,
                          color: theme.accentColor,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Bucket List Goals',
                  style: AppTypography.title(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.textColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: items.isEmpty
                      ? Container(
                          height: 100,
                          alignment: Alignment.center,
                          child: Text(
                            'Your bucket list is empty. Start planning your next dream adventure together! ✈️',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium(
                              fontSize: 12,
                              color: theme.textColor.withValues(alpha: 0.7),
                              height: 1.4,
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'CONQUER PROGRESS',
                                  style: AppTypography.captionMono(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: theme.textColor.withValues(alpha: 0.35),
                                  ).copyWith(letterSpacing: 0.5),
                                ),
                                Text(
                                  '${(progress * 100).toInt()}% ($completedCount/$total)',
                                  style: AppTypography.bodyMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: theme.accentColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: theme.textColor.withValues(alpha: 0.05),
                                valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              color: theme.textColor.withValues(alpha: 0.05),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'CLOSEST TO CONQUER:',
                              style: AppTypography.captionMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: theme.textColor.withValues(alpha: 0.35),
                              ).copyWith(letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: theme.accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    closestToConquer,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyMedium(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        completedText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.captionMono(
                          fontSize: 10,
                          color: theme.textColor.withValues(alpha: 0.35),
                        ).copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Text(
                          'Chase Objectives',
                          style: AppTypography.button(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: theme.accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9,
                          color: theme.accentColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
