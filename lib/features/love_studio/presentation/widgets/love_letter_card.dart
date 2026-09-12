import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The generated-letter display card on [AILoveLetterScreen], with its
/// copy/share actions. Extracted from its `_buildLetterCard` method
/// (Migration audit item 6).
class LoveLetterCard extends StatelessWidget {
  const LoveLetterCard({super.key, required this.letter, required this.theme});

  final String letter;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
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
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  Icons.copy_rounded,
                  color: theme.textColor.withValues(alpha: 0.7),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: letter));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard!')),
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.share_rounded,
                  color: theme.textColor.withValues(alpha: 0.7),
                ),
                onPressed: () {
                  Share.share(letter);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            letter,
            style: AppTypography.lora(
              fontSize: 16,
              height: 1.6,
              color: theme.textColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
