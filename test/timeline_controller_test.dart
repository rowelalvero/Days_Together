// Tests for TimelineController (Phase 6a of the architecture migration, the
// fifth of the 12 domain providers ported to Riverpod, and the widest UI
// consumer surface). No network: coupleSessionProvider is overridden with
// an unpaired CoupleSession() throughout (coupleId == null) -- these tests
// exercise the local-only write path and SharedPreferences cache (via
// LocalPersistenceService), not the REST/realtime/image-upload paths.
// pickImage() is not covered here -- it needs a BuildContext and real
// image_picker/permission platform channels, out of scope for a plain unit
// test, same as this repo's other provider tests don't cover platform-heavy
// methods.

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/providers/couple_session.dart';

/// timelineControllerProvider is `autoDispose` -- see
/// bucket_list_controller_test.dart's identical helper doc comment for why
/// a persistent `container.listen` is required, not just `container.read`.
ProviderContainer _unpairedContainer() {
  final container = ProviderContainer(
    overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
  );
  container.listen(timelineControllerProvider, (prev, next) {});
  return container;
}

TimelineItemData _item(String title, DateTime date) =>
    TimelineItemData(title: title, description: '', date: date, isImageCard: false, position: 0);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TimelineController', () {
    test('build() starts empty when there is no cached data', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(timelineControllerProvider);
      expect(state.items, isEmpty);
      expect(state.isLoading, false);
      expect(state.isAscending, true);
    });

    test('addTimelineItem appends locally, sorted by date ascending, positions reassigned', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(timelineControllerProvider.notifier);

      await notifier.addTimelineItem(_item('Later', DateTime(2026, 6, 1)));
      await notifier.addTimelineItem(_item('Earlier', DateTime(2026, 1, 1)));

      final state = container.read(timelineControllerProvider);
      expect(state.items.map((i) => i.title).toList(), ['Earlier', 'Later']);
      expect(state.items[0].position, 0);
      expect(state.items[1].position, 1);
    });

    test('toggleSortOrder flips ordering and keeps the scrubbed item selected', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(timelineControllerProvider.notifier);

      await notifier.addTimelineItem(_item('A', DateTime(2026, 1, 1)));
      await notifier.addTimelineItem(_item('B', DateTime(2026, 6, 1)));
      // Items are now [A, B] ascending; scrub to B (index 1).
      notifier.setCurrentScrubIndex(1);
      expect(container.read(timelineControllerProvider).items[container.read(timelineControllerProvider).currentScrubIndex].title, 'B');

      await notifier.toggleSortOrder();

      final state = container.read(timelineControllerProvider);
      expect(state.isAscending, false);
      expect(state.items.map((i) => i.title).toList(), ['B', 'A']);
      // The previously-scrubbed item (B) should still be the selected one.
      expect(state.items[state.currentScrubIndex].title, 'B');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('timeline_is_ascending'), false);
    });

    test('updateTimelineItem replaces the item locally when unpaired', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(timelineControllerProvider.notifier);

      final item = _item('Old title', DateTime(2026, 3, 3));
      await notifier.addTimelineItem(item);

      await notifier.updateTimelineItem(item.id, item.copyWith(title: 'New title'));

      final state = container.read(timelineControllerProvider);
      expect(state.items, hasLength(1));
      expect(state.items.first.title, 'New title');
    });

    test('deleteTimelineItem removes the item immediately, re-indexing position', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(timelineControllerProvider.notifier);

      await notifier.addTimelineItem(_item('First', DateTime(2026, 1, 1)));
      await notifier.addTimelineItem(_item('Second', DateTime(2026, 2, 1)));
      final firstId = container.read(timelineControllerProvider).items.first.id;

      await notifier.deleteTimelineItem(firstId);

      final state = container.read(timelineControllerProvider);
      expect(state.items, hasLength(1));
      expect(state.items.first.title, 'Second');
      expect(state.items.first.position, 0);
    });

    test('setCurrentScrubIndex clamps to the valid item range', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(timelineControllerProvider.notifier);

      await notifier.addTimelineItem(_item('Only item', DateTime(2026, 1, 1)));

      notifier.setCurrentScrubIndex(99);
      expect(container.read(timelineControllerProvider).currentScrubIndex, 0);

      notifier.setCurrentScrubIndex(-5);
      expect(container.read(timelineControllerProvider).currentScrubIndex, 0);
    });

    test('addCommentToItem appends a comment via updateTimelineItem', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(timelineControllerProvider.notifier);

      final item = _item('Memory', DateTime(2026, 4, 4));
      await notifier.addTimelineItem(item);

      await notifier.addCommentToItem(item.id, 'Love this!', 'Alex');

      final state = container.read(timelineControllerProvider);
      expect(state.items.first.comments, hasLength(1));
      expect(state.items.first.comments.first.content, 'Love this!');
    });

    test('purgeCache clears items and the underlying local persistence cache', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(timelineControllerProvider.notifier);
      await notifier.addTimelineItem(_item('Something', DateTime(2026, 5, 5)));

      await notifier.purgeCache();

      final state = container.read(timelineControllerProvider);
      expect(state.items, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('timeline_items'), '[]');
    });
  });
}
