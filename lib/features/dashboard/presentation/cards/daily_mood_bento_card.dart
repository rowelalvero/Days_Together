import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/routing/routes.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/mood/daily_mood_controller.dart';
import 'package:days_together/features/mood/daily_mood_state.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Bento card for the Daily Mood feature on the dashboard.
/// Shows current couple mood status and emoji indicators.
class DailyMoodBentoCard extends StatelessWidget {
  final LoveStoryTheme theme;

  const DailyMoodBentoCard({super.key, required this.theme});

  static String getMoodEmoji(int? score) {
    if (score == null) return '🤔';
    if (score <= 2) return '😢';
    if (score <= 4) return '😐';
    if (score <= 6) return '🙂';
    if (score <= 8) return '😊';
    return '🥰';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final dailyMood = ref.watch(dailyMoodControllerProvider);
        final isPaired = ref.watch(sessionControllerProvider).isPaired;
        final myToday = dailyMood.todayMood;

        String statusText = myToday != null
            ? (isPaired ? 'Synced Mood Logged' : 'Mood Logged')
            : 'Awaiting check-in';

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
                        'DAILY MOOD',
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
                          Icons.emoji_emotions_outlined,
                          color: theme.accentColor,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Daily Mood',
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
                  child: _buildMoodContent(context, isPaired, dailyMood),
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
                          'Share Mood',
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

  Widget _buildMoodContent(
    BuildContext context,
    bool isPaired,
    DailyMoodState dailyMood,
  ) {
    final myToday = dailyMood.todayMood;
    final partnerToday = isPaired ? dailyMood.partnerTodayMood : null;

    final myScore = myToday != null ? '${myToday.moodScore}/10' : 'Pending';
    final myEmoji = myToday != null ? getMoodEmoji(myToday.moodScore) : '🤔';

    Widget buildMoodBox(
      String label,
      String emoji,
      String score,
      bool hasLogged,
    ) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.textColor.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.textColor.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.cardCategory(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: theme.textColor.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  hasLogged
                      ? Icons.check_circle_rounded
                      : Icons.pending_rounded,
                  color: hasLogged
                      ? theme.accentColor
                      : theme.textColor.withValues(alpha: 0.2),
                  size: 13,
                ),
                const SizedBox(width: 6),
                Text(
                  '$emoji $score',
                  style: AppTypography.heading(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (!isPaired) {
      return buildMoodBox('YOU', myEmoji, myScore, myToday != null);
    }

    final partnerScore = partnerToday != null
        ? '${partnerToday.moodScore}/10'
        : 'Pending';
    final partnerEmoji = partnerToday != null
        ? getMoodEmoji(partnerToday.moodScore)
        : '🤔';

    return Row(
      children: [
        Expanded(child: buildMoodBox('YOU', myEmoji, myScore, myToday != null)),
        const SizedBox(width: 12),
        Expanded(
          child: buildMoodBox(
            'PARTNER',
            partnerEmoji,
            partnerScore,
            partnerToday != null,
          ),
        ),
      ],
    );
  }
}
