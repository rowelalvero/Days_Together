import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerWidget, WidgetRef;

import 'package:days_together/features/relationship/license_controller.dart';
import 'package:days_together/features/relationship/license_details.dart';
import 'package:days_together/features/relationship/presentation/duration/components/anniversary_countdown_card.dart';
import 'package:days_together/features/relationship/presentation/duration/components/duration_breakdown_section.dart';
import 'package:days_together/features/relationship/presentation/duration/components/duration_hero_app_bar.dart';
import 'package:days_together/features/relationship/presentation/duration/components/first_memory_highlight_card.dart';
import 'package:days_together/features/relationship/presentation/duration/components/journey_fun_facts_grid.dart';
import 'package:days_together/features/relationship/presentation/duration/components/live_stopwatch_card.dart';
import 'package:days_together/features/relationship/presentation/duration/components/milestones_achieved_timeline.dart';
import 'package:days_together/features/relationship/presentation/duration/components/next_milestone_card.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/core/utils/date_helper.dart';

/// Relationship Duration & Milestones Screen.
/// Displays animated duration counters, live ticking stopwatch, milestone achievements,
/// upcoming anniversary countdowns, and relationship journey fun facts.
class RelationshipDurationScreen extends ConsumerWidget {
  const RelationshipDurationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;
    final workspace = ref.watch(workspaceControllerProvider);
    final tp = ref.watch(timelineControllerProvider);
    final license =
        ref.watch(licenseControllerProvider).value ?? const LicenseDetails();

    final startDate = workspace.startDate ?? DateTime.now();
    final totalDays = DateHelper.relationshipTotalDays(workspace.startDate);
    final currentYears =
        DateHelper.relationshipPreciseAge(
          workspace.startDate,
          workspace.startTime,
        )['years'] ??
        0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.primaryColor,
              theme.secondaryColor,
              theme.backgroundColor,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            DurationHeroAppBar(
              totalDays: totalDays,
              startDate: startDate,
              theme: theme,
            ),

            // Scrollable Bento Sections
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 1. Duration Breakdown
                  DurationBreakdownSection(workspace: workspace, theme: theme),
                  const SizedBox(height: 16),

                  // 2. Live Stopwatch Counter
                  LiveStopwatchCard(
                    startDate: DateHelper.relationshipStartDateTime(
                      workspace.startDate,
                      workspace.startTime,
                    ),
                    theme: theme,
                  ),
                  const SizedBox(height: 16),

                  // 3. Next Milestone Progress
                  NextMilestoneCard(workspace: workspace, theme: theme),
                  const SizedBox(height: 16),

                  // 4. Anniversary Countdown
                  AnniversaryCountdownCard(
                    startDate: startDate,
                    currentYears: currentYears,
                    theme: theme,
                  ),
                  const SizedBox(height: 16),

                  // 5. Fun Statistics Grid
                  JourneyFunFactsGrid(
                    startDate: startDate,
                    workspace: workspace,
                    license: license,
                    theme: theme,
                  ),
                  const SizedBox(height: 24),

                  // 6. Milestone Achieved Timeline
                  MilestonesAchievedTimeline(
                    startDate: startDate,
                    totalDays: totalDays,
                    theme: theme,
                  ),
                  const SizedBox(height: 24),

                  // 7. Memories Highlight Section
                  FirstMemoryHighlightCard(tp: tp, theme: theme),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
