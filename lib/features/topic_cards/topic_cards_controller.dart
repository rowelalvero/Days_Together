import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:days_together/core/riverpod/supabase_lifecycle_notifier.dart';
import 'package:days_together/features/topic_cards/topic_cards_state.dart';
import 'package:days_together/models/topic_card_model.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:days_together/services/realtime_subscription_manager.dart';
import 'package:days_together/services/recent_activity_service.dart';

/// Riverpod port of `TopicCardsProvider` (Phase 6a of the architecture
/// migration). One of the two providers (with `DailyMoodController`) that
/// bypass `SupabaseLifecycleNotifier`'s single-table `initRealtime()`/
/// `onRealtimeData()` default: this controller overrides [initRealtime]/
/// [disposeRealtime] directly to run two independent
/// `RealtimeSubscriptionManager` subscriptions (`topic_cards`,
/// `topic_card_likes`), exactly as the original did. [onRealtimeData] stays
/// a no-op, matching the original's own comment that it's "handled by
/// overriding initRealtime due to multiple tables."
class TopicCardsController extends Notifier<TopicCardsState> with SupabaseLifecycleNotifier<TopicCardsState> {
  static const String _customCardsKey = 'topic_cards_custom';
  static const String _likedCardIdsKey = 'topic_cards_liked_ids';
  static const String _pendingLikesKey = 'topic_cards_pending_likes';

  StreamSubscription? _syncCardsSub;
  StreamSubscription? _syncLikesSub;
  bool _isSyncingLikes = false;
  final Set<String> _localMutations = {};

  @override
  String get tableName => 'topic_cards';

  @override
  TopicCardsState build() {
    initSessionLifecycle();
    ref.onDispose(() {
      _syncCardsSub?.cancel();
      _syncLikesSub?.cancel();
    });
    _loadFromCache();
    return const TopicCardsState();
  }

  int _clampedIndex(List<TopicCard> deck, int desired) {
    if (desired >= deck.length) return 0;
    return desired;
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final likedList = prefs.getStringList(_likedCardIdsKey);
      final likedCardIds = likedList != null ? likedList.toSet() : <String>{};

      List<TopicCard> customCards = [];
      final customJson = prefs.getString(_customCardsKey);
      if (customJson != null) {
        final decoded = jsonDecode(customJson) as List;
        customCards = decoded.map((json) => TopicCard.fromJson(json)).toList();
      }

      Map<String, bool> pendingLikes = {};
      final pendingJson = prefs.getString(_pendingLikesKey);
      if (pendingJson != null) {
        final decoded = jsonDecode(pendingJson) as Map<String, dynamic>;
        pendingLikes = decoded.map((k, v) => MapEntry(k, v as bool));
      }

      if (!ref.mounted) return;
      state = state.copyWith(
        likedCardIds: likedCardIds,
        customCards: customCards,
        pendingLikes: pendingLikes,
        isLoading: false,
        currentIndex: 0,
      );
    } catch (e, st) {
      debugPrint('TopicCardsController._loadFromCache failed: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, currentIndex: 0);
    }
  }

  @override
  Future<void> purgeCache() async {
    state = state.copyWith(
      customCards: [],
      likedCardIds: {},
      partnerLikedCardIds: {},
      pendingLikes: {},
      isLoading: false,
      currentIndex: 0,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_customCardsKey);
      await prefs.remove(_likedCardIdsKey);
      await prefs.remove(_pendingLikesKey);
    } catch (e) {
      debugPrint('TopicCardsController.purgeCache error: $e');
    }
  }

  @override
  Future<void> syncInitialData() async {
    if (coupleId == null) return;
    try {
      final List<dynamic> cardsRes =
          await Supabase.instance.client.from('topic_cards').select().eq('couple_id', coupleId!);
      final parsedCards = cardsRes.map((data) {
        return TopicCard(
          id: data['id'] as String,
          category: data['category'] ?? '',
          question: data['question'] ?? '',
          isCustom: true,
          isLiked: false,
        );
      }).toList();

      final List<dynamic> likesRes =
          await Supabase.instance.client.from('topic_card_likes').select().eq('couple_id', coupleId!);
      final myLikes = <String>{};
      final partnerLikes = <String>{};
      for (final data in likesRes) {
        final cardId = data['card_id'] as String? ?? '';
        final likedByUserId = data['user_id'] as String? ?? '';
        final isLikedVal = data['is_liked'] as bool? ?? false;
        if (isLikedVal) {
          if (likedByUserId == sessionUserId) {
            myLikes.add(cardId);
          } else {
            partnerLikes.add(cardId);
          }
        }
      }

      if (!ref.mounted) return;
      state = state.copyWith(
        customCards: parsedCards,
        likedCardIds: myLikes,
        partnerLikedCardIds: partnerLikes,
        currentIndex: 0,
      );
      await _saveCustomCards();
      await _saveLikedCardIds();
    } catch (e) {
      debugPrint('TopicCardsController.syncInitialData error: $e');
    }
  }

  @override
  void initRealtime() {
    if (coupleId == null || sessionUserId == null) return;
    state = state.copyWith(isLoading: true);

    Future.delayed(const Duration(seconds: 5), () {
      if (!ref.mounted) return;
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    });

    _syncCardsSub?.cancel();
    _syncCardsSub = RealtimeSubscriptionManager.instance.getStream(tableName: 'topic_cards', coupleId: coupleId!).listen(
      (dataList) {
        if (!ref.mounted) return;
        final newCustoms = <TopicCard>[];
        for (final data in dataList) {
          final docId = data['id'] as String;
          final isCustom = data['is_custom'] as bool? ?? false;
          if (isCustom) {
            newCustoms.add(
              TopicCard(
                id: docId,
                category: data['category'] ?? '',
                question: data['question'] ?? '',
                isCustom: true,
                isLiked: state.likedCardIds.contains(docId),
              ),
            );
          }
        }

        if (!state.isLoading) {
          final added = newCustoms.where((inc) => !state.customCards.any((old) => old.id == inc.id)).toList();
          for (final card in added) {
            if (_localMutations.contains(card.id)) {
              _localMutations.remove(card.id);
              continue;
            }
            RecentActivityService.instance.logActivity(
              activityType: 'created',
              title: 'Partner added custom card 🎴',
              description: 'Added: "${card.question}"',
              icon: '🎴',
              referenceId: card.id,
              route: 'topic_cards',
            );
          }
        }

        state = state.copyWith(
          customCards: newCustoms,
          isLoading: false,
          currentIndex: _clampedIndex(_deckFor(state.copyWith(customCards: newCustoms)), state.currentIndex),
        );
        _persistLocalOnly();
      },
      onError: (err) {
        debugPrint('TopicCardsController: Supabase cards sync error: $err');
        _loadFromCache();
      },
    );

    _syncLikesSub?.cancel();
    _syncLikesSub =
        RealtimeSubscriptionManager.instance.getStream(tableName: 'topic_card_likes', coupleId: coupleId!).listen(
      (dataList) {
        if (!ref.mounted) return;
        final newLikes = <String>{};
        final newPartnerLikes = <String>{};
        for (final data in dataList) {
          final cardId = data['card_id'] as String;
          final likedByUserId = data['user_id'] as String;
          if (likedByUserId == sessionUserId) {
            newLikes.add(cardId);
          } else {
            newPartnerLikes.add(cardId);
          }
        }

        if (!state.isLoading) {
          final addedLikes = newPartnerLikes.difference(state.partnerLikedCardIds);
          for (final cardId in addedLikes) {
            final card = state.allCards.firstWhere(
              (c) => c.id == cardId,
              orElse: () => TopicCard(id: cardId, category: 'All', question: '', isCustom: false),
            );
            if (card.question.isNotEmpty) {
              RecentActivityService.instance.logActivity(
                activityType: 'updated',
                title: 'Partner liked card 💖',
                description: 'Liked: "${card.question}"',
                icon: '💖',
                referenceId: cardId,
                route: 'topic_cards',
              );
            }
          }
        }

        // Apply local pending overrides to maintain visual consistency.
        final effectiveLikes = {...newLikes};
        for (final entry in state.pendingLikes.entries) {
          if (entry.value) {
            effectiveLikes.add(entry.key);
          } else {
            effectiveLikes.remove(entry.key);
          }
        }

        state = state.copyWith(
          partnerLikedCardIds: newPartnerLikes,
          likedCardIds: effectiveLikes,
          currentIndex: _clampedIndex(
            _deckFor(state.copyWith(partnerLikedCardIds: newPartnerLikes, likedCardIds: effectiveLikes)),
            state.currentIndex,
          ),
        );
        _persistLocalOnly();
      },
      onError: (err) {
        debugPrint('TopicCardsController: Supabase likes sync error: $err');
      },
    );

    _syncPendingLikes();
  }

  List<TopicCard> _deckFor(TopicCardsState s) => s.activeDeck;

  @override
  void disposeRealtime() {
    _syncCardsSub?.cancel();
    _syncLikesSub?.cancel();
    _syncCardsSub = null;
    _syncLikesSub = null;
    super.disposeRealtime();
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {}

  @override
  void onRealtimeError(Object error) {}

  Future<void> setCategory(String category) async {
    final next = state.copyWith(activeCategory: category, currentIndex: 0);
    state = next.copyWith(currentIndex: _clampedIndex(next.activeDeck, 0));
  }

  void nextCard() {
    final deck = state.activeDeck;
    if (deck.isEmpty) return;
    state = state.copyWith(currentIndex: (state.currentIndex + 1) % deck.length);
  }

  void previousCard() {
    final deck = state.activeDeck;
    if (deck.isEmpty) return;
    state = state.copyWith(currentIndex: (state.currentIndex - 1 + deck.length) % deck.length);
  }

  void setCurrentIndex(int index) {
    final deck = state.activeDeck;
    if (deck.isEmpty) return;
    state = state.copyWith(currentIndex: index.clamp(0, deck.length - 1));
  }

  Future<void> shuffleDeck() async {
    if (state.activeDeck.isEmpty) return;
    // The original shuffles `_activeDeck` in place, a derived field there;
    // here activeDeck is a pure getter over customCards/likedCardIds/
    // activeCategory, none of which shuffling changes -- so a shuffle
    // cannot be expressed as a state change the same way. Deferred: no UI
    // reads this controller yet, so this is a known gap rather than a
    // silent behavior change; flagged in the roadmap for whoever converts
    // the topic-cards screen in Phase 6b.
  }

  Future<void> addCustomCard(String question, String category) async {
    final newCard = TopicCard(id: const Uuid().v4(), category: category, question: question, isCustom: true, isLiked: false);
    _localMutations.add(newCard.id);

    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('topic_cards').upsert({
          'id': newCard.id,
          'couple_id': coupleId,
          'category': category,
          'question': question,
          'is_custom': true,
          'liked_by_user_ids': [],
        });
        NotificationService().sendPartnerNotification(
          title: 'New Topic Card Added 🃏',
          body: 'Your partner added a custom topic card: "$question"',
          feature: 'topic_cards',
          itemId: newCard.id,
        );
      } catch (e) {
        debugPrint('TopicCardsController.addCustomCard Supabase error: $e');
        if (!ref.mounted) return;
        final next = state.copyWith(customCards: [...state.customCards, newCard]);
        state = next.copyWith(currentIndex: _clampedIndex(next.activeDeck, state.currentIndex));
        await _saveCustomCards();
      }
    } else {
      final next = state.copyWith(customCards: [...state.customCards, newCard]);
      state = next.copyWith(currentIndex: _clampedIndex(next.activeDeck, state.currentIndex));
      await _saveCustomCards();
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: 'Created custom card 🎴',
      description: 'Added: "$question"',
      icon: '🎴',
      referenceId: newCard.id,
      route: 'topic_cards',
    );
  }

  Future<void> deleteCard(String id) async {
    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('topic_cards').delete().eq('id', id);
        await Supabase.instance.client
            .from('topic_card_likes')
            .delete()
            .eq('couple_id', coupleId!)
            .eq('user_id', sessionUserId!)
            .eq('card_id', id);
      } catch (e) {
        debugPrint('TopicCardsController.deleteCard Supabase error: $e');
        if (!ref.mounted) return;
        await _removeCardLocally(id);
      }
    } else {
      await _removeCardLocally(id);
    }
  }

  Future<void> _removeCardLocally(String id) async {
    final likedCardIds = {...state.likedCardIds}..remove(id);
    final pendingLikes = {...state.pendingLikes}..remove(id);
    final next = state.copyWith(
      customCards: state.customCards.where((c) => c.id != id).toList(),
      likedCardIds: likedCardIds,
      pendingLikes: pendingLikes,
    );
    state = next.copyWith(currentIndex: _clampedIndex(next.activeDeck, state.currentIndex));
    await _saveCustomCards();
    await _saveLikedCardIds();
    await _savePendingLikes();
  }

  Future<void> toggleLikeCard(String id) async {
    final nextLiked = !state.likedCardIds.contains(id);

    final likedCardIds = {...state.likedCardIds};
    if (nextLiked) {
      likedCardIds.add(id);
      if (coupleId != null) {
        NotificationService().sendPartnerNotification(
          title: 'Topic Card Favorited 💖',
          body: 'Your partner favorited a topic card!',
          feature: 'topic_cards',
          itemId: id,
        );
      }
    } else {
      likedCardIds.remove(id);
    }
    state = state.copyWith(likedCardIds: likedCardIds);
    await _saveLikedCardIds();

    final pendingLikes = {...state.pendingLikes, id: nextLiked};
    state = state.copyWith(pendingLikes: pendingLikes);
    await _savePendingLikes();

    unawaited(_syncPendingLikes());

    if (nextLiked) {
      final card = state.allCards.firstWhere(
        (c) => c.id == id,
        orElse: () => TopicCard(id: id, category: 'All', question: '', isCustom: false),
      );
      await RecentActivityService.instance.logActivity(
        activityType: 'updated',
        title: 'Liked custom card 💖',
        description: 'Liked: "${card.question}"',
        icon: '💖',
        referenceId: id,
        route: 'topic_cards',
      );
    }
  }

  Future<void> _syncPendingLikes() async {
    if (_isSyncingLikes) return;
    if (coupleId == null || sessionUserId == null) return;
    if (state.pendingLikes.isEmpty) return;

    _isSyncingLikes = true;
    try {
      final completedIds = <String>[];
      for (final entry in List<MapEntry<String, bool>>.from(state.pendingLikes.entries)) {
        final cardId = entry.key;
        final targetLiked = entry.value;
        try {
          if (targetLiked) {
            await Supabase.instance.client.from('topic_card_likes').upsert({
              'couple_id': coupleId,
              'user_id': sessionUserId,
              'card_id': cardId,
            });
          } else {
            await Supabase.instance.client
                .from('topic_card_likes')
                .delete()
                .eq('couple_id', coupleId!)
                .eq('user_id', sessionUserId!)
                .eq('card_id', cardId);
          }
          completedIds.add(cardId);
        } catch (e) {
          debugPrint('TopicCardsController: Failed to sync pending like for $cardId: $e');
          break;
        }
      }

      if (completedIds.isNotEmpty && ref.mounted) {
        final pendingLikes = {...state.pendingLikes};
        for (final id in completedIds) {
          pendingLikes.remove(id);
        }
        state = state.copyWith(pendingLikes: pendingLikes);
        await _savePendingLikes();
      }
    } finally {
      _isSyncingLikes = false;
    }
  }

  Future<void> _saveCustomCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = state.customCards.map((c) => c.toJson()).toList();
      await prefs.setString(_customCardsKey, jsonEncode(serialized));
    } catch (e) {
      debugPrint('TopicCardsController._saveCustomCards failed: $e');
    }
  }

  Future<void> _saveLikedCardIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_likedCardIdsKey, state.likedCardIds.toList());
    } catch (e) {
      debugPrint('TopicCardsController._saveLikedCardIds failed: $e');
    }
  }

  Future<void> _savePendingLikes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingLikesKey, jsonEncode(state.pendingLikes));
    } catch (e) {
      debugPrint('TopicCardsController._savePendingLikes failed: $e');
    }
  }

  Future<void> _persistLocalOnly() async {
    await _saveCustomCards();
    await _saveLikedCardIds();
    await _savePendingLikes();
  }
}

final topicCardsControllerProvider = NotifierProvider.autoDispose<TopicCardsController, TopicCardsState>(
  TopicCardsController.new,
  dependencies: [coupleSessionProvider],
);
