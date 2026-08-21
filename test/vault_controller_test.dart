// Tests for VaultController (Phase 6a of the architecture migration, the
// sixth of the 12 domain providers ported to Riverpod). No network:
// coupleSessionProvider is overridden with an unpaired CoupleSession()
// throughout (coupleId == null) -- these tests exercise the local-only
// write path. FlutterSecureStorage has no platform channel in a plain unit
// test, so every secure-storage call throws and setPin/verifyPin fall back
// to the 'vault_pin_fallback' SharedPreferences key -- exactly the fallback
// path VaultProvider already built for a real device where secure storage
// is unavailable, so this is exercising real production behavior, not a
// test-only shortcut.

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/vault/vault_controller.dart';
import 'package:days_together/providers/couple_session.dart';

/// vaultControllerProvider is `autoDispose` -- see
/// bucket_list_controller_test.dart's identical helper doc comment for why
/// a persistent `container.listen` is required, not just `container.read`.
ProviderContainer _unpairedContainer() {
  final container = ProviderContainer(
    overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
  );
  container.listen(vaultControllerProvider, (prev, next) {});
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VaultController', () {
    test('build() starts locked with no items', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(vaultControllerProvider);
      expect(state.isUnlocked, false);
      expect(state.hasPin, false);
      expect(state.visibleItems, isEmpty);
    });

    test('setPin sets hasPin and unlocks; verifyPin with the right PIN unlocks', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(vaultControllerProvider.notifier);

      await notifier.setPin('1234');
      expect(container.read(vaultControllerProvider).hasPin, true);
      expect(container.read(vaultControllerProvider).isUnlocked, true);

      await notifier.lock();
      expect(container.read(vaultControllerProvider).isUnlocked, false);

      final correct = await notifier.verifyPin('1234');
      expect(correct, true);
      expect(container.read(vaultControllerProvider).isUnlocked, true);
    });

    test('verifyPin with the wrong PIN increments wrongAttempts and triggers decoy mode at 3', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(vaultControllerProvider.notifier);
      await notifier.setPin('1234');
      await notifier.lock();

      await notifier.verifyPin('0000');
      await notifier.verifyPin('0000');
      expect(container.read(vaultControllerProvider).isDecoyMode, false);

      final result = await notifier.verifyPin('0000');
      expect(result, false);
      expect(container.read(vaultControllerProvider).wrongAttempts, 3);
      expect(container.read(vaultControllerProvider).isDecoyMode, true);
    });

    test('addLetter is a no-op while locked', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(vaultControllerProvider.notifier);

      await notifier.addLetter('Should not be added');

      expect(container.read(vaultControllerProvider).visibleItems, isEmpty);
    });

    test('addLetter appends locally once unlocked', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(vaultControllerProvider.notifier);
      await notifier.setPin('1234');

      await notifier.addLetter('A love note');

      final state = container.read(vaultControllerProvider);
      expect(state.visibleItems, hasLength(1));
      expect(state.letters, hasLength(1));
      expect(state.letters.first.content, 'A love note');
      expect(state.photos, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('vault_items'), contains('A love note'));
    });

    test('deleteItem removes locally when unpaired', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(vaultControllerProvider.notifier);
      await notifier.setPin('1234');
      await notifier.addLetter('Gone soon');
      final id = container.read(vaultControllerProvider).visibleItems.first.id;

      await notifier.deleteItem(id);

      expect(container.read(vaultControllerProvider).visibleItems, isEmpty);
    });

    test('lock hides items via visibleItems without clearing the underlying data', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(vaultControllerProvider.notifier);
      await notifier.setPin('1234');
      await notifier.addLetter('Still here');

      await notifier.lock();

      final state = container.read(vaultControllerProvider);
      expect(state.visibleItems, isEmpty, reason: 'visibleItems is gated by isUnlocked');
      expect(state.letters, hasLength(1), reason: 'the underlying data is not cleared by locking');
    });

    test('purgeCache clears items and the SharedPreferences cache', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(vaultControllerProvider.notifier);
      await notifier.setPin('1234');
      await notifier.addLetter('Something');

      await notifier.purgeCache();

      final state = container.read(vaultControllerProvider);
      expect(state.letters, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('vault_items'), isFalse);
    });
  });
}
