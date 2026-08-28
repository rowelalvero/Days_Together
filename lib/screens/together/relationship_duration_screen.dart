import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ConsumerWidget, WidgetRef;
import 'package:intl/intl.dart';

import 'package:days_together/features/relationship/license_controller.dart';
import 'package:days_together/features/relationship/license_details.dart';
import 'package:days_together/features/relationship/presentation/duration/components/anniversary_countdown_card.dart';
import 'package:days_together/features/relationship/presentation/duration/components/duration_breakdown_section.dart';
import 'package:days_together/features/relationship/presentation/duration/components/first_memory_highlight_card.dart';
import 'package:days_together/features/relationship/presentation/duration/components/journey_fun_facts_grid.dart';
import 'package:days_together/features/relationship/presentation/duration/components/live_stopwatch_card.dart';
import 'package:days_together/features/relationship/presentation/duration/components/milestones_achieved_timeline.dart';
import 'package:days_together/features/relationship/presentation/duration/components/next_milestone_card.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/services/date_helper.dart';
import 'package:days_together/themes/app_typography.dart';

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
    final license = ref.watch(licenseControllerProvider).value ?? const LicenseDetails();

    final startDate = workspace.startDate ?? DateTime.now();
    final totalDays = DateHelper.relationshipTotalDays(workspace.startDate);
    final currentYears = DateHelper.relationshipPreciseAge(
      workspace.startDate,
      workspace.startTime,
    )['years'] ?? 0;

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
            // Sliver App Bar with Hero Counter Header
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.textColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: theme.textColor, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.blurBackground,
                ],
                background: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Decorative circle
                    Positioned(
                      top: 40,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: theme.accentColor.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 50),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite_rounded, color: theme.accentColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'TOGETHER FOR',
                              style: AppTypography.cardCategory(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: theme.textColor.withValues(alpha: 0.6),
                                letterSpacing: 2.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: totalDays.toDouble()),
                          duration: const Duration(milliseconds: 1600),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [theme.accentColor, Colors.amberAccent],
                              ).createShader(bounds),
                              child: Text(
                                NumberFormat('#,###').format(value.toInt()),
                                style: AppTypography.display(
                                  fontSize: 64,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                        Text(
                          'Days',
                          style: AppTypography.cormorant(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor.withValues(alpha: 0.8),
                          ).copyWith(letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.textColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.textColor.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Since ${DateFormat('MMMM dd, yyyy').format(startDate)}',
                            style: AppTypography.bodyMono(
                              fontSize: 11,
                              color: theme.textColor.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
