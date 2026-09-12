import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/mood/domain/entities/daily_mood_model.dart';

/// The daily connection prompt on [LoveMeterScreen]: the question, an
/// answer field (before answering), or both partners' answers (after).
/// Extracted from its `_buildSyncQuestionCard` (Migration audit item 6).
class DailySyncQuestionCard extends StatelessWidget {
  const DailySyncQuestionCard({
    super.key,
    required this.question,
    required this.theme,
    required this.answerController,
    required this.onSubmitAnswer,
  });

  final DailySyncQuestion? question;
  final LoveStoryTheme theme;
  final TextEditingController answerController;
  final VoidCallback onSubmitAnswer;

  @override
  Widget build(BuildContext context) {
    final question = this.question;
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
                child: Icon(
                  Icons.favorite_rounded,
                  color: theme.accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Daily Connection Prompt',
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
              controller: answerController,
              style: AppTypography.body(color: theme.textColor),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Write your response here...',
                hintStyle: AppTypography.body(
                  color: theme.textColor.withValues(alpha: 0.3),
                ),
                filled: true,
                fillColor: theme.textColor.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: theme.textColor.withValues(alpha: 0.1),
                  ),
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
                onPressed: onSubmitAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Share Response',
                  style: AppTypography.button(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.textColor.withValues(alpha: 0.05),
                ),
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
                    style: AppTypography.body(
                      color: theme.textColor,
                      fontSize: 14,
                    ),
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.textColor.withValues(alpha: 0.3),
                      ),
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
                  border: Border.all(
                    color: theme.accentColor.withValues(alpha: 0.2),
                  ),
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
                      style: AppTypography.body(
                        color: theme.textColor,
                        fontSize: 14,
                      ),
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
}
