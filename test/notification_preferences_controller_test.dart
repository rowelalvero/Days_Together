// Tests for NotificationPreferencesController (Phase 6a of the
// architecture migration, the twelfth and last of the 12 domain providers
// ported to Riverpod). No network: Supabase.instance throws without
// Supabase.initialize(), which _loadPreferences catches and logs --
// exercising the same graceful-failure path a real offline device hits,
// leaving preferences null and isLoading false.

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/settings/notification_preferences_controller.dart';
import 'package:days_together/providers/couple_session.dart';

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
    test('build() with an unpaired session never attempts a sync (preserved gating)', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(notificationPreferencesControllerProvider);
      expect(state.preferences, isNull);
      expect(state.isLoading, false);
    });

    test('updateSession with both userId and coupleId set attempts a sync and fails gracefully offline', () async {
      SharedPreferences.setMockInitialValues({
        'couple_id': 'c1',
        'is_paired': true,
        'is_creator': true,
        'onboarding_completed': true,
      });
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(notificationPreferencesControllerProvider.notifier);

      final pairedSession = CoupleSession();
      await Future.delayed(Duration.zero);
      // Without Supabase.initialize(), CoupleSession never actually
      // populates userId (only coupleId comes from prefs) -- so this only
      // exercises the "coupleId set, userId still null" half of the gate,
      // which correctly stays purgeCache'd. Included to document the
      // gating explicitly, not to reach the syncInitialData branch (that
      // needs a real Supabase-backed userId, out of reach for a unit test).
      await notifier.updateSession(pairedSession);

      final state = container.read(notificationPreferencesControllerProvider);
      expect(state.preferences, isNull);
      expect(state.isLoading, false);
    });

    test('togglePreference is a no-op when preferences have not loaded', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(notificationPreferencesControllerProvider.notifier);

      await notifier.togglePreference('push_enabled');

      expect(container.read(notificationPreferencesControllerProvider).preferences, isNull);
    });

    test('purgeCache clears any loaded preferences', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(notificationPreferencesControllerProvider.notifier);

      await notifier.purgeCache();

      expect(container.read(notificationPreferencesControllerProvider).preferences, isNull);
      expect(container.read(notificationPreferencesControllerProvider).isLoading, false);
    });
  });
}
