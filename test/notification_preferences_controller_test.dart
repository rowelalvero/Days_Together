// Tests for NotificationPreferencesController (Phase 6a of the
// architecture migration, the twelfth and last of the 12 domain providers
// ported to Riverpod). No network: Supabase.instance throws without
// Supabase.initialize(), which _loadPreferences catches and logs --
// exercising the same graceful-failure path a real offline device hits,
// leaving preferences null and isLoading false.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/settings/notification_preferences_controller.dart';
import 'package:days_together/features/settings/data/notification_preferences_cache.dart';
import 'package:days_together/features/settings/notification_preferences_state.dart';
import 'package:days_together/features/settings/domain/entities/notification_preferences_model.dart';
import 'package:days_together/core/errors/app_failure.dart';
import 'package:days_together/core/session/couple_session.dart';

/// Seeds the controller with fixed state, so tests can reach code paths
/// that need non-null preferences. The real build() cannot get there in a
/// unit test: CoupleSession never produces a userId without a live Supabase
/// client, so both the network load and the per-user cache load are
/// unreachable. Same subclass-fake technique as
/// daily_mood_bento_card_test.dart.
class _SeededController extends NotificationPreferencesController {
  _SeededController(this._seed);
  final NotificationPreferencesState _seed;
  @override
  NotificationPreferencesState build() => _seed;
}

ProviderContainer _seededContainer(NotificationPreferences preferences) {
  final container = ProviderContainer(
    overrides: [
      coupleSessionProvider.overrideWithValue(CoupleSession()),
      notificationPreferencesControllerProvider.overrideWith(
        () => _SeededController(
          NotificationPreferencesState(preferences: preferences),
        ),
      ),
    ],
  );
  container.listen(notificationPreferencesControllerProvider, (prev, next) {});
  return container;
}

/// notificationPreferencesControllerProvider is `autoDispose` -- see
/// bucket_list_controller_test.dart's identical helper doc comment for why
/// a persistent `container.listen` is required, not just `container.read`.
ProviderContainer _unpairedContainer() {
  final container = ProviderContainer(
    overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
  );
  container.listen(notificationPreferencesControllerProvider, (prev, next) {});
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NotificationPreferencesController', () {
    test('build() with no signed-in user never attempts a sync', () async {
      // Was "preserved gating": this used to also require a coupleId, so a
      // signed-in but unpaired user never loaded preferences at all. The
      // gate is now userId-only; here userId is null too, so the outcome
      // is unchanged.
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(notificationPreferencesControllerProvider);
      expect(state.preferences, isNull);
      expect(state.isLoading, false);
    });

    test(
      'updateSession with a coupleId but no userId still skips the sync',
      () async {
        SharedPreferences.setMockInitialValues({
          'couple_id': 'c1',
          'is_paired': true,
          'is_creator': true,
          'onboarding_completed': true,
        });
        final container = _unpairedContainer();
        addTearDown(container.dispose);
        await Future.delayed(Duration.zero);
        final notifier = container.read(
          notificationPreferencesControllerProvider.notifier,
        );

        final pairedSession = CoupleSession();
        await Future.delayed(Duration.zero);
        // Without Supabase.initialize(), CoupleSession never populates
        // userId (only coupleId comes from prefs). Since the gate is now
        // userId-only, a coupleId on its own must still not trigger a sync --
        // that is what this pins. Reaching the syncInitialData branch needs a
        // real Supabase-backed userId, out of reach for a unit test.
        await notifier.updateSession(pairedSession);

        final state = container.read(notificationPreferencesControllerProvider);
        expect(state.preferences, isNull);
        expect(state.isLoading, false);
      },
    );

    test(
      'togglePreference is a no-op when preferences have not loaded',
      () async {
        final container = _unpairedContainer();
        addTearDown(container.dispose);
        await Future.delayed(Duration.zero);
        final notifier = container.read(
          notificationPreferencesControllerProvider.notifier,
        );

        await notifier.togglePreference('push_enabled');

        expect(
          container.read(notificationPreferencesControllerProvider).preferences,
          isNull,
        );
      },
    );

    // The cache round-trip, its per-user scoping, malformed-entry
    // tolerance and clearAll now live in
    // notification_preferences_cache_test.dart. They cannot be driven from
    // here any more: the cache is keyed on userId, and a unit-test
    // CoupleSession has none.

    test('a failed write publishes a failure the UI can surface', () async {
      // Seeded so updatePreference gets past its early return; the Supabase
      // write then throws, because Supabase.initialize() was never called.
      // That is the offline path.
      final container = _seededContainer(
        NotificationPreferences(userId: 'u1', timezone: 'UTC'),
      );
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(
        notificationPreferencesControllerProvider.notifier,
      );

      await notifier.togglePreference('chat_enabled');

      final state = container.read(notificationPreferencesControllerProvider);
      expect(
        state.failure,
        isA<AppFailure>(),
        reason:
            'a dropped write used to be invisible -- the switch simply '
            'never moved and nothing was reported',
      );
      expect(
        state.preferences!.chatEnabled,
        isTrue,
        reason:
            'the write runs before the local update, so a failure must '
            'leave the old value in place',
      );

      notifier.clearFailure();
      expect(
        container.read(notificationPreferencesControllerProvider).failure,
        isNull,
      );
    });

    test('purgeCache clears cached entries for every user', () async {
      SharedPreferences.setMockInitialValues({
        NotificationPreferencesCache.keyFor('u1'): jsonEncode(
          NotificationPreferences(userId: 'u1', timezone: 'UTC').toJson(),
        ),
      });
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(
        notificationPreferencesControllerProvider.notifier,
      );

      await notifier.purgeCache();

      expect(
        await const NotificationPreferencesCache().load('u1'),
        isNull,
        reason: 'preferences must not survive on disk after sign-out',
      );
    });

    test('purgeCache clears any loaded preferences', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(
        notificationPreferencesControllerProvider.notifier,
      );

      await notifier.purgeCache();

      expect(
        container.read(notificationPreferencesControllerProvider).preferences,
        isNull,
      );
      expect(
        container.read(notificationPreferencesControllerProvider).isLoading,
        false,
      );
    });
  });
}
