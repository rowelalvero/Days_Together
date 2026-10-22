import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/features/mood/daily_mood_controller.dart';
import 'package:days_together/features/mood/presentation/widgets/daily_sync_question_card.dart';
import 'package:days_together/features/mood/presentation/widgets/love_meter_app_bar.dart';
import 'package:days_together/features/mood/presentation/widgets/mood_chart_card.dart';
import 'package:days_together/features/mood/presentation/widgets/mood_logger_card.dart';
import 'package:days_together/features/mood/presentation/widgets/today_mood_summary_card.dart';
import 'package:days_together/features/theme/theme_controller.dart';

/// The couple's shared mood tracker: today's mood logger/summary, a daily
/// connection prompt, and a 30-day mood trend chart.
///
/// Its `_buildX` methods were extracted into focused widgets under
/// `presentation/widgets/` (Migration audit item 6) -- this class now only
/// owns the in-progress mood-entry state (score/note/editing flag).
class LoveMeterScreen extends ConsumerStatefulWidget {
  const LoveMeterScreen({super.key});

  @override
  ConsumerState<LoveMeterScreen> createState() => _LoveMeterScreenState();
}

class _LoveMeterScreenState extends ConsumerState<LoveMeterScreen> {
  double _currentMoodScore = 7.0;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  bool _isEditingMood = false;

  @override
  void initState() {
    super.initState();
    final moodState = ref.read(dailyMoodControllerProvider);
    final todayMood = moodState.todayMood;
    if (todayMood != null) {
      _currentMoodScore = todayMood.moodScore.toDouble();
      _noteController.text = todayMood.note ?? '';
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _saveMood(DailyMoodController notifier) async {
    final noteText = _noteController.text.trim();
    await notifier.logMood(
      _currentMoodScore.toInt(),
      note: noteText.isEmpty ? null : noteText,
    );
    if (mounted) {
      setState(() {
        _isEditingMood = false;
      });
    }
  }

  Future<void> _submitAnswer(DailyMoodController notifier) async {
    final text = _answerController.text.trim();
    if (text.isNotEmpty) {
      await notifier.answerDailyQuestion(text);
      if (mounted) {
        _answerController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;
    final moodState = ref.watch(dailyMoodControllerProvider);
    final moodNotifier = ref.read(dailyMoodControllerProvider.notifier);
    final todayMood = moodState.todayMood;
    final todayQuestion = moodState.todayQuestion;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: themeProvider.currentGradient),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LoveMeterAppBar(theme: theme),
                  if (todayMood == null || _isEditingMood)
                    MoodLoggerCard(
                      theme: theme,
                      currentScore: _currentMoodScore,
                      noteController: _noteController,
                      onScoreChanged: (val) =>
                          setState(() => _currentMoodScore = val),
                      onSave: () => _saveMood(moodNotifier),
                    )
                  else
                    TodayMoodSummaryCard(
                      todayMood: todayMood,
                      theme: theme,
                      onUpdate: () => setState(() => _isEditingMood = true),
                    ),
                  const SizedBox(height: 24),
                  DailySyncQuestionCard(
                    question: todayQuestion,
                    theme: theme,
                    answerController: _answerController,
                    onSubmitAnswer: () => _submitAnswer(moodNotifier),
                  ),
                  const SizedBox(height: 24),
                  MoodChartCard(
                    recentMoods: moodState.recentMoods,
                    theme: theme,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
