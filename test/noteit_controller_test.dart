// Tests for NoteitController (Phase 6a of the architecture migration, the
// seventh of the 12 domain providers ported to Riverpod, alongside
// LoveChatController -- both read the shared `love_notes` table). No
// network: coupleSessionProvider is overridden with an unpaired
// CoupleSession() throughout (coupleId == null), so send* methods take
// their "unpaired" branch (NoteitSyncManager.enqueue is never reached,
// avoiding any need to mock that singleton) and visibleNotes stays empty
// (its coupleId-gating), matching NoteitProvider.notes's original behavior
// -- tests that need to inspect content read the raw `notes` field instead.

import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/scrapbook/noteit_controller.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/providers/couple_session.dart';

/// noteitControllerProvider is `autoDispose` -- see
/// bucket_list_controller_test.dart's identical helper doc comment for why
/// a persistent `container.listen` is required, not just `container.read`.
ProviderContainer _unpairedContainer() {
  final container = ProviderContainer(
    overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
  );
  container.listen(noteitControllerProvider, (prev, next) {});
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NoteitController', () {
    test('build() prepopulates the tutorial notes when there is no cache', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(noteitControllerProvider);
      expect(state.notes, hasLength(2));
      expect(state.isLoading, false);
    });

    test('visibleNotes is empty while unpaired, even with notes present', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(noteitControllerProvider);
      expect(state.notes, isNotEmpty);
      expect(state.visibleNotes, isEmpty);
      expect(state.coupleId, isNull);
    });

    test('sendText prepends locally and marks failed when unpaired', () async {
      SharedPreferences.setMockInitialValues({'love_notes_items': '[]'});
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      const bgColor = Color(0xFF000000);
      await container.read(noteitControllerProvider.notifier).sendText('Thinking of you', bgColor);

      final state = container.read(noteitControllerProvider);
      expect(state.notes, hasLength(1));
      expect(state.notes.first.content, 'Thinking of you');
      expect(state.notes.first.syncStatus, SyncStatus.failed);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('love_notes_items'), contains('Thinking of you'));
    });

    test('sendDrawing prepends locally', () async {
      SharedPreferences.setMockInitialValues({'love_notes_items': '[]'});
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      const bgColor = Color(0xFFFFFFFF);
      await container.read(noteitControllerProvider.notifier).sendDrawing('1,1;2,2', bgColor);

      final state = container.read(noteitControllerProvider);
      expect(state.notes, hasLength(1));
      expect(state.notes.first.type, NoteitType.drawing);
    });

    test('deleteNote removes locally when unpaired', () async {
      SharedPreferences.setMockInitialValues({'love_notes_items': '[]'});
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(noteitControllerProvider.notifier);

      await notifier.sendText('Gone soon', const Color(0xFF123456));
      final id = container.read(noteitControllerProvider).notes.first.id;

      await notifier.deleteNote(id);

      expect(container.read(noteitControllerProvider).notes, isEmpty);
    });

    test('updateItemSyncStatus updates the matching note and persists', () async {
      SharedPreferences.setMockInitialValues({'love_notes_items': '[]'});
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(noteitControllerProvider.notifier);

      await notifier.sendText('Retry me', const Color(0xFF654321));
      final id = container.read(noteitControllerProvider).notes.first.id;

      notifier.updateItemSyncStatus(id, SyncStatus.synced);

      expect(container.read(noteitControllerProvider).notes.first.syncStatus, SyncStatus.synced);
    });

    test('purgeCache clears notes and the SharedPreferences cache', () async {
      SharedPreferences.setMockInitialValues({'love_notes_items': '[]'});
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(noteitControllerProvider.notifier);
      await notifier.sendText('Something', const Color(0xFF000001));

      await notifier.purgeCache();

      final state = container.read(noteitControllerProvider);
      expect(state.notes, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('love_notes_items'), isFalse);
    });
  });
}
