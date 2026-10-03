/// One realtime change to a couple-scoped row, delivered instead of the full
/// table (audit F-18). `.stream()` re-fetches every matching row on
/// subscribe and on every reconnect, then re-emits the whole list on every
/// change; for `love_notes` (chat + doodle strokes) that is megabytes per app
/// launch. Controllers that opt in (SupabaseLifecycleNotifier.usesRowChanges)
/// load a bounded snapshot over REST and apply these changes to it.
enum RowChangeType {
  insert,
  update,
  delete,

  /// The change feed is LIVE (Postgres confirmed the subscription) -- on the
  /// first connect and after every reconnect. Changes committed before this
  /// point were not delivered, so the receiver (re)loads its snapshot now.
  /// Realtime reports a channel SUBSCRIBED seconds before this; anything
  /// committed in that window is lost, which is why loading on SUBSCRIBED (or
  /// before subscribing) is not enough (verified against the real server,
  /// test/e2e/realtime_e2e_test.dart).
  ready,
}

class RowChange {
  const RowChange({
    required this.type,
    this.newRecord = const {},
    this.oldRecord = const {},
  });

  const RowChange.ready() : this(type: RowChangeType.ready);

  final RowChangeType type;

  /// The row after an insert/update. Empty for a delete.
  final Map<String, dynamic> newRecord;

  /// For a delete, the removed row's identity. With RLS enabled, Realtime
  /// sends only the primary key here, so receivers must rely on `id` alone.
  final Map<String, dynamic> oldRecord;

  /// The affected row's id, for any data change.
  String? get id => (newRecord['id'] ?? oldRecord['id']) as String?;
}
