import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/relationship/presence_controller.dart';
import 'package:days_together/features/bucket_list/bucket_list_controller.dart';
import 'package:days_together/features/dashboard/presentation/detailed_days_counter.dart';
import 'package:days_together/features/dashboard/presentation/insights_banner.dart';
import 'package:days_together/features/dashboard/presentation/milestone_card.dart';
import 'package:days_together/features/dashboard/presentation/memory_highlight_carousel.dart';
import 'package:days_together/features/dashboard/presentation/relationship_statistics.dart';
import 'package:days_together/features/dashboard/presentation/bento_grid.dart';
import 'package:days_together/features/dashboard/presentation/currently_card.dart';
import 'package:days_together/features/dashboard/presentation/recent_activity_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer, Provider;
import 'package:days_together/app/theme/app_typography.dart';

/// The Home tab's content, extracted from the shell's love_story_screen.dart
/// (it composed eight `dashboard` widgets from inside a file the `shell`
/// owned, which inverted the feature boundary). The shell now imports this
/// page instead of reaching into dashboard's internals.

// ──────────────────────────────────────────────
// HOME DASHBOARD
// ──────────────────────────────────────────────

class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final workspace = ref.watch(workspaceControllerProvider);
    final profile = ref.watch(profileControllerProvider);
    final presence = ref.watch(presenceControllerProvider);
    final tp = ref.watch(timelineControllerProvider);
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailedDaysCounter(workspace: workspace, theme: theme),
            const SizedBox(height: 16),
            const CurrentlyCard(),
            const SizedBox(height: 16),
            InsightsBanner(
              timelineProvider: tp,
              bucketProvider: ref.watch(bucketListControllerProvider),
              workspace: workspace,
              profile: profile,
              presence: presence,
              theme: theme,
            ),
            const SizedBox(height: 16),
            MilestoneCard(
              workspace: workspace,
              isPaired: session.isPaired,
              theme: theme,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.bookmark_rounded,
                  color: Colors.pinkAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Latest Captured Memories',
                  style: AppTypography.title(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MemoryHighlightCarousel(timelineProvider: tp, theme: theme),
            const SizedBox(height: 24),
            RelationshipStatistics(theme: theme),
            const SizedBox(height: 24),
            BentoGrid(theme: theme),
            const SizedBox(height: 24),
            RecentActivityFeed(theme: theme),
            const SizedBox(height: 120), // Bottom navigation padding
          ],
        ),
      ),
    );
  }
}
