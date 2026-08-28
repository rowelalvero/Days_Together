import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/routing/routes.dart';
import 'package:days_together/features/mood/daily_mood_controller.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Bento card for the Daily Sync / Couple Q&A prompt on the dashboard.
class DailySyncBentoCard extends StatelessWidget {
  final LoveStoryTheme theme;

  const DailySyncBentoCard({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final dailyMood = ref.watch(dailyMoodControllerProvider);
        final question = dailyMood.todayQuestion;

        final hasQuestion = question != null;
        final answered = question != null && question.myAnswer != null;
        final partnerAnswered = question != null && question.partnerAnswer != null;

        String statusText = 'Waiting for answers';
        if (answered && partnerAnswered) {
          statusText = 'Ready to read responses';
        } else if (answered) {
          statusText = 'Waiting for partner';
        } else if (partnerAnswered) {
          statusText = 'Partner answered! Unlock now';
        }

        final questionText = question != null
            ? '"${question.question}"'
            : 'Waiting for today\'s relationship prompt...';

        return InkWell(
          onTap: () => context.push(Routes.loveMeter),
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
                        'DAILY SYNC',
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
                          Icons.question_answer_outlined,
                          color: theme.accentColor,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Daily Sync Question',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        questionText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.heading(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: theme.textColor,
                          height: 1.4,
                        ).copyWith(
                          fontStyle: hasQuestion ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 1,
                        color: theme.textColor.withValues(alpha: 0.05),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'SYNC STATUS:',
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
                              color: answered
                                  ? theme.accentColor
                                  : theme.textColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'You',
                            style: AppTypography.caption(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: answered
                                  ? theme.textColor
                                  : theme.textColor.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: partnerAnswered
                                  ? theme.accentColor
                                  : theme.textColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Partner',
                            style: AppTypography.caption(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: partnerAnswered
                                  ? theme.textColor
                                  : theme.textColor.withValues(alpha: 0.4),
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
                        statusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.captionMono(
                          fontSize: 10,
                          color: theme.textColor.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Text(
                          'Sync Minds',
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
