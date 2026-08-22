import 'package:days_together/themes/theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/providers/bucket_list_provider.dart';
import 'package:days_together/providers/daily_mood_provider.dart';
import 'package:days_together/services/ai_service.dart';
import 'package:days_together/services/date_helper.dart';
import 'package:days_together/themes/app_typography.dart';

class RelationshipInsightsScreen extends ConsumerStatefulWidget {
  const RelationshipInsightsScreen({super.key});

  @override
  ConsumerState<RelationshipInsightsScreen> createState() =>
      _RelationshipInsightsScreenState();
}

class _RelationshipInsightsScreenState
    extends ConsumerState<RelationshipInsightsScreen> {
  bool _isRefreshing = false;

  void _refreshInsights() async {
    setState(() {
      _isRefreshing = true;
    });
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✨ Insights updated successfully!'),
          backgroundColor: context
              .read<ThemeProvider>()
              .currentLoveTheme
              .accentColor,
        ),
      );
    }
  }

  String _getCommonMood(List<dynamic> moods) {
    if (moods.isEmpty) return "";
    final counts = <int, int>{};
    for (final m in moods) {
      counts[m.moodScore] = (counts[m.moodScore] ?? 0) + 1;
    }
    var maxScore = 5;
    var maxCount = 0;
    counts.forEach((score, count) {
      if (count > maxCount) {
        maxCount = count;
        maxScore = score;
      }
    });

    if (maxScore <= 2) return '😢 Sad / Low';
    if (maxScore <= 4) return '😕 Okay';
    if (maxScore <= 6) return '🙂 Good';
    if (maxScore <= 8) return '😊 Happy';
    return '😍 Amazing';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;

    final workspace = ref.watch(workspaceControllerProvider);
    final tp = context.watch<TimelineProvider>();
    final bp = context.watch<BucketListProvider>();
    final dp = context.watch<DailyMoodProvider>();

    final commonMood = _getCommonMood(dp.moods);
    final insights = AIService.generateInsights(
      totalDays: DateHelper.relationshipTotalDays(workspace.startDate),
      totalMemories: tp.timelineItems.length,
      commonMood: commonMood,
      totalBucketItems: bp.totalItems,
      completedBucketItems: bp.completedItems,
    );

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: themeProvider.currentGradient),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, theme),
                Expanded(
                  child: _isRefreshing
                      ? Center(
                          child: CircularProgressIndicator(
                            color: theme.accentColor,
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                          itemCount: insights.length,
                          itemBuilder: (context, index) {
                            return _buildInsightCard(
                              insights[index],
                              theme,
                              index,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshInsights,
        backgroundColor: theme.accentColor,
        child: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, LoveStoryTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: theme.textColor,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Relationship Insights',
                  style: AppTypography.cormorant(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                Text(
                  'Fun statistics and facts about your love story.',
                  style: AppTypography.spectral(
                    fontSize: 12,
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String insight, LoveStoryTheme theme, int index) {
    // Pick different background overlays to represent premium charts/insights
    final icons = [
      Icons.favorite_rounded,
      Icons.auto_awesome_rounded,
      Icons.bar_chart_rounded,
      Icons.flag_rounded,
      Icons.bubble_chart_rounded,
    ];
    final currentIcon = icons[index % icons.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(currentIcon, color: theme.accentColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight,
                  style: AppTypography.body(
                    color: theme.textColor,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
