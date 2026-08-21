// Tests for TimeCapsuleController (Phase 6a of the architecture migration,
// the fourth of the 12 domain providers ported to Riverpod). No network:
// coupleSessionProvider is overridden with an unpaired CoupleSession()
// throughout (coupleId == null), matching bucket_list_controller_test.dart's
// convention -- these tests exercise the local-only write path.

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/love_studio/time_capsule_controller.dart';
import 'package:days_together/providers/couple_session.dart';

/// timeCapsuleControllerProvider is `autoDispose` -- see
/// bucket_list_controller_test.dart's identical helper doc comment for why
/// a persistent `container.listen` is required, not just `container.read`.
ProviderContainer _unpairedContainer() {
  final container = ProviderContainer(
    overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
  );
  container.listen(timeCapsuleControllerProvider, (prev, next) {});
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TimeCapsuleController', () {
    test('build() starts empty when there is no cached data', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(timeCapsuleControllerProvider);
      expect(state.capsules, isEmpty);
      expect(state.isLoading, false);
    });

    test('createCapsule appends locally, sorted by openDate', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(timeCapsuleControllerProvider.notifier);

      await notifier.createCapsule('Later', DateTime(2027, 1, 1));
      await notifier.createCapsule('Sooner', DateTime(2026, 1, 1));

      final state = container.read(timeCapsuleControllerProvider);
      expect(state.capsules.map((c) => c.message).toList(), ['Sooner', 'Later']);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('time_capsules'), contains('Sooner'));
    });

    test('a capsule with a past openDate is openable, not locked', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(timeCapsuleControllerProvider.notifier);

      await notifier.createCapsule('Ready now', DateTime(2020, 1, 1));
      await notifier.createCapsule('Not yet', DateTime(2099, 1, 1));

      final state = container.read(timeCapsuleControllerProvider);
      expect(state.openableCapsules.map((c) => c.message), contains('Ready now'));
      expect(state.lockedCapsules.map((c) => c.message), contains('Not yet'));
    });

    test('openCapsule marks an openable capsule as opened', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(timeCapsuleControllerProvider.notifier);

      await notifier.createCapsule('Ready now', DateTime(2020, 1, 1));
      final id = container.read(timeCapsuleControllerProvider).capsules.first.id;

      await notifier.openCapsule(id);

      final state = container.read(timeCapsuleControllerProvider);
      expect(state.openedCapsules, hasLength(1));
      expect(state.lockedCapsules, isEmpty);
      expect(state.openableCapsules, isEmpty);
    });

    test('openCapsule is a no-op for a still-locked capsule', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(timeCapsuleControllerProvider.notifier);

      await notifier.createCapsule('Not yet', DateTime(2099, 1, 1));
      final id = container.read(timeCapsuleControllerProvider).capsules.first.id;

      await notifier.openCapsule(id);

      expect(container.read(timeCapsuleControllerProvider).openedCapsules, isEmpty);
    });

    test('deleteCapsule removes locally when unpaired', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(timeCapsuleControllerProvider.notifier);

      await notifier.createCapsule('Gone soon', DateTime(2026, 1, 1));
      final id = container.read(timeCapsuleControllerProvider).capsules.first.id;

      await notifier.deleteCapsule(id);

      expect(container.read(timeCapsuleControllerProvider).capsules, isEmpty);
    });

    test('purgeCache clears capsules and the SharedPreferences cache', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(timeCapsuleControllerProvider.notifier);
      await notifier.createCapsule('Something', DateTime(2026, 1, 1));

      await notifier.purgeCache();

      final state = container.read(timeCapsuleControllerProvider);
      expect(state.capsules, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('time_capsules'), isFalse);
    });
  });
}
