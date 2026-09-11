// Tests for DailyMoodController (Phase 6a of the architecture migration,
// the tenth of the 12 domain providers ported to Riverpod -- the second of
// the two dual-table providers, alongside TopicCardsController). No
// network: coupleSessionProvider is overridden with an unpaired
// CoupleSession() throughout (coupleId == null) -- these tests exercise the
// local-only write path.

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/mood/daily_mood_controller.dart';
import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/core/storage/scoped_json_cache.dart';

/// The controller caches are keyed per user (see ScopedJsonCache): a bare
/// device-wide key let a second account signing in read the first one's data.
/// Tests seed [_testUserId] so the cache has a user to scope by, and derive
/// keys through the cache itself rather than hardcoding the scheme.
const String _testUserId = 'u1';
String _cacheKey(String prefix) => ScopedJsonCache(prefix).keyFor(_testUserId);

/// dailyMoodControllerProvider is `autoDispose` -- see
/// bucket_list_controller_test.dart's identical helper doc comment for why
/// a persistent `container.listen` is required, not just `container.read`.
ProviderContainer _unpairedContainer() {
  final container = ProviderContainer(
    overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
  );
  container.listen(dailyMoodControllerProvider, (prev, next) {});
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'user_id': _testUserId});
  });

  group('DailyMoodController', () {
    test(
      'build() generates a deterministic today-question when there is no cache',
      () async {
        final container = _unpairedContainer();
        addTearDown(container.dispose);
        await Future.delayed(Duration.zero);

        final state = container.read(dailyMoodControllerProvider);
        expect(state.moods, isEmpty);
        expect(state.todayQuestion, isNotNull);
        expect(state.hasLoggedToday, isFalse);
      },
    );

    test(
      'logMood records locally when unpaired and reflects in hasLoggedToday/todayMood',
      () async {
        final container = _unpairedContainer();
        addTearDown(container.dispose);
        await Future.delayed(Duration.zero);

        await container
            .read(dailyMoodControllerProvider.notifier)
            .logMood(8, note: 'Great day');

        final state = container.read(dailyMoodControllerProvider);
        expect(state.hasLoggedToday, isTrue);
        expect(state.todayMood?.moodScore, 8);
        expect(state.todayMood?.note, 'Great day');

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(_cacheKey('daily_moods')),
          contains('Great day'),
        );
      },
    );

    test(
      'logMood twice in the same day replaces, not duplicates, today\'s entry',
      () async {
        final container = _unpairedContainer();
        addTearDown(container.dispose);
        await Future.delayed(Duration.zero);
        final notifier = container.read(dailyMoodControllerProvider.notifier);

        await notifier.logMood(5);
        await notifier.logMood(9, note: 'Even better');

        final state = container.read(dailyMoodControllerProvider);
        expect(
          state.moods.where((m) => m.date == state.todayMood!.date),
          hasLength(1),
        );
        expect(state.todayMood?.moodScore, 9);
      },
    );

    test(
      'answerDailyQuestion records the answer locally when unpaired',
      () async {
        final container = _unpairedContainer();
        addTearDown(container.dispose);
        await Future.delayed(Duration.zero);
        final notifier = container.read(dailyMoodControllerProvider.notifier);

        await notifier.answerDailyQuestion(
          'Because you make me laugh every day.',
        );

        final state = container.read(dailyMoodControllerProvider);
        expect(
          state.todayQuestion?.myAnswer,
          'Because you make me laugh every day.',
        );
      },
    );

    test(
      'purgeCache clears moods and regenerates a fresh today-question',
      () async {
        final container = _unpairedContainer();
        addTearDown(container.dispose);
        await Future.delayed(Duration.zero);
        final notifier = container.read(dailyMoodControllerProvider.notifier);
        await notifier.logMood(7);

        await notifier.purgeCache();

        final state = container.read(dailyMoodControllerProvider);
        expect(state.moods, isEmpty);
        expect(state.partnerMoods, isEmpty);
        expect(state.todayQuestion, isNotNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey(_cacheKey('daily_moods')), isFalse);
      },
    );
  });
}
