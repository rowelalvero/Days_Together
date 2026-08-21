// Tests for CurrentlyController (Phase 6a of the architecture migration,
// the eleventh of the 12 domain providers ported to Riverpod). No network:
// coupleSessionProvider is overridden with an unpaired CoupleSession()
// throughout (coupleId == null) -- syncInitialData/_loadHistory's Supabase
// call is skipped by its own `if (coupleId == null) return;` guard, so
// these tests exercise onRealtimeData (fed directly, as the realtime
// subscription would) and purgeCache instead.

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/currently/currently_controller.dart';
import 'package:days_together/features/currently/currently_state.dart';
import 'package:days_together/providers/couple_session.dart';

/// currentlyControllerProvider is `autoDispose` -- see
/// bucket_list_controller_test.dart's identical helper doc comment for why
/// a persistent `container.listen` is required, not just `container.read`.
ProviderContainer _unpairedContainer() {
  final container = ProviderContainer(
    overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
  );
  container.listen(currentlyControllerProvider, (prev, next) {});
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CurrentlyController', () {
    test('build() starts idle with an empty history', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(currentlyControllerProvider);
      expect(state.state, LoveTapState.idle);
      expect(state.history.completedTaps, 0);
    });

    test('onRealtimeData with no row for today yields idle', () {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      final notifier = container.read(currentlyControllerProvider.notifier);

      notifier.onRealtimeData([]);

      expect(container.read(currentlyControllerProvider).state, LoveTapState.idle);
    });

    test('onRealtimeData with both partners tapped today yields mutual', () {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      final notifier = container.read(currentlyControllerProvider.notifier);
      final today = DateTime.now();
      final todayStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      notifier.onRealtimeData([
        {'date': todayStr, 'partner1_tapped': true, 'partner2_tapped': true},
      ]);

      expect(container.read(currentlyControllerProvider).state, LoveTapState.mutual);
    });

    test('purgeCache resets state to idle and clears history', () {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      final notifier = container.read(currentlyControllerProvider.notifier);
      final today = DateTime.now();
      final todayStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      notifier.onRealtimeData([
        {'date': todayStr, 'partner1_tapped': true, 'partner2_tapped': true},
      ]);

      notifier.purgeCache();

      final state = container.read(currentlyControllerProvider);
      expect(state.state, LoveTapState.idle);
      expect(state.history.completedTaps, 0);
    });
  });
}
