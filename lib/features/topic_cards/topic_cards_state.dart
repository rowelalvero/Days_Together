import 'package:days_together/models/topic_card_model.dart';

/// State for `TopicCardsController` (Phase 6a of the architecture
/// migration) -- a direct Riverpod port of `TopicCardsProvider`'s fields.
/// `defaultCards` is a fixed constant deck (never mutated), kept as a
/// static list here rather than duplicated per-instance, matching the
/// original's `_initializeDefaultCards()`-computed-once field.
class TopicCardsState {
  final List<TopicCard> customCards;
  final Set<String> likedCardIds;
  final Set<String> partnerLikedCardIds;
  final Map<String, bool> pendingLikes;
  final bool isLoading;
  final int currentIndex;
  final String activeCategory;

  const TopicCardsState({
    this.customCards = const [],
    this.likedCardIds = const {},
    this.partnerLikedCardIds = const {},
    this.pendingLikes = const {},
    this.isLoading = true,
    this.currentIndex = 0,
    this.activeCategory = 'All',
  });

  TopicCardsState copyWith({
    List<TopicCard>? customCards,
    Set<String>? likedCardIds,
    Set<String>? partnerLikedCardIds,
    Map<String, bool>? pendingLikes,
    bool? isLoading,
    int? currentIndex,
    String? activeCategory,
  }) {
    return TopicCardsState(
      customCards: customCards ?? this.customCards,
      likedCardIds: likedCardIds ?? this.likedCardIds,
      partnerLikedCardIds: partnerLikedCardIds ?? this.partnerLikedCardIds,
      pendingLikes: pendingLikes ?? this.pendingLikes,
      isLoading: isLoading ?? this.isLoading,
      currentIndex: currentIndex ?? this.currentIndex,
      activeCategory: activeCategory ?? this.activeCategory,
    );
  }

  List<TopicCard> get allCards {
    final combined = <TopicCard>[];
    for (final card in defaultCards) {
      combined.add(card.copyWith(isLiked: likedCardIds.contains(card.id)));
    }
    for (final card in customCards) {
      combined.add(card.copyWith(isLiked: likedCardIds.contains(card.id)));
    }
    return combined;
  }

  List<TopicCard> get activeDeck {
    final cards = allCards;
    List<TopicCard> deck;
    if (activeCategory == 'All') {
      deck = List.from(cards);
    } else if (activeCategory == 'Favorites') {
      deck = cards.where((c) => c.isLiked).toList();
    } else {
      deck = cards.where((c) => c.category == activeCategory).toList();
    }
    return deck;
  }

  static final List<TopicCard> defaultCards = _buildDefaultCards();

  static List<TopicCard> _buildDefaultCards() {
    final defaultQuestions = [
      {'id': 'd1', 'cat': 'Deep Conversations', 'q': 'What is a memory with me that always makes you smile, no matter how tough your day is?'},
      {'id': 'd2', 'cat': 'Deep Conversations', 'q': 'If you could change one event in your past to make our lives better today, what would it be?'},
      {'id': 'd3', 'cat': 'Deep Conversations', 'q': 'What is your biggest fear about our relationship, and how can we work through it together?'},
      {'id': 'd4', 'cat': 'Deep Conversations', 'q': 'What does unconditional love mean to you, and do you feel it between us?'},
      {'id': 'd5', 'cat': 'Deep Conversations', 'q': "Is there a secret or a worry you've been holding onto that you feel ready to share with me?"},
      {'id': 'd6', 'cat': 'Deep Conversations', 'q': 'When was the moment you realized you were falling in love with me?'},
      {'id': 'd7', 'cat': 'Deep Conversations', 'q': 'What is something I did recently that made you feel incredibly appreciated and loved?'},
      {'id': 'd8', 'cat': 'Deep Conversations', 'q': 'If our relationship was a book title, what would it be and why?'},
      {'id': 'd9', 'cat': 'Deep Conversations', 'q': 'What is one thing about how your parents loved each other that you want to replicate or avoid?'},
      {'id': 'd10', 'cat': 'Deep Conversations', 'q': "What is the hardest thing we've gone through together, and how did it change us?"},
      {'id': 'f1', 'cat': 'Fun & Quirky', 'q': 'If we were characters in a movie, who would we be and who would survive a zombie apocalypse?'},
      {'id': 'f2', 'cat': 'Fun & Quirky', 'q': 'What is the most ridiculous or funny first impression you had of me?'},
      {'id': 'f3', 'cat': 'Fun & Quirky', 'q': 'If we won a million dollars today, what is the first silly thing we would buy?'},
      {'id': 'f4', 'cat': 'Fun & Quirky', 'q': "What is a secret talent or weird habit of yours that you haven't fully shown me yet?"},
      {'id': 'f5', 'cat': 'Fun & Quirky', 'q': 'If we could switch bodies for a single day, what is the first thing you would do?'},
      {'id': 'f6', 'cat': 'Fun & Quirky', 'q': 'What is a song that perfectly summarizes how chaotic or beautiful our love is?'},
      {'id': 'f7', 'cat': 'Fun & Quirky', 'q': 'If we had to live in a fictional universe (e.g., Harry Potter, Marvel) for a year, which one would it be?'},
      {'id': 'f8', 'cat': 'Fun & Quirky', 'q': 'Who is the better driver, and who is the backseat driver who thinks they are better?'},
      {'id': 'f9', 'cat': 'Fun & Quirky', 'q': 'What is our absolute worst inside joke that nobody else would find funny?'},
      {'id': 'u1', 'cat': 'Future & Dreams', 'q': 'Where do you see us living in ten years, and what does our ideal morning routine look like?'},
      {'id': 'u2', 'cat': 'Future & Dreams', 'q': 'What is a dream or goal you have for yourself that you want me to help you achieve?'},
      {'id': 'u3', 'cat': 'Future & Dreams', 'q': 'How do you picture our lives when we are old and grey?'},
      {'id': 'u4', 'cat': 'Future & Dreams', 'q': "What is one adventure or travel destination we haven't been to yet that is a must-do for us?"},
      {'id': 'u5', 'cat': 'Future & Dreams', 'q': 'What are your hopes for our home together in the future?'},
      {'id': 'u6', 'cat': 'Future & Dreams', 'q': 'If we could open any business together, what would it be and who would be the boss?'},
      {'id': 'u7', 'cat': 'Future & Dreams', 'q': 'What is a major life milestone you are most excited to share with me?'},
      {'id': 'u8', 'cat': 'Future & Dreams', 'q': 'How do you think our relationship will grow or adapt over the next 5 years?'},
      {'id': 'l1', 'cat': 'Love & Romance', 'q': 'What is your favorite way to receive affection from me (words, touch, gifts, quality time, acts of service)?'},
      {'id': 'l2', 'cat': 'Love & Romance', 'q': "What is a romantic gesture you've always wanted to experience but haven't told me yet?"},
      {'id': 'l3', 'cat': 'Love & Romance', 'q': 'How has your definition of love changed since we first met?'},
      {'id': 'l4', 'cat': 'Love & Romance', 'q': "What was the sweetest thing you think I've ever done for you?"},
      {'id': 'l5', 'cat': 'Love & Romance', 'q': 'If you could freeze a single moment we shared together forever, which one would it be?'},
      {'id': 'l6', 'cat': 'Love & Romance', 'q': 'What is a small, everyday habit of mine that makes you feel deeply loved?'},
      {'id': 'l7', 'cat': 'Love & Romance', 'q': "What was your favorite date we've ever been on, and why does it stand out?"},
      {'id': 'l8', 'cat': 'Love & Romance', 'q': 'If you could dedicate any love poem or quote to me, which one describes us best?'},
      {'id': 'i1', 'cat': 'Intimacy & Bonding', 'q': 'What makes you feel closest and most connected to me?'},
      {'id': 'i2', 'cat': 'Intimacy & Bonding', 'q': "Is there a way we can improve our emotional or physical intimacy that you'd like to explore?"},
      {'id': 'i3', 'cat': 'Intimacy & Bonding', 'q': 'What is a subtle look, touch, or word of mine that always gets your heart racing?'},
      {'id': 'i4', 'cat': 'Intimacy & Bonding', 'q': 'What is something we do together that makes you feel completely safe and secure?'},
      {'id': 'i5', 'cat': 'Intimacy & Bonding', 'q': 'How can I support you better during times when you feel overwhelmed or emotionally drained?'},
      {'id': 'i6', 'cat': 'Intimacy & Bonding', 'q': "What is your favorite way to reconnect after we've had a busy week apart?"},
      {'id': 'i7', 'cat': 'Intimacy & Bonding', 'q': 'What are some ways we can make our physical touch feel more intentional and loving?'},
    ];

    return defaultQuestions.map((item) {
      return TopicCard(
        id: item['id']!,
        category: item['cat']!,
        question: item['q']!,
        isCustom: false,
        isLiked: false,
      );
    }).toList();
  }
}
