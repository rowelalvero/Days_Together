// Tests for LoveChatController (Phase 6a of the architecture migration, the
// eighth of the 12 domain providers ported to Riverpod, alongside
// NoteitController -- both read the shared `love_notes` table). No network:
// coupleSessionProvider is overridden with an unpaired CoupleSession()
// throughout (coupleId == null) -- these tests exercise the local-only
// write path.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/chat/love_chat_controller.dart';
import 'package:days_together/models/love_chat_model.dart';
import 'package:days_together/providers/couple_session.dart';

/// loveChatControllerProvider is `autoDispose` -- see
/// bucket_list_controller_test.dart's identical helper doc comment for why
/// a persistent `container.listen` is required, not just `container.read`.
/// (This provider also calls `ref.keepAlive()` per ADR-005, but a test
/// still needs its own listener to observe state changes.)
ProviderContainer _unpairedContainer() {
  final container = ProviderContainer(
    overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
  );
  container.listen(loveChatControllerProvider, (prev, next) {});
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LoveChatController', () {
    test('build() prepopulates a welcome message when there is no cache', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(loveChatControllerProvider);
      expect(state.messages, hasLength(1));
      expect(state.messages.first.senderId, 'partner');
      expect(state.isLoading, false);
    });

    test('sendMessage prepends locally and persists', () async {
      SharedPreferences.setMockInitialValues({'love_chat_messages': '[]'});
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      await container.read(loveChatControllerProvider.notifier).sendMessage('Hi love', 'Me');

      final state = container.read(loveChatControllerProvider);
      expect(state.messages, hasLength(1));
      expect(state.messages.first.content, 'Hi love');
      expect(state.messages.first.senderId, 'you');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('love_chat_messages'), contains('Hi love'));
    });

    test('deleteMessage removes locally', () async {
      SharedPreferences.setMockInitialValues({'love_chat_messages': '[]'});
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(loveChatControllerProvider.notifier);

      await notifier.sendMessage('Delete me', 'Me');
      final id = container.read(loveChatControllerProvider).messages.first.id;

      await notifier.deleteMessage(id);

      expect(container.read(loveChatControllerProvider).messages, isEmpty);
    });

    test('messages are capped at maxLocalMessages, newest kept', () async {
      SharedPreferences.setMockInitialValues({'love_chat_messages': '[]'});
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(loveChatControllerProvider.notifier);

      for (var i = 0; i < LoveChatController.maxLocalMessages + 5; i++) {
        await notifier.sendMessage('Message $i', 'Me');
      }

      final state = container.read(loveChatControllerProvider);
      expect(state.messages.length, LoveChatController.maxLocalMessages);
      // Most recently sent message stays at the front.
      expect(state.messages.first.content, 'Message ${LoveChatController.maxLocalMessages + 4}');
    });

    test('purgeCache clears messages and the SharedPreferences cache', () async {
      SharedPreferences.setMockInitialValues({'love_chat_messages': '[]'});
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(loveChatControllerProvider.notifier);
      await notifier.sendMessage('Something', 'Me');

      await notifier.purgeCache();

      final state = container.read(loveChatControllerProvider);
      expect(state.messages, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('love_chat_messages'), isFalse);
    });

    // The tests below port `LoveChatProvider`'s old M-1 bounded-local-chat-
    // persistence coverage (test/love_chat_provider_test.dart, deleted once
    // this file was confirmed to supersede it) -- specifically the
    // `_loadFromCache()` load-path behaviors (single message, exact-cap,
    // over-cap clamping, malformed JSON, restart, ordering, legacy-oversized
    // migration) that the tests above never exercised: they only cover the
    // no-cache/welcome-message build() path and the runtime `sendMessage`
    // cap logic, not what happens when `build()` finds existing cached data.

    test('loads a single persisted message from cache on build', () async {
      final now = DateTime.now();
      final msg = LoveChatMessage(
        id: 'msg-1',
        senderId: 'you',
        senderName: 'Me',
        content: 'Hello love!',
        createdAt: now,
      );
      SharedPreferences.setMockInitialValues({
        'love_chat_messages': jsonEncode([msg.toJson()]),
      });
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(loveChatControllerProvider);
      expect(state.messages.length, 1);
      expect(state.messages.first.id, 'msg-1');
      expect(state.messages.first.content, 'Hello love!');
    });

    test('loads exactly 200 persisted messages without loss', () async {
      final now = DateTime.now();
      final rawList = [
        for (int i = 0; i < 200; i++)
          LoveChatMessage(
            id: 'msg-$i',
            senderId: 'you',
            senderName: 'Me',
            content: 'Message $i',
            createdAt: now.subtract(Duration(minutes: i)),
          ).toJson(),
      ];
      SharedPreferences.setMockInitialValues({'love_chat_messages': jsonEncode(rawList)});
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(loveChatControllerProvider);
      expect(state.messages.length, 200);
      expect(state.messages.first.id, 'msg-0');
      expect(state.messages.last.id, 'msg-199');
    });

    test('clamps 201 persisted messages to 200 on load', () async {
      final now = DateTime.now();
      final rawList = [
        for (int i = 0; i < 201; i++)
          LoveChatMessage(
            id: 'msg-$i',
            senderId: 'you',
            senderName: 'Me',
            content: 'Message $i',
            createdAt: now.subtract(Duration(minutes: i)),
          ).toJson(),
      ];
      SharedPreferences.setMockInitialValues({'love_chat_messages': jsonEncode(rawList)});
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(loveChatControllerProvider);
      expect(state.messages.length, 200);
      expect(state.messages.first.id, 'msg-0');
      expect(state.messages.last.id, 'msg-199');
    });

    test('clamps 1,000 persisted messages to 200 on load', () async {
      final now = DateTime.now();
      final rawList = [
        for (int i = 0; i < 1000; i++)
          LoveChatMessage(
            id: 'msg-$i',
            senderId: 'you',
            senderName: 'Me',
            content: 'Message $i',
            createdAt: now.subtract(Duration(minutes: i)),
          ).toJson(),
      ];
      SharedPreferences.setMockInitialValues({'love_chat_messages': jsonEncode(rawList)});
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(loveChatControllerProvider);
      expect(state.messages.length, 200);
      expect(state.messages.first.id, 'msg-0');
      expect(state.messages.last.id, 'msg-199');
    });

    test('falls back safely on malformed persisted JSON', () async {
      SharedPreferences.setMockInitialValues({'love_chat_messages': '{invalid_json_corrupted}'});
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(loveChatControllerProvider);
      expect(state.messages, isEmpty);
      expect(state.isLoading, false);
    });

    test('restores bounded state across a simulated app restart', () async {
      final now = DateTime.now();
      final rawList = [
        for (int i = 0; i < 50; i++)
          LoveChatMessage(
            id: 'restart-msg-$i',
            senderId: 'you',
            senderName: 'Me',
            content: 'Persistent $i',
            createdAt: now.subtract(Duration(seconds: i)),
          ).toJson(),
      ];
      SharedPreferences.setMockInitialValues({'love_chat_messages': jsonEncode(rawList)});

      // App instance 1.
      final container1 = _unpairedContainer();
      await Future.delayed(Duration.zero);
      expect(container1.read(loveChatControllerProvider).messages.length, 50);
      container1.dispose();

      // App instance 2 (simulating an app restart against the same
      // SharedPreferences-backed disk cache).
      final container2 = _unpairedContainer();
      addTearDown(container2.dispose);
      await Future.delayed(Duration.zero);
      final state2 = container2.read(loveChatControllerProvider);
      expect(state2.messages.length, 50);
      expect(state2.messages.first.id, 'restart-msg-0');
    });

    test('preserves newest-first ordering when loading from cache', () async {
      final now = DateTime.now();
      final oldMsg = LoveChatMessage(
        id: 'old',
        senderId: 'you',
        senderName: 'Me',
        content: 'Old',
        createdAt: now.subtract(const Duration(hours: 2)),
      );
      final newMsg = LoveChatMessage(
        id: 'new',
        senderId: 'you',
        senderName: 'Me',
        content: 'New',
        createdAt: now.subtract(const Duration(minutes: 5)),
      );
      SharedPreferences.setMockInitialValues({
        'love_chat_messages': jsonEncode([oldMsg.toJson(), newMsg.toJson()]),
      });
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(loveChatControllerProvider);
      expect(state.messages.first.id, 'new');
      expect(state.messages.last.id, 'old');
    });

    test('migrates and trims an oversized legacy cache on load', () async {
      final now = DateTime.now();
      final oversizedList = [
        for (int i = 0; i < 500; i++)
          LoveChatMessage(
            id: 'legacy-$i',
            senderId: 'you',
            senderName: 'Me',
            content: 'Legacy message $i',
            createdAt: now.subtract(Duration(minutes: i)),
          ).toJson(),
      ];
      SharedPreferences.setMockInitialValues({'love_chat_messages': jsonEncode(oversizedList)});
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      await Future.delayed(const Duration(milliseconds: 50));

      final state = container.read(loveChatControllerProvider);
      expect(state.messages.length, 200);

      final prefs = await SharedPreferences.getInstance();
      final migratedDiskJson = prefs.getString('love_chat_messages');
      expect(migratedDiskJson, isNotNull);
      final migratedList = jsonDecode(migratedDiskJson!) as List;
      expect(migratedList.length, 200);
      expect((migratedList.first as Map)['id'], 'legacy-0');
      expect((migratedList.last as Map)['id'], 'legacy-199');
    });
  });
}
