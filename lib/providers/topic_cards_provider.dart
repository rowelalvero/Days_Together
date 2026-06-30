import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/services/supabase_sync_service.dart';
import 'package:uuid/uuid.dart';
import 'package:days_together/models/topic_card_model.dart';
import 'package:days_together/providers/relationship_provider.dart';

class TopicCardsProvider with ChangeNotifier {
  static const String _customCardsKey = 'topic_cards_custom';
  static const String _likedCardIdsKey = 'topic_cards_liked_ids';
  static const String _pendingLikesKey = 'topic_cards_pending_likes';

  List<TopicCard> _defaultCards = [];
  List<TopicCard> _customCards = [];
  Set<String> _likedCardIds = {};
  Map<String, bool> _pendingLikes = {};

  String _activeCategory = 'All';
  int _currentIndex = 0;
  List<TopicCard> _activeDeck = [];
  bool _isLoading = true;
  bool _disposed = false;

  String? _coupleId;
  String? _userId;
  StreamSubscription? _syncCardsSub;
  StreamSubscription? _syncLikesSub;
  bool _isSyncingLikes = false;

  List<TopicCard> get allCards {
    final List<TopicCard> combined = [];
    for (final card in _defaultCards) {
      combined.add(card.copyWith(isLiked: _likedCardIds.contains(card.id)));
    }
    for (final card in _customCards) {
      combined.add(card.copyWith(isLiked: _likedCardIds.contains(card.id)));
    }
    return combined;
  }

  List<TopicCard> get activeDeck => _activeDeck;
  String get activeCategory => _activeCategory;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;

  TopicCardsProvider() {
    _initializeDefaultCards();
    _loadData();
  }

  void updateRelationship(RelationshipProvider relationship) {
    if (_coupleId != relationship.coupleId || _userId != relationship.userId) {
      _coupleId = relationship.coupleId;
      _userId = relationship.userId;

      _syncCardsSub?.cancel();
      _syncCardsSub = null;
      _syncLikesSub?.cancel();
      _syncLikesSub = null;

      if (_coupleId != null && _userId != null && relationship.isFirebaseAvailable) {
        _initSupabaseSync();
      } else {
        _loadData();
      }
    }
  }

  void _initSupabaseSync() {
    if (_coupleId == null || _userId == null) return;
    _isLoading = true;
    if (!_disposed) notifyListeners();

    // Stream 1: Sync Custom Cards
    _syncCardsSub = SupabaseSyncService.instance.subscribeToCoupleData(
      tableName: 'topic_cards',
      coupleId: _coupleId!,
      onData: (dataList) {
      final List<TopicCard> newCustoms = [];

      for (final data in dataList) {
        final docId = data['id'] as String;
        final isCustom = data['is_custom'] as bool? ?? false;

        if (isCustom) {
          newCustoms.add(TopicCard(
            id: docId,
            category: data['category'] ?? '',
            question: data['question'] ?? '',
            isCustom: true,
            isLiked: _likedCardIds.contains(docId),
          ));
        }
      }

      _customCards = newCustoms;
      _isLoading = false;
      _updateActiveDeck();
      _persistLocalOnly();
      },
      onError: (err) {
        debugPrint('TopicCardsProvider: Supabase cards sync error: $err');
        _loadData();
      },
    );

    // Stream 2: Sync Liked Card IDs
    _syncLikesSub = Supabase.instance.client
        .from('topic_card_likes')
        .stream(primaryKey: ['id'])
        .eq('couple_id', _coupleId!)
        .listen((dataList) {
      final Set<String> newLikes = {};

      for (final data in dataList) {
        final cardId = data['card_id'] as String;
        final userId = data['user_id'] as String;

        if (userId == _userId) {
          newLikes.add(cardId);
        }
      }

      _likedCardIds = newLikes;

      // Apply local pending overrides to maintain visual consistency
      for (final entry in _pendingLikes.entries) {
        if (entry.value) {
          _likedCardIds.add(entry.key);
        } else {
          _likedCardIds.remove(entry.key);
        }
      }

      _updateActiveDeck();
      _persistLocalOnly();
    }, onError: (err) {
      debugPrint('TopicCardsProvider: Supabase likes sync error: $err');
    });

    // Run initial sync of offline/pending likes
    _syncPendingLikes();
  }

  void _initializeDefaultCards() {
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

    _defaultCards = defaultQuestions.map((item) {
      return TopicCard(
        id: item['id']!,
        category: item['cat']!,
        question: item['q']!,
        isCustom: false,
        isLiked: false,
      );
    }).toList();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    if (!_disposed) notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();

      final likedList = prefs.getStringList(_likedCardIdsKey);
      if (likedList != null) {
        _likedCardIds = likedList.toSet();
      }

      final customJson = prefs.getString(_customCardsKey);
      if (customJson != null) {
        final decoded = jsonDecode(customJson) as List;
        _customCards = decoded.map((json) => TopicCard.fromJson(json)).toList();
      } else {
        _customCards = [];
      }

      final pendingJson = prefs.getString(_pendingLikesKey);
      if (pendingJson != null) {
        final decoded = jsonDecode(pendingJson) as Map<String, dynamic>;
        _pendingLikes = decoded.map((k, v) => MapEntry(k, v as bool));
      } else {
        _pendingLikes = {};
      }
    } catch (e, st) {
      debugPrint('TopicCardsProvider._loadData failed: $e\n$st');
    } finally {
      _isLoading = false;
      _currentIndex = 0;
      _updateActiveDeck();
    }
  }

  void _updateActiveDeck() {
    final cards = allCards;
    if (_activeCategory == 'All') {
      _activeDeck = List.from(cards);
    } else if (_activeCategory == 'Favorites') {
      _activeDeck = cards.where((c) => c.isLiked).toList();
    } else {
      _activeDeck = cards.where((c) => c.category == _activeCategory).toList();
    }

    if (_currentIndex >= _activeDeck.length) {
      _currentIndex = 0;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> setCategory(String category) async {
    _activeCategory = category;
    _currentIndex = 0;
    _updateActiveDeck();
  }

  void nextCard() {
    if (_activeDeck.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _activeDeck.length;
    if (!_disposed) notifyListeners();
  }

  void previousCard() {
    if (_activeDeck.isEmpty) return;
    _currentIndex = (_currentIndex - 1 + _activeDeck.length) % _activeDeck.length;
    if (!_disposed) notifyListeners();
  }

  void setCurrentIndex(int index) {
    if (_activeDeck.isEmpty) return;
    _currentIndex = index.clamp(0, _activeDeck.length - 1);
    if (!_disposed) notifyListeners();
  }

  Future<void> shuffleDeck() async {
    if (_activeDeck.isEmpty) return;
    _activeDeck.shuffle();
    _currentIndex = 0;
    if (!_disposed) notifyListeners();
  }

  Future<void> addCustomCard(String question, String category) async {
    final newCard = TopicCard(
      id: const Uuid().v4(),
      category: category,
      question: question,
      isCustom: true,
      isLiked: false,
    );

    if (_coupleId != null) {
      try {
        await Supabase.instance.client
            .from('topic_cards')
            .upsert({
          'id': newCard.id,
          'couple_id': _coupleId,
          'category': category,
          'question': question,
          'is_custom': true,
          'liked_by_user_ids': [],
        });
      } catch (e) {
        debugPrint('TopicCardsProvider.addCustomCard Supabase error: $e');
        _customCards.add(newCard);
        await _saveCustomCards();
        _updateActiveDeck();
      }
    } else {
      _customCards.add(newCard);
      await _saveCustomCards();
      _updateActiveDeck();
    }
  }

  Future<void> deleteCard(String id) async {
    if (_coupleId != null) {
      try {
        await Supabase.instance.client
            .from('topic_cards')
            .delete()
            .eq('id', id);

        // Clean up own like for the deleted card if exists
        await Supabase.instance.client
            .from('topic_card_likes')
            .delete()
            .eq('couple_id', _coupleId!)
            .eq('user_id', _userId!)
            .eq('card_id', id);
      } catch (e) {
        debugPrint('TopicCardsProvider.deleteCard Supabase error: $e');
        _customCards.removeWhere((c) => c.id == id);
        _likedCardIds.remove(id);
        _pendingLikes.remove(id);
        await _saveCustomCards();
        await _saveLikedCardIds();
        await _savePendingLikes();
        _updateActiveDeck();
      }
    } else {
      _customCards.removeWhere((c) => c.id == id);
      _likedCardIds.remove(id);
      _pendingLikes.remove(id);
      await _saveCustomCards();
      await _saveLikedCardIds();
      await _savePendingLikes();
      _updateActiveDeck();
    }
  }

  Future<void> toggleLikeCard(String id) async {
    final nextLiked = !_likedCardIds.contains(id);

    // 1. Optimistic UI update
    if (nextLiked) {
      _likedCardIds.add(id);
    } else {
      _likedCardIds.remove(id);
    }
    _updateActiveDeck();
    _saveLikedCardIds();

    // 2. Queue the pending operation
    _pendingLikes[id] = nextLiked;
    await _savePendingLikes();

    // 3. Trigger async sync in background
    _syncPendingLikes();
  }

  Future<void> _syncPendingLikes() async {
    if (_isSyncingLikes) return;
    if (_coupleId == null || _userId == null) return;
    if (_pendingLikes.isEmpty) return;

    _isSyncingLikes = true;

    try {
      final List<String> completedIds = [];
      for (final entry in List.from(_pendingLikes.entries)) {
        final cardId = entry.key as String;
        final targetLiked = entry.value as bool;

        try {
          if (targetLiked) {
            // Idempotent upsert
            await Supabase.instance.client.from('topic_card_likes').upsert({
              'couple_id': _coupleId,
              'user_id': _userId,
              'card_id': cardId,
            });
          } else {
            // Delete matching row
            await Supabase.instance.client
                .from('topic_card_likes')
                .delete()
                .eq('couple_id', _coupleId!)
                .eq('user_id', _userId!)
                .eq('card_id', cardId);
          }
          completedIds.add(cardId);
        } catch (e) {
          debugPrint('TopicCardsProvider: Failed to sync pending like for $cardId: $e');
          break; // Stop and retry later if network fails
        }
      }

      for (final id in completedIds) {
        _pendingLikes.remove(id);
      }
      await _savePendingLikes();
    } finally {
      _isSyncingLikes = false;
    }
  }

  Future<void> _saveCustomCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = _customCards.map((c) => c.toJson()).toList();
      await prefs.setString(_customCardsKey, jsonEncode(serialized));
    } catch (e) {
      debugPrint('TopicCardsProvider._saveCustomCards failed: $e');
    }
  }

  Future<void> _saveLikedCardIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_likedCardIdsKey, _likedCardIds.toList());
    } catch (e) {
      debugPrint('TopicCardsProvider._saveLikedCardIds failed: $e');
    }
  }

  Future<void> _savePendingLikes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingLikesKey, jsonEncode(_pendingLikes));
    } catch (e) {
      debugPrint('TopicCardsProvider._savePendingLikes failed: $e');
    }
  }

  Future<void> _persistLocalOnly() async {
    await _saveCustomCards();
    await _saveLikedCardIds();
    await _savePendingLikes();
  }

  @override
  void dispose() {
    _syncCardsSub?.cancel();
    _syncLikesSub?.cancel();
    _disposed = true;
    super.dispose();
  }
}
