enum LoveTapState { idle, sent, received, mutual }

class LoveTapHistory {
  final int completedTaps;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastLoveTap;

  const LoveTapHistory({
    this.completedTaps = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastLoveTap,
  });
}

/// State for `CurrentlyController` (Phase 6a of the architecture migration)
/// -- a direct Riverpod port of `CurrentlyProvider`'s fields.
///
/// **Pre-existing, preserved quirk:** [state] only ever changes from
/// [syncInitialData] indirectly -- the original `syncInitialData` calls
/// only `_loadHistory()`, never touching `_state`, so `state` stays `idle`
/// until the first realtime event arrives even if today's row already
/// shows a tap. Flagged in unit investigation before this phase started;
/// preserved as-is here since fixing it wasn't asked for.
class CurrentlyState {
  final bool isLoading;
  final LoveTapState state;
  final LoveTapHistory history;

  const CurrentlyState({
    this.isLoading = false,
    this.state = LoveTapState.idle,
    this.history = const LoveTapHistory(),
  });

  CurrentlyState copyWith({bool? isLoading, LoveTapState? state, LoveTapHistory? history}) {
    return CurrentlyState(
      isLoading: isLoading ?? this.isLoading,
      state: state ?? this.state,
      history: history ?? this.history,
    );
  }
}
