import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/features/chat/love_chat_controller.dart';
import 'package:days_together/features/scrapbook/data/noteit_draft_store.dart';
import 'package:days_together/features/scrapbook/domain/scrapbook_share_use_case.dart';
import 'package:days_together/features/scrapbook/noteit_controller.dart';
import 'package:days_together/models/canvas_document.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/providers/couple_session.dart';

/// Forces the note-creation step to fail, to exercise
/// ScrapbookShareNoteFailed without needing a real Supabase failure.
class _ThrowingNoteitController extends NoteitController {
  @override
  Future<NoteitItem> sendCanvas(String jsonContent, String? localImagePath) {
    throw Exception('note creation boom');
  }
}

/// Forces the chat-mirror step to fail, to exercise
/// ScrapbookShareChatMirrorFailed. LoveChatController.sendMessage currently
/// swallows its own Supabase errors internally (see migration-roadmap.md
/// Phase 8's note), so this is the only way to exercise this branch today.
class _ThrowingLoveChatController extends LoveChatController {
  @override
  Future<void> sendMessage(String content, String senderName) {
    throw Exception('chat mirror boom');
  }
}

/// Both loveChatControllerProvider and noteitControllerProvider are
/// `autoDispose` -- see love_chat_controller_test.dart's identical helper
/// doc comment for why a persistent `container.listen` is required, not
/// just `container.read`.
ProviderContainer _unpairedContainer({
  LoveChatController Function()? chatOverride,
  NoteitController Function()? noteitOverride,
}) {
  final container = ProviderContainer(
    overrides: [
      coupleSessionProvider.overrideWithValue(CoupleSession()),
      if (chatOverride != null) loveChatControllerProvider.overrideWith(chatOverride),
      if (noteitOverride != null) noteitControllerProvider.overrideWith(noteitOverride),
    ],
  );
  container.listen(loveChatControllerProvider, (prev, next) {});
  container.listen(noteitControllerProvider, (prev, next) {});
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const draftDoc = CanvasDocument(
    background: BackgroundData(type: 'color', color: 0xFFFFFFFF),
    objects: [],
  );

  group('ScrapbookShareUseCase.share', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('full success: note created, chat mirrored, draft cleared', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final noteit = container.read(noteitControllerProvider.notifier);
      final chat = container.read(loveChatControllerProvider.notifier);
      const draftStore = NoteitDraftStore();
      await draftStore.save(draftDoc);

      final useCase = ScrapbookShareUseCase(noteit, chat, draftStore);
      final result = await useCase.share(
        canvasJson: '{}',
        localImagePath: null,
        yourName: 'Me',
      );

      expect(result, isA<ScrapbookShareSuccess>());
      expect((result as ScrapbookShareSuccess).item.content, '{}');
      expect(await draftStore.load(), isNull);
    });

    test('note-creation failure: draft is NOT cleared, no item is returned', () async {
      final container = _unpairedContainer(noteitOverride: _ThrowingNoteitController.new);
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final noteit = container.read(noteitControllerProvider.notifier);
      final chat = container.read(loveChatControllerProvider.notifier);
      const draftStore = NoteitDraftStore();
      await draftStore.save(draftDoc);

      final useCase = ScrapbookShareUseCase(noteit, chat, draftStore);
      final result = await useCase.share(
        canvasJson: '{}',
        localImagePath: null,
        yourName: 'Me',
      );

      expect(result, isA<ScrapbookShareNoteFailed>());
      expect(await draftStore.load(), isNotNull);
    });

    test('chat-mirror failure: note is kept, draft is cleared, distinct error surfaced', () async {
      final container = _unpairedContainer(chatOverride: _ThrowingLoveChatController.new);
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final noteit = container.read(noteitControllerProvider.notifier);
      final chat = container.read(loveChatControllerProvider.notifier);
      const draftStore = NoteitDraftStore();
      await draftStore.save(draftDoc);

      final useCase = ScrapbookShareUseCase(noteit, chat, draftStore);
      final result = await useCase.share(
        canvasJson: '{}',
        localImagePath: null,
        yourName: 'Me',
      );

      expect(result, isA<ScrapbookShareChatMirrorFailed>());
      final failed = result as ScrapbookShareChatMirrorFailed;
      expect(failed.item.content, '{}');
      expect(failed.failure.message, isNotEmpty);
      expect(await draftStore.load(), isNull);
    });
  });
}
