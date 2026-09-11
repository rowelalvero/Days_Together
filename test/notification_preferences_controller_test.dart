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
import 'package:days_together/features/settings/domain/entities/notification_preferences_model.dart';
import 'package:days_together/core/errors/app_failure.dart';
import 'package:days_together/core/session/couple_session.dart';

/// The controller's own cache key. Duplicated here deliberately: the
/// constant is private, and a test that reached into it could not catch the
/// key being renamed out from under a shipped install.
const String _cacheKey = 'notification_preferences';

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

    test('build() seeds preferences from the local cache', () async {
      // The controller is autoDispose, so without this mirror every visit to
      // the settings screen started from an empty state and sat on a spinner
      // until a network round-trip finished -- and showed nothing at all
      // offline.
      SharedPreferences.setMockInitialValues({
        _cacheKey: jsonEncode(
          NotificationPreferences(
            userId: 'u1',
            timezone: 'UTC',
          ).copyWith(chatEnabled: false, muteAll: true).toJson(),
        ),
      });
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(notificationPreferencesControllerProvider);
      expect(state.preferences, isNotNull);
      expect(state.preferences!.chatEnabled, isFalse);
      expect(state.preferences!.muteAll, isTrue);
      expect(
        state.isLoading,
        isFalse,
        reason:
            'cached values are real -- the refresh behind them must not '
            'put the screen back behind a spinner',
      );
    });

    test('a malformed cache entry is ignored rather than thrown', () async {
      SharedPreferences.setMockInitialValues({_cacheKey: 'not json'});
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      expect(
        container.read(notificationPreferencesControllerProvider).preferences,
        isNull,
      );
    });

    test('a failed write publishes a failure the UI can surface', () async {
      // Seeded from cache so preferences are non-null and updatePreference
      // gets past its early return; the Supabase write then throws, because
      // Supabase.initialize() was never called. That is the offline path.
      SharedPreferences.setMockInitialValues({
        _cacheKey: jsonEncode(
          NotificationPreferences(userId: 'u1', timezone: 'UTC').toJson(),
        ),
      });
      final container = _unpairedContainer();
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

    test('purgeCache clears the stored cache entry too', () async {
      SharedPreferences.setMockInitialValues({
        _cacheKey: jsonEncode(
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

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(_cacheKey),
        isFalse,
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
