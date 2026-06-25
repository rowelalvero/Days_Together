import 'package:flutter/material.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/screens/studio/ai_love_letter_screen.dart';
import 'package:days_together/screens/studio/time_capsule_screen.dart';
import 'package:days_together/screens/studio/relationship_insights_screen.dart';

class StudioTab extends StatelessWidget {
  const StudioTab({super.key});

  void _showPremiumPaywall(BuildContext context, dynamic theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: theme.primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.textColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '✨ Love Studio Premium',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Unlock the full magic of AI and digital connection.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 14),
              ),
              const SizedBox(height: 24),
              _buildFeatureBullet(
                Icons.edit_note_rounded,
                'AI Love Letter Generator',
                'Create poetic love letters from your timeline memories.',
                theme,
              ),
              _buildFeatureBullet(
                Icons.insights_rounded,
                'Deep Relationship Insights',
                'Get fun stats, relationship analysis & compatibility scores.',
                theme,
              ),
              _buildFeatureBullet(
                Icons.alarm_on_rounded,
                'Unlimited Future Time Capsules',
                'Write to your future selves with no date restrictions.',
                theme,
              ),
              _buildFeatureBullet(
                Icons.palette_rounded,
                'Exclusive App Themes',
                'Access premium romantic and celestial color palettes.',
                theme,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    context.read<RelationshipProvider>().setPremium(true);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✨ Welcome to Love Studio Premium!'),
                        backgroundColor: Colors.pinkAccent,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Unlock Premium — \$0.00 (Free Test)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This is a local demo. Toggling is completely free.',
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.3),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureBullet(IconData icon, String title, String desc, dynamic theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.amber, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final rp = context.watch<RelationshipProvider>();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Love Studio',
              style: AppTypography.cormorant(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            Row(
              children: [
                Text(
                  'Powered by AI',
                  style: AppTypography.spectral(
                    fontSize: 16,
                    color: theme.textColor.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
              ],
            ),
            const SizedBox(height: 24),
            if (!rp.isPremium) _buildPremiumBanner(context, theme),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 120),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildStudioCard(
                    context: context,
                    icon: Icons.edit_note_rounded,
                    title: 'AI Love Letter Generator',
                    desc:
                        'Select a memory and let AI draft a gorgeous love letter for your partner.',
                    isPremium: true,
                    isUnlocked: rp.isPremium,
                    theme: theme,
                    onTap: () {
                      if (rp.isPremium) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AILoveLetterScreen(),
                          ),
                        );
                      } else {
                        _showPremiumPaywall(context, theme);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildStudioCard(
                    context: context,
                    icon: Icons.alarm_rounded,
                    title: 'Future Time Capsule',
                    desc:
                        'Write letters to be locked away. Pick a date to unlock them in the future.',
                    isPremium: false,
                    isUnlocked: true,
                    theme: theme,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TimeCapsuleScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildStudioCard(
                    context: context,
                    icon: Icons.query_stats_rounded,
                    title: 'Relationship Insights',
                    desc:
                        'Fun statistics, shared milestones, and emotional dashboard charts.',
                    isPremium: true,
                    isUnlocked: rp.isPremium,
                    theme: theme,
                    onTap: () {
                      if (rp.isPremium) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RelationshipInsightsScreen(),
                          ),
                        );
                      } else {
                        _showPremiumPaywall(context, theme);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBanner(BuildContext context, dynamic theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.15),
            theme.accentColor.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(
                'Unlock Love Studio Premium',
                style: AppTypography.body(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Get access to the Love Letter Generator, deep Insights, and custom app styles.',
            style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.7), fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showPremiumPaywall(context, theme),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Upgrade Now',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudioCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String desc,
    required bool isPremium,
    required bool isUnlocked,
    required dynamic theme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isPremium && !isUnlocked
                ? Colors.amber.withValues(alpha: 0.2)
                : theme.textColor.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    (isPremium && !isUnlocked
                            ? Colors.amber
                            : theme.accentColor)
                        .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isPremium && !isUnlocked
                    ? Colors.amber
                    : theme.accentColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: AppTypography.body(
                          color: theme.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (isPremium) ...[
                        const SizedBox(width: 8),
                        Icon(
                          isUnlocked
                              ? Icons.star_rounded
                              : Icons.lock_outline_rounded,
                          color: isUnlocked ? Colors.amber : theme.textColor.withValues(alpha: 0.54),
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: AppTypography.bodyMedium(
                      color: theme.textColor.withValues(alpha: 0.5),
                      fontSize: 12,
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
}
