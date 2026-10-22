import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/topic_cards/domain/entities/topic_card_model.dart';

/// The plain, non-interactive card silhouette rendered behind the top of the
/// deck to suggest depth -- extracted from [TopicCardsScreen]'s
/// `_buildStaticCardCover` (Migration audit item 6).
///
/// [card] is unused in the render (the cover carries no content), but is
/// kept as a parameter matching the original method's signature: callers
/// already have a specific card in hand (the one *behind* the top of the
/// deck) and passing it keeps this widget's API honest about which card's
/// position it represents, in case a future design gives the cover content.
class TopicCardStaticCover extends StatelessWidget {
  const TopicCardStaticCover({
    super.key,
    required this.theme,
    required this.card,
  });

  final LoveStoryTheme theme;
  final TopicCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 400,
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.textColor.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
    );
  }
}
