import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:share_plus/share_plus.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/topic_cards_provider.dart';
import 'package:days_together/models/topic_card_model.dart';
import 'package:days_together/widgets/glass_container.dart';

class TopicCardsScreen extends StatefulWidget {
  const TopicCardsScreen({super.key});

  @override
  State<TopicCardsScreen> createState() => _TopicCardsScreenState();
}

class _TopicCardsScreenState extends State<TopicCardsScreen>
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
    TopicCardsProvider provider,
  ) {
    final threshold = 120.0;
    if (_dragOffset.dx > threshold) {
      // Swipe Right -> Go to next question (or previous, depending on preference)
      _animateSwipe(endOffset: const Offset(600, 50), rotation: 0.15).then((_) {
        provider.previousCard();
        _resetCardPosition();
      });
    } else if (_dragOffset.dx < -threshold) {
      // Swipe Left -> Next card
      _animateSwipe(endOffset: const Offset(-600, 50), rotation: -0.15).then((
        _,
      ) {
        provider.nextCard();
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

  void _showAddCardDialog(
    BuildContext context,
    LoveStoryTheme theme,
    TopicCardsProvider provider,
  ) {
    final formKey = GlobalKey<FormState>();
    final questionController = TextEditingController();
    String selectedCategory =
        _categories[1]; // default to first real category (Deep)

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: GlassContainer(
                borderRadius: 24,
                opacity: 0.15,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add Custom Card',
                            style: AppTypography.sectionHeader(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: theme.textColor,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: theme.textColor),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'CATEGORY',
                        style: AppTypography.caption(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.textColor.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: theme.textColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.textColor.withValues(alpha: 0.1),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            dropdownColor: theme.backgroundColor,
                            style: AppTypography.body(
                              color: theme.textColor,
                              fontWeight: FontWeight.bold,
                            ),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: theme.accentColor,
                            ),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  selectedCategory = val;
                                });
                              }
                            },
                            items: _categories
                                .where((c) => c != 'All' && c != 'Favorites')
                                .map((cat) {
                                  return DropdownMenuItem<String>(
                                    value: cat,
                                    child: Text(cat),
                                  );
                                })
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'YOUR QUESTION / TOPIC PROMPT',
                        style: AppTypography.caption(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.textColor.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: questionController,
                        maxLines: 4,
                        style: AppTypography.body(color: theme.textColor),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please write a prompt!';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText:
                              'e.g., What is a dream you have that you are too scared to pursue?',
                          hintStyle: AppTypography.body(
                            color: theme.textColor.withValues(alpha: 0.4),
                          ),
                          filled: true,
                          fillColor: theme.textColor.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.textColor.withValues(alpha: 0.1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.textColor.withValues(alpha: 0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.accentColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              provider.addCustomCard(
                                questionController.text.trim(),
                                selectedCategory,
                              );
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Custom topic added successfully! 🃏',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.accentColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          child: Text(
                            'Add to Deck',
                            style: AppTypography.body(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final cardsProvider = context.watch<TopicCardsProvider>();
    final activeDeck = cardsProvider.activeDeck;
    final activeIndex = cardsProvider.currentIndex;

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
            onPressed: () => _showAddCardDialog(context, theme, cardsProvider),
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
                    final isSelected = cardsProvider.activeCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        onTap: () {
                          cardsProvider.setCategory(cat);
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
                    ? Center(child: _buildEmptyState(theme, cardsProvider))
                    : _buildCardDeck(
                        activeDeck,
                        activeIndex,
                        theme,
                        cardsProvider,
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
                      _buildRoundButton(
                        icon: Icons.skip_previous_rounded,
                        color: theme.textColor.withValues(alpha: 0.1),
                        iconColor: theme.textColor,
                        theme: theme,
                        onPressed: () {
                          cardsProvider.previousCard();
                          setState(() {
                            _isFlipped = false;
                            _flipRotation = 0.0;
                          });
                        },
                      ),

                      // Shuffle Button
                      _buildRoundButton(
                        icon: Icons.shuffle_rounded,
                        color: theme.textColor.withValues(alpha: 0.1),
                        iconColor: theme.textColor,
                        theme: theme,
                        onPressed: () {
                          cardsProvider.shuffleDeck();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Deck Shuffled! 🎲'),
                              duration: Duration(milliseconds: 800),
                            ),
                          );
                        },
                      ),

                      // Next Button
                      _buildRoundButton(
                        icon: Icons.skip_next_rounded,
                        color: theme.accentColor,
                        iconColor: Colors.white,
                        theme: theme,
                        onPressed: () {
                          cardsProvider.nextCard();
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

  Widget _buildEmptyState(LoveStoryTheme theme, TopicCardsProvider provider) {
    final isFav = provider.activeCategory == 'Favorites';
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
            isFav ? 'No Favorited Topics' : 'No custom topics yet',
            style: AppTypography.sectionHeader(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            isFav
                ? 'Tap the heart icon on any card back to save deep prompts for later discussion!'
                : 'Fill this category with custom prompts tailored to your relationship!',
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
              onPressed: () => _showAddCardDialog(context, theme, provider),
              icon: const Icon(Icons.add),
              label: const Text('Add Custom Topic'),
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

  Widget _buildCardDeck(
    List<TopicCard> deck,
    int index,
    LoveStoryTheme theme,
    TopicCardsProvider provider,
  ) {
    final double cardWidth = 300;
    final double cardHeight = 440;

    // We build a stack representing the deck.
    // The top card is interactive.
    // Behind it we render 1 or 2 visual placeholders of other cards to create a deck effect.
    return Center(
      child: SizedBox(
        width: cardWidth + 50,
        height: cardHeight + 40,
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
                    child: _buildStaticCardCover(
                      theme,
                      deck[(index + 2) % deck.length],
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
                    child: _buildStaticCardCover(
                      theme,
                      deck[(index + 1) % deck.length],
                    ),
                  ),
                ),
              ),

            // Top draggable & interactive card
            Positioned(
              bottom: 25,
              child: GestureDetector(
                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                onHorizontalDragEnd: (details) =>
                    _onHorizontalDragEnd(details, provider),
                onTap: _toggleFlip,
                child: Transform.translate(
                  offset: _dragOffset,
                  child: Transform.rotate(
                    angle: _swipeController.isAnimating
                        ? _rotationAnimation.value
                        : (_dragOffset.dx / 1000).clamp(-0.15, 0.15),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: _flipRotation),
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
                              ? _buildCardBack(theme, deck[index], provider)
                              : _buildCardFront(theme, deck[index]),
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

  Widget _buildStaticCardCover(LoveStoryTheme theme, TopicCard card) {
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

  Widget _buildCardFront(LoveStoryTheme theme, TopicCard card) {
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
                    style: AppTypography.sectionHeader(
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

  Widget _buildCardBack(
    LoveStoryTheme theme,
    TopicCard card,
    TopicCardsProvider provider,
  ) {
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
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: theme.backgroundColor,
                              title: Text(
                                'Delete Card?',
                                style: AppTypography.cardTitle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.textColor,
                                ),
                              ),
                              content: Text(
                                'Are you sure you want to delete this custom topic card?',
                                style: AppTypography.body(
                                  color: theme.textColor.withValues(
                                    alpha: 0.8,
                                  ),
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
                                    provider.deleteCard(card.id);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const Spacer(),

                // Question Text
                Text(
                  card.question,
                  textAlign: TextAlign.center,
                  style: AppTypography.sectionHeader(
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
                        provider.toggleLikeCard(card.id);
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

  Widget _buildRoundButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required dynamic theme,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.textColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 26),
      ),
    );
  }
}
