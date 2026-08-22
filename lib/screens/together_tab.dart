import 'package:days_together/themes/theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/features/bucket_list/bucket_list_controller.dart';
import 'package:days_together/features/mood/daily_mood_controller.dart';
import 'package:days_together/routing/routes.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:provider/provider.dart';
import 'package:days_together/themes/app_typography.dart';

class TogetherTab extends ConsumerWidget {
  const TogetherTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final bucketList = ref.watch(bucketListControllerProvider);
    final dailyMood = ref.watch(dailyMoodControllerProvider);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Together',
              style: AppTypography.display(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            Text(
              'Every moment shared is a memory.',
              style: AppTypography.body(
                fontSize: 14,
                color: theme.textColor.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 35),
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.only(bottom: 120),
                crossAxisCount: 2,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
                childAspectRatio: 0.85,
                children: [
                  _buildFeatureCard(
                    context: context,
                    theme: theme,
                    emoji: '🔒',
                    title: 'The Vault',
                    subtitle: 'Private memories.',
                    color: theme.accentColor,
                    onTap: () => context.push(Routes.vault),
                  ),
                  _buildFeatureCard(
                    context: context,
                    theme: theme,
                    emoji: '✅',
                    title: 'Bucket List',
                    subtitle:
                        '${bucketList.completedItems}/${bucketList.totalItems} done',
                    color: Colors.lightBlue,
                    onTap: () => context.push(Routes.bucketList),
                  ),
                  _buildFeatureCard(
                    context: context,
                    theme: theme,
                    emoji: '📈',
                    title: 'Love Meter',
                    subtitle: dailyMood.hasLoggedToday
                        ? 'Today: ${dailyMood.todayMood?.moodScore}/10'
                        : 'How are we today?',
                    color: Colors.pink,
                    onTap: () => context.push(Routes.loveMeter),
                  ),
                  _buildFeatureCard(
                    context: context,
                    theme: theme,
                    emoji: '🎁',
                    title: 'Gift Ideas',
                    subtitle: 'Never forget a date.',
                    color: Colors.orange,
                    onTap: () => context.push(Routes.gifts),
                  ),
                  _buildFeatureCard(
                    context: context,
                    theme: theme,
                    emoji: '📅',
                    title: 'Calendar',
                    subtitle: 'Our important dates.',
                    color: Colors.teal,
                    onTap: () => context.push(Routes.calendar),
                  ),
                  _buildFeatureCard(
                    context: context,
                    theme: theme,
                    emoji: '💌',
                    title: 'Love License',
                    subtitle: 'Our official bond.',
                    color: const Color(0xFFD4AF37),
                    onTap: () => context.push(Routes.license),
                  ),
                  _buildFeatureCard(
                    context: context,
                    theme: theme,
                    emoji: '🃏',
                    title: 'Topic Cards',
                    subtitle: 'Deep questions for couples.',
                    color: Colors.purple,
                    onTap: () => context.push(Routes.topicCards),
                  ),
                  _buildFeatureCard(
                    context: context,
                    theme: theme,
                    emoji: '📱',
                    title: 'Scrapbook',
                    subtitle: 'Doodle, write notes & pin photos.',
                    color: Colors.pink,
                    onTap: () => context.push(Routes.notes),
                  ),
                  _buildFeatureCard(
                    context: context,
                    theme: theme,
                    emoji: '💬',
                    title: 'Love Chat',
                    subtitle: 'Connected messaging.',
                    color: theme.accentColor,
                    onTap: () => context.push(Routes.chat),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required LoveStoryTheme theme,
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 28,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(emoji, style: AppTypography.body(fontSize: 24)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.title(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.caption(
                    color: theme.textColor.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
