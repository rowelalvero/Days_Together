import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/providers/bucket_list_provider.dart';
import 'package:days_together/providers/daily_mood_provider.dart';
import 'package:days_together/services/ai_service.dart';

class RelationshipInsightsScreen extends StatefulWidget {
  const RelationshipInsightsScreen({super.key});

  @override
  State<RelationshipInsightsScreen> createState() => _RelationshipInsightsScreenState();
}

class _RelationshipInsightsScreenState extends State<RelationshipInsightsScreen> {
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
        const SnackBar(
          content: Text('✨ Insights updated successfully!'),
          backgroundColor: Colors.pinkAccent,
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

    final rp = context.watch<RelationshipProvider>();
    final tp = context.watch<TimelineProvider>();
    final bp = context.watch<BucketListProvider>();
    final dp = context.watch<DailyMoodProvider>();

    final commonMood = _getCommonMood(dp.moods);
    final insights = AIService.generateInsights(
      totalDays: rp.totalDays,
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
                _buildAppBar(context),
                Expanded(
                  child: _isRefreshing
                      ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                          itemCount: insights.length,
                          itemBuilder: (context, index) {
                            return _buildInsightCard(insights[index], theme, index);
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

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Love Insights',
                style: TextStyle(
                  fontFamily: 'Cormorant',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Fun statistics and facts about your love story.',
                style: TextStyle(
                  fontFamily: 'Spectral',
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String insight, dynamic theme, int index) {
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                  style: const TextStyle(
                    color: Colors.white,
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
