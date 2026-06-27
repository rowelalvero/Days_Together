import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/daily_mood_provider.dart';
import 'package:days_together/models/daily_mood_model.dart';
import 'package:days_together/themes/app_typography.dart';

class LoveMeterScreen extends StatefulWidget {
  const LoveMeterScreen({super.key});

  @override
  State<LoveMeterScreen> createState() => _LoveMeterScreenState();
}

class _LoveMeterScreenState extends State<LoveMeterScreen> {
  double _currentMoodScore = 7.0;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  bool _isEditingMood = false;

  @override
  void initState() {
    super.initState();
    final moodProvider = context.read<DailyMoodProvider>();
    final todayMood = moodProvider.todayMood;
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

  String _getMoodEmoji(double score) {
    if (score <= 2) return '😢';
    if (score <= 4) return '😕';
    if (score <= 6) return '🙂';
    if (score <= 8) return '😊';
    return '😍';
  }

  String _getMoodLabel(double score) {
    if (score <= 2) return 'Sad / Low energy';
    if (score <= 4) return 'A bit down / Tired';
    if (score <= 6) return 'Good / Content';
    if (score <= 8) return 'Happy / Positive';
    return 'Amazing / In Love!';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final moodProvider = context.watch<DailyMoodProvider>();
    final todayMood = moodProvider.todayMood;
    final todayQuestion = moodProvider.todayQuestion;

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
                  _buildAppBar(context, theme),
                  if (todayMood == null || _isEditingMood)
                    _buildMoodLogger(theme, moodProvider)
                  else
                    _buildTodayMoodSummary(todayMood, theme),
                  const SizedBox(height: 24),
                  _buildSyncQuestionCard(todayQuestion, theme, moodProvider),
                  const SizedBox(height: 24),
                  _buildMoodChartCard(moodProvider.recentMoods, theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, dynamic theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Love Meter',
                style: AppTypography.cormorant(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              Text(
                'Sync your hearts and track your moods.',
                style: AppTypography.spectral(
                  fontSize: 12,
                  color: theme.textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoodLogger(dynamic theme, DailyMoodProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'How is your mood today?',
            style: AppTypography.sectionHeader(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _getMoodEmoji(_currentMoodScore),
            style: AppTypography.body(fontSize: 70),
          ),
          const SizedBox(height: 8),
          Text(
            _getMoodLabel(_currentMoodScore),
            style: AppTypography.body(
              fontSize: 16,
              color: theme.accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.accentColor,
              inactiveTrackColor: theme.textColor.withValues(alpha: 0.1),
              thumbColor: theme.accentColor,
              overlayColor: theme.accentColor.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            ),
            child: Slider(
              value: _currentMoodScore,
              min: 1.0,
              max: 10.0,
              divisions: 9,
              label: _currentMoodScore.toInt().toString(),
              onChanged: (val) {
                setState(() {
                  _currentMoodScore = val;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                10,
                (i) => Text(
                  '${i + 1}',
                  style: AppTypography.caption(
                    color: (_currentMoodScore.toInt() == i + 1)
                        ? theme.textColor
                        : theme.textColor.withValues(alpha: 0.38),
                    fontWeight: (_currentMoodScore.toInt() == i + 1)
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _noteController,
            style: AppTypography.body(color: theme.textColor),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Add a small note about your day... (optional)',
              hintStyle: AppTypography.body(color: theme.textColor.withValues(alpha: 0.3)),
              filled: true,
              fillColor: theme.textColor.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.textColor.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.accentColor),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                await provider.logMood(
                  _currentMoodScore.toInt(),
                  note: _noteController.text.trim().isEmpty
                      ? null
                      : _noteController.text.trim(),
                );
                setState(() {
                  _isEditingMood = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Log Today\'s Mood',
                style: AppTypography.button(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMoodSummary(DailyMood todayMood, dynamic theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Mood',
                style: AppTypography.body(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor.withValues(alpha: 0.7),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isEditingMood = true;
                  });
                },
                icon: const Icon(Icons.edit, size: 16),
                label: Text('Update', style: AppTypography.button(color: theme.accentColor)),
                style: TextButton.styleFrom(foregroundColor: theme.accentColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                _getMoodEmoji(todayMood.moodScore.toDouble()),
                style: AppTypography.body(fontSize: 48),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score: ${todayMood.moodScore}/10',
                      style: AppTypography.body(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getMoodLabel(todayMood.moodScore.toDouble()),
                      style: AppTypography.body(
                        fontSize: 14,
                        color: theme.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (todayMood.note != null && todayMood.note!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '"${todayMood.note}"',
                style: AppTypography.body(
                  color: theme.textColor.withValues(alpha: 0.7),
                  fontSize: 14,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncQuestionCard(
      DailySyncQuestion? question, dynamic theme, DailyMoodProvider provider) {
    if (question == null) return const SizedBox.shrink();

    final hasAnswered = question.myAnswer != null;
    final bothAnswered = question.bothAnswered;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.favorite_rounded, color: theme.accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Daily Sync Question',
                style: AppTypography.body(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            question.question,
            style: AppTypography.body(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.textColor,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 20),
          if (!hasAnswered) ...[
            TextField(
              controller: _answerController,
              style: AppTypography.body(color: theme.textColor),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Type your answer here...',
                hintStyle: AppTypography.body(color: theme.textColor.withValues(alpha: 0.3)),
                filled: true,
                fillColor: theme.textColor.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.textColor.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.accentColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (_answerController.text.trim().isNotEmpty) {
                    await provider.answerDailyQuestion(_answerController.text.trim());
                    _answerController.clear();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text('Submit Answer', style: AppTypography.button(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.textColor.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Answer:',
                    style: AppTypography.caption(
                      color: theme.textColor.withValues(alpha: 0.54),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    question.myAnswer!,
                    style: AppTypography.body(color: theme.textColor, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!bothAnswered) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: theme.textColor.withValues(alpha: 0.01),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.textColor.withValues(alpha: 0.05),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.textColor.withValues(alpha: 0.3)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '⏳ Waiting for partner to reply...',
                      style: AppTypography.body(
                        color: theme.textColor.withValues(alpha: 0.5),
                        fontSize: 13,
                      ).copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.accentColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Partner\'s Answer:',
                      style: AppTypography.caption(
                        color: Colors.pinkAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      question.partnerAnswer!,
                      style: AppTypography.body(color: theme.textColor, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMoodChartCard(List<DailyMood> recentMoods, dynamic theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emotional Map',
            style: AppTypography.body(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Mood sync history over the last 30 days',
            style: AppTypography.caption(
              fontSize: 12,
              color: theme.textColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 30),
          if (recentMoods.length < 2)
            Container(
              height: 200,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Log your mood for a few days to see your emotional map 📈',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  color: theme.textColor.withValues(alpha: 0.38),
                  fontSize: 13,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: AppTypography.caption(
                              color: theme.textColor.withValues(alpha: 0.3),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: (recentMoods.length / 4).clamp(1.0, 30.0),
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < recentMoods.length) {
                            final date = DateTime.parse(recentMoods[idx].date);
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                DateFormat('MM/dd').format(date),
                                style: AppTypography.caption(
                                  color: theme.textColor.withValues(alpha: 0.3),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (recentMoods.length - 1).toDouble(),
                  minY: 1,
                  maxY: 10,
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        recentMoods.length,
                        (index) => FlSpot(
                          index.toDouble(),
                          recentMoods[index].moodScore.toDouble(),
                        ),
                      ),
                      isCurved: true,
                      color: theme.accentColor,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 5,
                          color: theme.accentColor,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.accentColor.withValues(alpha: 0.15),
                      ),
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
