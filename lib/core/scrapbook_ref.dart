/// A typed reference to a scrapbook (noteit) item, shared between the
/// writer (`ScrapbookShareUseCase`, which mirrors a new scrapbook note into
/// love chat) and the reader (the dashboard's chat preview card) so both
/// sides depend on one type instead of a hand-rolled string convention
/// duplicated at two call sites with no compiler connection between them
/// (Migration Phase 8, Definition-of-Done item 14; ADR-013).
///
/// Lives in `lib/core/`, not `lib/features/scrapbook/`, because it
/// describes the shared `love_notes` chat-mirror wire format between the
/// `scrapbook` and `dashboard` features, not scrapbook's own private
/// domain model -- the same reasoning ADR-013 gives for its sibling
/// `love_notes` row-type discriminator.
class ScrapbookRef {
  const ScrapbookRef(this.itemId);

  final String itemId;

  static const _currentPrefix = 'scrapbook:';

  /// The legacy wire prefix used by every scrapbook-mirror chat message
  /// sent before this type existed. Recognized on read so already-sent
  /// production messages (this is a live app, not a fresh schema) keep
  /// rendering correctly; never written going forward.
  static const _legacyPrefix = '[scrapbook]:';

  /// Serializes this reference for storage as a love_chat message's
  /// `content`. Always uses the current (non-legacy) prefix.
  String toChatPayload() => '$_currentPrefix$itemId';

  /// Parses a love_chat message's `content` back into a [ScrapbookRef],
  /// or `null` if it isn't a scrapbook-mirror message at all. Accepts
  /// both the current and legacy wire prefixes -- see [_legacyPrefix].
  static ScrapbookRef? fromChatPayload(String raw) {
    final prefix = raw.startsWith(_currentPrefix)
        ? _currentPrefix
        : raw.startsWith(_legacyPrefix)
            ? _legacyPrefix
            : null;
    if (prefix == null) return null;

    final id = raw.substring(prefix.length).trim();
    if (id.isEmpty) return null;
    return ScrapbookRef(id);
  }

  @override
  bool operator ==(Object other) => other is ScrapbookRef && other.itemId == itemId;

  @override
  int get hashCode => itemId.hashCode;
}
