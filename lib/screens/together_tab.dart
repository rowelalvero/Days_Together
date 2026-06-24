import 'package:flutter/material.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/bucket_list_provider.dart';
import 'package:days_together/providers/daily_mood_provider.dart';
import 'package:days_together/screens/together/vault_screen.dart';
import 'package:days_together/screens/together/bucket_list_screen.dart';
import 'package:days_together/screens/together/love_meter_screen.dart';
import 'package:days_together/screens/together/gift_reminders_screen.dart';
import 'package:days_together/screens/together/calendar_screen.dart';
import 'package:days_together/screens/together/relationship_license_screen.dart';
import 'package:days_together/screens/together/topic_cards_screen.dart';
import 'package:days_together/screens/together/noteit_screen.dart';
import 'package:days_together/screens/together/love_chat_screen.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:provider/provider.dart';
import 'package:days_together/themes/app_typography.dart';

class TogetherTab extends StatelessWidget {
  const TogetherTab({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final bucketList = context.watch<BucketListProvider>();
    final dailyMood = context.watch<DailyMoodProvider>();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Together',
              style: AppTypography.pageTitle(
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
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VaultScreen()),
                    ),
                  ),
                  _buildFeatureCard(
                    context: context,
                    theme: theme,
                    emoji: '✅',
                    title: 'Bucket List',
                    subtitle:
                        '${bucketList.completedItems}/${bucketList.totalItems} done',
                    color: Colors.lightBlueAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BucketListScreen(),
                      ),
                    ),
                  ),
                  _buildFeatureCard(
                    context: context,
                    theme: theme,
                    emoji: '📈',
                    title: 'Love Meter',
                    subtitle: dailyMood.hasLoggedToday
                        ? 'Today: ${dailyMood.todayMood?.moodScore}/10'
                        : 'How are we today?',
                    color: Colors.pinkAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoveMeterScreen(),
                      ),
                    ),
                  ),
                  _buildFeatureCard(
                    context: context,
                    theme: theme,
                    emoji: '🎁',
                    title: 'Gift Ideas',
                    subtitle: 'Never forget a date.',
                    color: Colors.orangeAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GiftRemindersScreen(),
                      ),
                    ),
                  ),
                  _buildFeatureCard(
                    context: context,
                    theme: theme,
                    emoji: '📅',
                    title: 'Calendar',
                    subtitle: 'Our important dates.',
                    color: Colors.tealAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CalendarScreen()),
                    ),
                  ),
                  _buildFeatureCard(
                    context: context,
                    theme: theme,
                    emoji: '💌',
                    title: 'Love License',
                    subtitle: 'Our official bond.',
                    color: const Color(0xFFD4AF37),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RelationshipLicenseScreen(),
                      ),
                    ),
                  ),
                  _buildFeatureCard(
                    context: context,
                    theme: theme,
                    emoji: '🃏',
                    title: 'Topic Cards',
                    subtitle: 'Deep questions for couples.',
                    color: Colors.purpleAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TopicCardsScreen(),
                      ),
                    ),
                  ),
                  _buildFeatureCard(
                    context: context,
                    theme: theme,
                    emoji: '📱',
                    title: 'Doodle Notes',
                    subtitle: 'Doodle & send widget notes.',
                    color: Colors.pinkAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NoteitScreen(),
                      ),
                    ),
                  ),
                  _buildFeatureCard(
                    context: context,
                    theme: theme,
                    emoji: '💬',
                    title: 'Love Chat',
                    subtitle: 'Connected messaging.',
                    color: Colors.pinkAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoveChatScreen(),
                      ),
                    ),
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
    required dynamic theme,
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
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.cardTitle(
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
