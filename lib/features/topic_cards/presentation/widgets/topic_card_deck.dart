import 'dart:math';

import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/topic_cards/domain/entities/topic_card_model.dart';
import 'package:days_together/features/topic_cards/presentation/widgets/topic_card_back.dart';
import 'package:days_together/features/topic_cards/presentation/widgets/topic_card_front.dart';
import 'package:days_together/features/topic_cards/presentation/widgets/topic_card_static_cover.dart';
import 'package:days_together/features/topic_cards/topic_cards_controller.dart';

/// The interactive card stack: two static covers suggesting depth behind a
/// draggable, flippable top card. Extracted from [TopicCardsScreen]'s
/// `_buildCardDeck` (Migration audit item 6).
///
/// Deliberately still a "dumb" render given its parameters -- the drag
/// offset, swipe/flip animations, and gesture callbacks all remain owned by
/// `_TopicCardsScreenState`, which is the only object with a `vsync` and a
/// reason to call `setState`. This widget just draws whatever position and
/// rotation it is handed, and forwards gestures back up.
class TopicCardDeck extends StatelessWidget {
  const TopicCardDeck({
    super.key,
    required this.deck,
    required this.index,
    required this.theme,
    required this.notifier,
    required this.dragOffset,
    required this.isSwipeAnimating,
    required this.rotationAnimation,
    required this.flipRotation,
    required this.onHorizontalDragUpdate,
    required this.onHorizontalDragEnd,
    required this.onTap,
  });

  final List<TopicCard> deck;
  final int index;
  final LoveStoryTheme theme;
  final TopicCardsController notifier;

  /// The top card's current translation, driven either by an in-progress
  /// drag or by the snap-back/swipe-away animation.
  final Offset dragOffset;

  /// Whether the swipe animation is currently running -- while true, the
  /// card's rotation follows [rotationAnimation] rather than [dragOffset].
  final bool isSwipeAnimating;
  final Animation<double> rotationAnimation;

  /// 0 (face up) to pi (face down); driven by the parent's flip
  /// `TweenAnimationBuilder`.
  final double flipRotation;

  final GestureDragUpdateCallback onHorizontalDragUpdate;
  final GestureDragEndCallback onHorizontalDragEnd;
  final VoidCallback onTap;

  static const double _cardWidth = 300;
  static const double _cardHeight = 440;

  @override
  Widget build(BuildContext context) {
    // We build a stack representing the deck.
    // The top card is interactive.
    // Behind it we render 1 or 2 visual placeholders of other cards to create a deck effect.
    return Center(
      child: SizedBox(
        width: _cardWidth + 50,
        height: _cardHeight + 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Bottom deck visual shadow card
            if (deck.length > 2)
              Positioned(
                bottom: 5,
                child: Transform.scale(
                  scale: 0.90,
                  child: Opacity(
                    opacity: 0.4,
                    child: TopicCardStaticCover(
                      theme: theme,
                      card: deck[(index + 2) % deck.length],
                    ),
                  ),
                ),
              ),

            // Middle deck visual shadow card
            if (deck.length > 1)
              Positioned(
                bottom: 15,
                child: Transform.scale(
                  scale: 0.95,
                  child: Opacity(
                    opacity: 0.7,
                    child: TopicCardStaticCover(
                      theme: theme,
                      card: deck[(index + 1) % deck.length],
                    ),
                  ),
                ),
              ),

            // Top draggable & interactive card
            Positioned(
              bottom: 25,
              child: GestureDetector(
                onHorizontalDragUpdate: onHorizontalDragUpdate,
                onHorizontalDragEnd: onHorizontalDragEnd,
                onTap: onTap,
                child: Transform.translate(
                  offset: dragOffset,
                  child: Transform.rotate(
                    angle: isSwipeAnimating
                        ? rotationAnimation.value
                        : (dragOffset.dx / 1000).clamp(-0.15, 0.15),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: flipRotation),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      builder: (context, angle, child) {
                        final isBack = angle >= pi / 2;
                        return Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001) // perspective
                            ..rotateY(angle),
                          alignment: Alignment.center,
                          child: isBack
                              ? TopicCardBack(
                                  theme: theme,
                                  card: deck[index],
                                  notifier: notifier,
                                )
                              : TopicCardFront(theme: theme, card: deck[index]),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
