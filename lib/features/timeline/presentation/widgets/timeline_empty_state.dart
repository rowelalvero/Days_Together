import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/timeline/presentation/widgets/add_item_dialog.dart';

/// The "your story begins here" empty state on [TimelineTab]. Extracted
/// from its `_buildEmptyState` method (Migration audit item 6).
class TimelineEmptyState extends StatelessWidget {
  const TimelineEmptyState({super.key, required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.textColor.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 64,
              color: theme.accentColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Your story begins here.',
            textAlign: TextAlign.center,
            style: AppTypography.heading(
              color: theme.textColor,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Every date, every laugh, and every small moment is a chapter in your book. Start capturing your memories together.',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              color: theme.textColor.withValues(alpha: 0.5),
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              // AddItemDialog is pushed via Navigator, not context.push,
              // deliberately: despite using Navigator.push rather than
              // showDialog, it's conceptually a dialog (full-screen
              // overlay, no deep link or back-button target of its own)
              // -- out of ADR-007's scope the same way showDialog sites
              // are. See love_story_screen.dart's own "+" FAB for the
              // same reasoning.
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AddItemDialog()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded),
                const SizedBox(width: 8),
                Text(
                  'Capture first memory',
                  style: AppTypography.body(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
