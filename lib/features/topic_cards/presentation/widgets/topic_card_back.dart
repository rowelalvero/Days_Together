import 'dart:math';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/topic_cards/domain/entities/topic_card_model.dart';
import 'package:days_together/features/topic_cards/topic_cards_controller.dart';

/// The revealed side of the interactive topic card -- the question itself,
/// a delete action for custom cards, and share/favorite controls. Extracted
/// from [TopicCardsScreen]'s `_buildCardBack` (Migration audit item 6).
///
/// The `Transform(..rotateY(pi))` at the root un-mirrors this content: the
/// parent flip animation rotates the whole card past 180 degrees to reveal
/// this side, which would otherwise read backwards.
class TopicCardBack extends StatelessWidget {
  const TopicCardBack({
    super.key,
    required this.theme,
    required this.card,
    required this.notifier,
  });

  final LoveStoryTheme theme;
  final TopicCard card;
  final TopicCardsController notifier;

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        title: Text(
          'Delete Card?',
          style: AppTypography.title(
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this custom topic card?',
          style: AppTypography.body(
            color: theme.textColor.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: Text(
              'Delete',
              style: AppTypography.button(color: Colors.redAccent),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              notifier.deleteCard(card.id);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Transform(
      // We flip Y axis of the content so it reads correctly when Y-rotated 180 degrees
      transform: Matrix4.identity()..rotateY(pi),
      alignment: Alignment.center,
      child: Container(
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Row: Category label & Delete (if custom)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.accentColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        card.category,
                        style: AppTypography.caption(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.accentColor,
                        ),
                      ),
                    ),
                    if (card.isCustom)
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () => _confirmDelete(context),
                      ),
                  ],
                ),
                const Spacer(),

                // Question Text
                Text(
                  card.question,
                  textAlign: TextAlign.center,
                  style: AppTypography.heading(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                    height: 1.4,
                  ),
                ),
                const Spacer(),

                // Bottom Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Share Button
                    IconButton(
                      icon: Icon(
                        Icons.share_outlined,
                        color: theme.textColor.withValues(alpha: 0.6),
                      ),
                      onPressed: () {
                        Share.share(
                          'Here is a relationship topic for us: "${card.question}" 💕',
                          subject: 'Deep Connection Topic',
                        );
                      },
                    ),

                    // Like/Favorite Toggle Button
                    IconButton(
                      icon: Icon(
                        card.isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: card.isLiked
                            ? theme.accentColor
                            : theme.textColor.withValues(alpha: 0.6),
                      ),
                      onPressed: () {
                        notifier.toggleLikeCard(card.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
