import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The placeholder shown in place of the card deck when the active category
/// has no cards -- either "Favorites" with nothing liked yet, or a category
/// with no custom cards added. Extracted from [TopicCardsScreen]'s
/// `_buildEmptyState` (Migration audit item 6).
class TopicCardsEmptyState extends StatelessWidget {
  const TopicCardsEmptyState({
    super.key,
    required this.theme,
    required this.activeCategory,
    required this.onAddCard,
  });

  final LoveStoryTheme theme;
  final String activeCategory;

  /// Favorites has no "add a card" action -- there is no category to add it
  /// to -- so this is only invoked from the "Create Custom Card" button,
  /// which is itself only shown for non-Favorites categories.
  final VoidCallback onAddCard;

  @override
  Widget build(BuildContext context) {
    final isFav = activeCategory == 'Favorites';
    return GlassContainer(
      borderRadius: 24,
      opacity: 0.08,
      margin: const EdgeInsets.symmetric(horizontal: 36, vertical: 48),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFav
                  ? Icons.favorite_outline_rounded
                  : Icons.folder_open_rounded,
              size: 50,
              color: theme.accentColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isFav ? 'No Favorited Topics' : 'No custom prompts yet',
            style: AppTypography.heading(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            isFav
                ? 'Tap the heart icon on any card to save meaningful prompts for later!'
                : 'Add your own custom prompts to personalize your deck!',
            style: AppTypography.body(
              fontSize: 14,
              color: theme.textColor.withValues(alpha: 0.6),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          if (!isFav)
            ElevatedButton.icon(
              onPressed: onAddCard,
              icon: const Icon(Icons.add),
              label: const Text('Create Custom Card'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
