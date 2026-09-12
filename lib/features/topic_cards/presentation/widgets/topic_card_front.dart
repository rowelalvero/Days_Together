import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/topic_cards/domain/entities/topic_card_model.dart';

/// The face-up side of the interactive topic card -- category label,
/// "Conversation Deck" title, and a "tap to reveal" affordance. Extracted
/// from [TopicCardsScreen]'s `_buildCardFront` (Migration audit item 6).
class TopicCardFront extends StatelessWidget {
  const TopicCardFront({super.key, required this.theme, required this.card});

  final LoveStoryTheme theme;
  final TopicCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 400,
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFD4AF37), // elegant gold border
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.accentColor.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Corner gold accents
          Positioned(
            top: 10,
            left: 10,
            child: Icon(
              Icons.star_border_rounded,
              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
              size: 18,
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Icon(
              Icons.star_border_rounded,
              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
              size: 18,
            ),
          ),
          Positioned(
            bottom: 10,
            left: 10,
            child: Icon(
              Icons.star_border_rounded,
              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
              size: 18,
            ),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: Icon(
              Icons.star_border_rounded,
              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
              size: 18,
            ),
          ),

          // Core content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: theme.accentColor.withValues(alpha: 0.8),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    card.category.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AppTypography.caption(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFD4AF37),
                    ).copyWith(letterSpacing: 2),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Conversation Deck',
                    textAlign: TextAlign.center,
                    style: AppTypography.heading(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.textColor.withValues(alpha: 0.2),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'TAP TO REVEAL',
                      style: AppTypography.caption(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor.withValues(alpha: 0.6),
                      ).copyWith(letterSpacing: 1.5),
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
