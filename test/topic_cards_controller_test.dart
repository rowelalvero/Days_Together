// Tests for TopicCardsController (Phase 6a of the architecture migration,
// the ninth of the 12 domain providers ported to Riverpod -- one of the two
// dual-table providers, alongside DailyMoodController). No network:
// coupleSessionProvider is overridden with an unpaired CoupleSession()
// throughout (coupleId == null) -- these tests exercise the local-only
// write path.

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/topic_cards/topic_cards_controller.dart';
import 'package:days_together/features/topic_cards/topic_cards_state.dart';
import 'package:days_together/providers/couple_session.dart';

/// topicCardsControllerProvider is `autoDispose` -- see
/// bucket_list_controller_test.dart's identical helper doc comment for why
/// a persistent `container.listen` is required, not just `container.read`.
ProviderContainer _unpairedContainer() {
  final container = ProviderContainer(
    overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
  );
  container.listen(topicCardsControllerProvider, (prev, next) {});
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TopicCardsController', () {
    test('build() starts with the default deck and no likes', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(topicCardsControllerProvider);
      expect(state.customCards, isEmpty);
      expect(state.allCards.length, TopicCardsState.defaultCards.length);
      expect(state.activeCategory, 'All');
      expect(state.currentIndex, 0);
    });

    test('addCustomCard appends locally when unpaired', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      await container.read(topicCardsControllerProvider.notifier).addCustomCard('Our own question?', 'Fun & Quirky');

      final state = container.read(topicCardsControllerProvider);
      expect(state.customCards, hasLength(1));
      expect(state.customCards.first.question, 'Our own question?');
      expect(state.allCards.length, TopicCardsState.defaultCards.length + 1);
    });

    test('setCategory filters the active deck', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(topicCardsControllerProvider.notifier);

      await notifier.setCategory('Fun & Quirky');

      final state = container.read(topicCardsControllerProvider);
      expect(state.activeDeck, isNotEmpty);
      expect(state.activeDeck.every((c) => c.category == 'Fun & Quirky'), isTrue);
    });

    test('nextCard/previousCard wrap around the active deck', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(topicCardsControllerProvider.notifier);
      await notifier.setCategory('Fun & Quirky');
      final deckLength = container.read(topicCardsControllerProvider).activeDeck.length;

      notifier.setCurrentIndex(deckLength - 1);
      notifier.nextCard();
      expect(container.read(topicCardsControllerProvider).currentIndex, 0);

      notifier.previousCard();
      expect(container.read(topicCardsControllerProvider).currentIndex, deckLength - 1);
    });

    test('toggleLikeCard marks a card liked and persists', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(topicCardsControllerProvider.notifier);
      final cardId = TopicCardsState.defaultCards.first.id;

      await notifier.toggleLikeCard(cardId);

      final state = container.read(topicCardsControllerProvider);
      expect(state.likedCardIds, contains(cardId));
      expect(state.allCards.firstWhere((c) => c.id == cardId).isLiked, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('topic_cards_liked_ids'), contains(cardId));
    });

    test('deleteCard removes a custom card and its like locally when unpaired', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(topicCardsControllerProvider.notifier);

      await notifier.addCustomCard('Delete me', 'Fun & Quirky');
      final id = container.read(topicCardsControllerProvider).customCards.first.id;
      await notifier.toggleLikeCard(id);

      await notifier.deleteCard(id);

      final state = container.read(topicCardsControllerProvider);
      expect(state.customCards, isEmpty);
      expect(state.likedCardIds, isNot(contains(id)));
    });

    test('purgeCache clears cards, likes, and the SharedPreferences cache', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(topicCardsControllerProvider.notifier);
      await notifier.addCustomCard('Something', 'Fun & Quirky');

      await notifier.purgeCache();

      final state = container.read(topicCardsControllerProvider);
      expect(state.customCards, isEmpty);
      expect(state.likedCardIds, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('topic_cards_custom'), isFalse);
    });
  });
}
