import 'package:days_together/core/errors/app_failure.dart';
import 'package:days_together/core/scrapbook_ref.dart';
import 'package:days_together/features/scrapbook/data/noteit_draft_store.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/providers/love_chat_provider.dart';
import 'package:days_together/providers/noteit_provider.dart';

/// The outcome of [ScrapbookShareUseCase.share]. Sealed so callers must
/// handle all three cases -- in particular, so a chat-mirror failure can't
/// be silently treated the same as full success (the bug this use case
/// fixes; see the type's own doc comment below).
sealed class ScrapbookShareResult {
  const ScrapbookShareResult();
}

/// Both the note and its chat mirror were created successfully.
class ScrapbookShareSuccess extends ScrapbookShareResult {
  const ScrapbookShareSuccess(this.item);
  final NoteitItem item;
}

/// The note itself was never created -- nothing was shared, and the local
/// draft was NOT cleared (so the user's work isn't lost).
class ScrapbookShareNoteFailed extends ScrapbookShareResult {
  const ScrapbookShareNoteFailed(this.failure);
  final AppFailure failure;
}

/// The note was created (and is visible to the couple) but mirroring a
/// reference to it into love chat failed. Surfaced distinctly rather than
/// swallowed, so the UI can say "shared to scrapbook, but couldn't notify
/// chat" instead of either silently failing or claiming full success.
class ScrapbookShareChatMirrorFailed extends ScrapbookShareResult {
  const ScrapbookShareChatMirrorFailed(this.item, this.failure);
  final NoteitItem item;
  final AppFailure failure;
}

/// Owns the noteit canvas's five-step share transaction (Migration Phase
/// 8, Definition-of-Done item 15; ADR-009's one sanctioned `domain/`
/// class): create the scrapbook note, mirror a [ScrapbookRef] to it into
/// love chat, and clear the local draft. Extracted out of
/// `NoteitScreen._sendCanvas`, which embedded this as a widget method with
/// no test coverage and no recovery path when a step failed partway
/// through.
///
/// No step here is transactional with any other -- that was already true
/// before this extraction and isn't a regression to "fix": if the note
/// mirrors into chat but the app crashes before returning, the note still
/// exists (correct: it's real user content). What this class changes is
/// that a chat-mirror failure is no longer silently `debugPrint`-swallowed
/// -- it comes back as [ScrapbookShareChatMirrorFailed] so the UI can
/// choose to tell the user.
class ScrapbookShareUseCase {
  const ScrapbookShareUseCase(this._noteitProvider, this._chatProvider, this._draftStore);

  final NoteitProvider _noteitProvider;
  final LoveChatProvider _chatProvider;
  final NoteitDraftStore _draftStore;

  /// [canvasJson] and [localImagePath] are the already-rendered/serialized
  /// canvas (rendering a live `PainterController` to a PNG is a UI-layer
  /// concern that stays in the screen, not this domain class).
  Future<ScrapbookShareResult> share({
    required String canvasJson,
    String? localImagePath,
    required String yourName,
  }) async {
    final NoteitItem newItem;
    try {
      newItem = await _noteitProvider.sendCanvas(canvasJson, localImagePath);
    } catch (e) {
      return ScrapbookShareNoteFailed(mapExceptionToFailure(e));
    }

    // The note exists now, regardless of what happens next -- clear the
    // draft before attempting the chat mirror, matching the original
    // _sendCanvas's ordering (draft clears whenever note creation
    // succeeded, independent of the chat-mirror outcome).
    await _draftStore.clear();

    try {
      final ref = ScrapbookRef(newItem.id);
      await _chatProvider.sendMessage(ref.toChatPayload(), yourName);
    } catch (e) {
      return ScrapbookShareChatMirrorFailed(newItem, mapExceptionToFailure(e));
    }

    return ScrapbookShareSuccess(newItem);
  }
}
