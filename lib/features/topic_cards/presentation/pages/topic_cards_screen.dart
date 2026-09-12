import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/topic_cards/presentation/sheets/add_topic_card_sheet.dart';
import 'package:days_together/features/topic_cards/presentation/widgets/topic_card_deck.dart';
import 'package:days_together/features/topic_cards/presentation/widgets/topic_card_round_button.dart';
import 'package:days_together/features/topic_cards/presentation/widgets/topic_cards_empty_state.dart';
import 'package:days_together/features/topic_cards/topic_cards_controller.dart';

/// The Topic Cards feature's home screen: a swipeable, flippable deck of
/// conversation prompts, filterable by category.
///
/// Card rendering, the empty-deck placeholder, and the "add a custom card"
/// sheet were split out into their own widgets under `presentation/widgets/`
/// and `presentation/sheets/` (Migration audit item 6) -- this class now
/// owns only what genuinely needs to live on a `State`: the swipe/flip
/// animation controllers and the drag gesture handlers that drive them.
class TopicCardsScreen extends ConsumerStatefulWidget {
  const TopicCardsScreen({super.key});

  @override
  ConsumerState<TopicCardsScreen> createState() => _TopicCardsScreenState();
}

class _TopicCardsScreenState extends ConsumerState<TopicCardsScreen>
    with SingleTickerProviderStateMixin {
  // Swipe animation controller
  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;
  late Animation<double> _rotationAnimation;

  Offset _dragOffset = Offset.zero;
  bool _isFlipped = false;
  double _flipRotation = 0.0; // Y axis rotation for 3D flip

  final List<String> _categories = [
    'All',
    'Deep Conversations',
    'Fun & Quirky',
    'Future & Dreams',
    'Love & Romance',
    'Intimacy & Bonding',
    'Favorites',
  ];

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    // Only drag top card if deck has items
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onHorizontalDragEnd(
    DragEndDetails details,
    TopicCardsController notifier,
  ) {
    final threshold = 120.0;
    if (_dragOffset.dx > threshold) {
      // Swipe Right -> Go to next question (or previous, depending on preference)
      _animateSwipe(endOffset: const Offset(600, 50), rotation: 0.15).then((_) {
        notifier.previousCard();
        _resetCardPosition();
      });
    } else if (_dragOffset.dx < -threshold) {
      // Swipe Left -> Next card
      _animateSwipe(endOffset: const Offset(-600, 50), rotation: -0.15).then((
        _,
      ) {
        notifier.nextCard();
        _resetCardPosition();
      });
    } else {
      // Snap back to center
      _animateSnapBack();
    }
  }

  Future<void> _animateSwipe({
    required Offset endOffset,
    required double rotation,
  }) {
    _swipeAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: endOffset,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));

    _rotationAnimation = Tween<double>(
      begin: _dragOffset.dx / 1000,
      end: rotation,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));

    _swipeController.addListener(_updateDragOffset);
    return _swipeController.forward(from: 0.0);
  }

  void _updateDragOffset() {
    setState(() {
      _dragOffset = _swipeAnimation.value;
    });
  }

  void _resetCardPosition() {
    _swipeController.removeListener(_updateDragOffset);
    _swipeController.reset();
    setState(() {
      _dragOffset = Offset.zero;
      _isFlipped = false;
      _flipRotation = 0.0;
    });
  }

  Future<void> _animateSnapBack() {
    _swipeAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _swipeController, curve: Curves.elasticOut),
        );

    _rotationAnimation = Tween<double>(begin: _dragOffset.dx / 1000, end: 0.0)
        .animate(
          CurvedAnimation(parent: _swipeController, curve: Curves.elasticOut),
        );

    _swipeController.addListener(_updateDragOffset);
    return _swipeController.forward(from: 0.0).then((_) {
      _swipeController.removeListener(_updateDragOffset);
      _swipeController.reset();
    });
  }

  void _toggleFlip() {
    setState(() {
      _isFlipped = !_isFlipped;
      _flipRotation = _isFlipped ? pi : 0.0;
    });
  }

  void _showAddCardSheet(
    BuildContext context,
    LoveStoryTheme theme,
    TopicCardsController notifier,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (ctx) => AddTopicCardSheet(
        theme: theme,
        notifier: notifier,
        selectableCategories: _categories
            .where((c) => c != 'All' && c != 'Favorites')
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;
    final cardsState = ref.watch(topicCardsControllerProvider);
    final cardsNotifier = ref.read(topicCardsControllerProvider.notifier);
    final activeDeck = cardsState.activeDeck;
    final activeIndex = cardsState.currentIndex;

    final isDeckEmpty = activeDeck.isEmpty;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Topic Cards',
          style: AppTypography.cormorant(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: theme.textColor,
            ),
            onPressed: () => _showAddCardSheet(context, theme, cardsNotifier),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Categories scrolling tab bar
              Container(
                height: 48,
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (ctx, i) {
                    final cat = _categories[i];
                    final isSelected = cardsState.activeCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        onTap: () {
                          cardsNotifier.setCategory(cat);
                          setState(() {
                            _isFlipped = false;
                            _flipRotation = 0.0;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.accentColor
                                : theme.textColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? theme.accentColor
                                  : theme.textColor.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              cat,
                              style: AppTypography.caption(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : theme.textColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Main deck view area
              Expanded(
                child: isDeckEmpty
                    ? Center(
                        child: TopicCardsEmptyState(
                          theme: theme,
                          activeCategory: cardsState.activeCategory,
                          onAddCard: () =>
                              _showAddCardSheet(context, theme, cardsNotifier),
                        ),
                      )
                    : TopicCardDeck(
                        deck: activeDeck,
                        index: activeIndex,
                        theme: theme,
                        notifier: cardsNotifier,
                        dragOffset: _dragOffset,
                        isSwipeAnimating: _swipeController.isAnimating,
                        rotationAnimation: _rotationAnimation,
                        flipRotation: _flipRotation,
                        onHorizontalDragUpdate: _onHorizontalDragUpdate,
                        onHorizontalDragEnd: (details) =>
                            _onHorizontalDragEnd(details, cardsNotifier),
                        onTap: _toggleFlip,
                      ),
              ),

              // Bottom control actions
              if (!isDeckEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 24,
                    top: 16,
                    left: 24,
                    right: 24,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Previous Button
                      TopicCardRoundButton(
                        icon: Icons.skip_previous_rounded,
                        color: theme.textColor.withValues(alpha: 0.1),
                        iconColor: theme.textColor,
                        theme: theme,
                        onPressed: () {
                          cardsNotifier.previousCard();
                          setState(() {
                            _isFlipped = false;
                            _flipRotation = 0.0;
                          });
                        },
                      ),

                      // Shuffle Button
                      TopicCardRoundButton(
                        icon: Icons.shuffle_rounded,
                        color: theme.textColor.withValues(alpha: 0.1),
                        iconColor: theme.textColor,
                        theme: theme,
                        onPressed: () {
                          cardsNotifier.shuffleDeck();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Deck Shuffled! 🎲'),
                              duration: Duration(milliseconds: 800),
                            ),
                          );
                        },
                      ),

                      // Next Button
                      TopicCardRoundButton(
                        icon: Icons.skip_next_rounded,
                        color: theme.accentColor,
                        iconColor: Colors.white,
                        theme: theme,
                        onPressed: () {
                          cardsNotifier.nextCard();
                          setState(() {
                            _isFlipped = false;
                            _flipRotation = 0.0;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
