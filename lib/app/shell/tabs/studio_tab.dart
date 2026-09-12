import 'package:days_together/app/theme/theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/shell/sheets/premium_paywall_sheet.dart';
import 'package:days_together/app/shell/widgets/premium_banner.dart';
import 'package:days_together/app/shell/widgets/studio_card.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/app/router/route_names.dart';

/// The "Studio" tab: AI-powered feature list plus the local premium
/// paywall.
///
/// Its `_buildX` methods and inline `_showPremiumPaywall` bottom sheet
/// were extracted into focused widgets under `app/shell/widgets/` and
/// `app/shell/sheets/` (Migration audit item 6).
class StudioTab extends ConsumerWidget {
  const StudioTab({super.key});

  void _showPremiumPaywall(
    BuildContext context,
    WidgetRef ref,
    LoveStoryTheme theme,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => PremiumPaywallSheet(
        theme: theme,
        onUnlock: () =>
            ref.read(workspaceControllerProvider.notifier).setPremium(true),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;
    final isPremium = ref.watch(workspaceControllerProvider).isPremium;

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
            if (!isPremium)
              PremiumBanner(
                theme: theme,
                onUpgrade: () => _showPremiumPaywall(context, ref, theme),
              ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 120),
                physics: const BouncingScrollPhysics(),
                children: [
                  StudioCard(
                    icon: Icons.edit_note_rounded,
                    title: 'AI Love Letter Generator',
                    desc:
                        'Select a memory and let AI draft a gorgeous love letter for your partner.',
                    isPremium: true,
                    isUnlocked: isPremium,
                    theme: theme,
                    onTap: () {
                      if (isPremium) {
                        context.push(Routes.studioLoveLetter);
                      } else {
                        _showPremiumPaywall(context, ref, theme);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  StudioCard(
                    icon: Icons.alarm_rounded,
                    title: 'Future Time Capsule',
                    desc:
                        'Write letters to be locked away. Pick a date to unlock them in the future.',
                    isPremium: false,
                    isUnlocked: true,
                    theme: theme,
                    onTap: () {
                      context.push(Routes.timeCapsule);
                    },
                  ),
                  const SizedBox(height: 16),
                  StudioCard(
                    icon: Icons.query_stats_rounded,
                    title: 'Relationship Insights',
                    desc:
                        'Fun statistics, shared milestones, and emotional dashboard charts.',
                    isPremium: true,
                    isUnlocked: isPremium,
                    theme: theme,
                    onTap: () {
                      if (isPremium) {
                        context.push(Routes.studioInsights);
                      } else {
                        _showPremiumPaywall(context, ref, theme);
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
}
