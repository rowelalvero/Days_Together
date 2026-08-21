// Tests for LoveChatController (Phase 6a of the architecture migration, the
// eighth of the 12 domain providers ported to Riverpod, alongside
// NoteitController -- both read the shared `love_notes` table). No network:
// coupleSessionProvider is overridden with an unpaired CoupleSession()
// throughout (coupleId == null) -- these tests exercise the local-only
// write path.

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/chat/love_chat_controller.dart';
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
  });
}
