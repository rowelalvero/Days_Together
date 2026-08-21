import 'package:days_together/models/noteit_model.dart';

/// State for `NoteitController` (Phase 6a of the architecture migration) --
/// a direct Riverpod port of `NoteitProvider`'s `_notes`/`_isLoading`
/// fields. [coupleId] is denormalized onto this state (rather than left as
/// controller-only bookkeeping, unlike other Phase 6a controllers' private
/// `_localMutations`) purely so [visibleNotes] can replicate
/// `NoteitProvider.notes`'s original gating -- `coupleId == null ? const []
/// : ...` -- hides everything, including the locally-prepopulated tutorial
/// content, until the couple is actually paired.
class NoteitState {
  final List<NoteitItem> notes;
  final bool isLoading;
  final String? coupleId;

  const NoteitState({this.notes = const [], this.isLoading = true, this.coupleId});

  NoteitState copyWith({List<NoteitItem>? notes, bool? isLoading, String? coupleId}) {
    return NoteitState(
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      coupleId: coupleId ?? this.coupleId,
    );
  }

  List<NoteitItem> get visibleNotes => coupleId == null ? const [] : List.unmodifiable(notes);

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
