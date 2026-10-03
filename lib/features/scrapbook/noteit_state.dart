import 'package:days_together/core/models/paging_status.dart';
import 'package:days_together/shared/models/noteit_model.dart';

/// State for `NoteitController` (Phase 6a of the architecture migration) --
/// a direct Riverpod port of `NoteitProvider`'s `_notes`/`_isLoading`
/// fields. [coupleId] is denormalized onto this state (rather than left as
/// controller-only bookkeeping, unlike other Phase 6a controllers' private
/// `_localMutations`) purely so [visibleNotes] can replicate
/// `NoteitProvider.notes`'s original gating -- `coupleId == null ? const []
/// : ...` -- hides everything, including the locally-prepopulated tutorial
/// content, until the couple is actually paired.
///
/// When paired, [notes] is a PAGE WINDOW of the newest notes
/// (`NoteitController.pageSize` at a time, see [paging]); notes loaded for
/// other reasons -- one a chat message refers to, a Wrapped year -- are in
/// [detached]. [noteById] and [knownNotes] cover both; [noteCount] is the
/// whole-scrapbook total.
class NoteitState {
  final List<NoteitItem> notes;
  final bool isLoading;
  final String? coupleId;
  final PagingStatus paging;

  /// Notes loaded outside the page window, by id.
  final Map<String, NoteitItem> detached;

  /// Every note on the server; null until fetched.
  final int? totalCount;

  const NoteitState({
    this.notes = const [],
    this.isLoading = true,
    this.coupleId,
    this.paging = const PagingStatus(),
    this.detached = const {},
    this.totalCount,
  });

  NoteitState copyWith({
    List<NoteitItem>? notes,
    bool? isLoading,
    String? coupleId,
    PagingStatus? paging,
    Map<String, NoteitItem>? detached,
    int? totalCount,
    bool clearTotalCount = false,
  }) {
    return NoteitState(
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      coupleId: coupleId ?? this.coupleId,
      paging: paging ?? this.paging,
      detached: detached ?? this.detached,
      totalCount: clearTotalCount ? null : (totalCount ?? this.totalCount),
    );
  }

  List<NoteitItem> get visibleNotes =>
      coupleId == null ? const [] : List.unmodifiable(notes);

  /// [visibleNotes] plus notes loaded outside the window, without
  /// duplicates.
  List<NoteitItem> get knownNotes {
    if (coupleId == null) return const [];
    if (detached.isEmpty) return visibleNotes;
    final windowIds = {for (final n in notes) n.id};
    return List.unmodifiable([
      ...notes,
      ...detached.values.where((n) => !windowIds.contains(n.id)),
    ]);
  }

  NoteitItem? noteById(String id) {
    if (coupleId == null) return null;
    for (final n in notes) {
      if (n.id == id) return n;
    }
    return detached[id];
  }

  /// Every note in the scrapbook, not just the loaded window.
  int get noteCount => totalCount ?? visibleNotes.length;

  NoteitItem? get latestReceived {
    for (final n in notes) {
      if (n.sender == 'partner') return n;
    }
    return null;
  }

  NoteitItem? get latestSent {
    for (final n in notes) {
      if (n.sender == 'you') return n;
    }
    return null;
  }
}
