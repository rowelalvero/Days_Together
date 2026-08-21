// Tests for BucketListController (Phase 6a of the architecture migration --
// the first of the 12 domain providers ported to Riverpod, establishing the
// SupabaseLifecycleNotifier pattern the other 11 follow). No network:
// coupleSessionProvider is overridden with an unpaired CoupleSession()
// throughout (coupleId == null), matching license_controller_test.dart's
// offline-only convention, since Supabase.instance throws without
// Supabase.initialize() -- these tests exercise the local-only write path
// and SharedPreferences cache, not the REST/realtime paths.

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/bucket_list/bucket_list_controller.dart';
import 'package:days_together/providers/couple_session.dart';

/// bucketListControllerProvider is `autoDispose`: a bare `container.read()`
/// does not keep it alive, so without an active listener Riverpod tears it
/// down as soon as the read returns -- including mid-flight if `build()`'s
/// fire-and-forget `_loadFromCache()` hasn't resolved yet. `container.listen`
/// establishes the same kind of persistent watch a real widget would, which
/// every test here needs since it's exercising async methods.
ProviderContainer _unpairedContainer() {
  final container = ProviderContainer(
    overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
  );
  container.listen(bucketListControllerProvider, (prev, next) {});
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BucketListController', () {
    test('build() starts empty when there is no cached data', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);

      // Allow the async _loadFromCache() kicked off from build() to resolve.
      await Future.delayed(Duration.zero);

      final state = container.read(bucketListControllerProvider);
      expect(state.items, isEmpty);
      expect(state.isLoading, false);
    });

    test('build() hydrates from the SharedPreferences cache', () async {
      SharedPreferences.setMockInitialValues({
        'bucket_list_items':
            '[{"id":"1","title":"Skydive","isCompleted":false,"order":0,"createdAt":"2024-01-01T00:00:00.000"}]',
      });
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(bucketListControllerProvider);
      expect(state.items, hasLength(1));
      expect(state.items.first.title, 'Skydive');
    });

    test('addItem appends locally and persists when unpaired', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      await container.read(bucketListControllerProvider.notifier).addItem('Watch the sunrise');

      final state = container.read(bucketListControllerProvider);
      expect(state.items, hasLength(1));
      expect(state.items.first.title, 'Watch the sunrise');
      expect(state.totalItems, 1);
      expect(state.completedItems, 0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bucket_list_items'), contains('Watch the sunrise'));
    });

    test('toggleItem flips completion and updates progress', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(bucketListControllerProvider.notifier);

      await notifier.addItem('Learn to surf');
      final id = container.read(bucketListControllerProvider).items.first.id;

      await notifier.toggleItem(id);
      var state = container.read(bucketListControllerProvider);
      expect(state.items.first.isCompleted, true);
      expect(state.items.first.completedAt, isNotNull);
      expect(state.progress, 1.0);

      await notifier.toggleItem(id);
      state = container.read(bucketListControllerProvider);
      expect(state.items.first.isCompleted, false);
      // Pre-existing bug, faithfully preserved from BucketListProvider, not
      // introduced by this port: BucketListItem.copyWith's
      // `completedAt: completedAt ?? this.completedAt` means an explicit
      // `completedAt: null` never clears the field, since `null ?? x` falls
      // back to `x`. Un-completing an item leaves its old completedAt
      // timestamp in place. Out of scope to fix here -- Phase 6a is a
      // faithful behavior port, not a bug hunt.
      expect(state.items.first.completedAt, isNotNull);
    });

    test('deleteItem removes the item and re-indexes remaining order', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(bucketListControllerProvider.notifier);

      await notifier.addItem('First');
      await notifier.addItem('Second');
      await notifier.addItem('Third');
      final firstId = container.read(bucketListControllerProvider).items.first.id;

      await notifier.deleteItem(firstId);

      final state = container.read(bucketListControllerProvider);
      expect(state.items, hasLength(2));
      expect(state.items.any((i) => i.id == firstId), isFalse);
      expect(state.items[0].order, 0);
      expect(state.items[1].order, 1);
    });

    test('reorderItems moves an item and re-indexes order', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(bucketListControllerProvider.notifier);

      await notifier.addItem('A');
      await notifier.addItem('B');
      await notifier.addItem('C');

      await notifier.reorderItems(0, 2);

      final titles = container.read(bucketListControllerProvider).items.map((i) => i.title).toList();
      expect(titles, ['B', 'A', 'C']);
      expect(container.read(bucketListControllerProvider).items.map((i) => i.order).toList(), [0, 1, 2]);
    });

    test('purgeCache clears items and the SharedPreferences cache', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(bucketListControllerProvider.notifier);
      await notifier.addItem('Something');

      await notifier.purgeCache();

      final state = container.read(bucketListControllerProvider);
      expect(state.items, isEmpty);
      expect(state.isLoading, false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('bucket_list_items'), isFalse);
    });

    test('updateSession with an unpaired-to-unpaired transition is a no-op', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(bucketListControllerProvider.notifier);
      await notifier.addItem('Keep me');

      // A CoupleSession with the same (null) coupleId/userId -- no
      // credentials change, so nothing should be purged or re-synced.
      await notifier.updateSession(CoupleSession());

      expect(container.read(bucketListControllerProvider).items, hasLength(1));
    });
  });
}
