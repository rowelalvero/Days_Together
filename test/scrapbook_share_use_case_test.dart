import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/features/scrapbook/data/noteit_draft_store.dart';
import 'package:days_together/features/scrapbook/domain/scrapbook_share_use_case.dart';
import 'package:days_together/models/canvas_document.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/providers/love_chat_provider.dart';
import 'package:days_together/providers/noteit_provider.dart';

/// Forces the note-creation step to fail, to exercise
/// ScrapbookShareNoteFailed without needing a real Supabase failure.
class _ThrowingNoteitProvider extends NoteitProvider {
  @override
  Future<NoteitItem> sendCanvas(String jsonContent, String? localImagePath) {
    throw Exception('note creation boom');
  }
}

/// Forces the chat-mirror step to fail, to exercise
/// ScrapbookShareChatMirrorFailed. LoveChatProvider.sendMessage currently
/// swallows its own Supabase errors internally (see migration-roadmap.md
/// Phase 8's note), so this is the only way to exercise this branch today.
class _ThrowingLoveChatProvider extends LoveChatProvider {
  @override
  Future<void> sendMessage(String content, String senderName) {
    throw Exception('chat mirror boom');
  }
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
      final noteit = NoteitProvider();
      final chat = LoveChatProvider();
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

      noteit.dispose();
      chat.dispose();
    });

    test('note-creation failure: draft is NOT cleared, no item is returned', () async {
      final noteit = _ThrowingNoteitProvider();
      final chat = LoveChatProvider();
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

      noteit.dispose();
      chat.dispose();
    });

    test('chat-mirror failure: note is kept, draft is cleared, distinct error surfaced', () async {
      final noteit = NoteitProvider();
      final chat = _ThrowingLoveChatProvider();
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

      noteit.dispose();
      chat.dispose();
    });
  });
}
