import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/features/relationship/presence_state.dart';
import 'package:days_together/providers/couple_session.dart';

/// Owns a Riverpod-native read+write surface over `CoupleSession`'s 3
/// presence fields (`isPartnerOnline`, `yourActivity`, `partnerActivity`) --
/// Phase 6b-1 of the architecture migration, unit 4 (the last of the four,
/// closing out the merged 6b-1/6b-2 per-controller sequence).
///
/// **Delegates to `CoupleSession`, does not duplicate its fields** -- same
/// reasoning as `ProfileController` (unit 2) and `WorkspaceController`
/// (unit 3). `isPartnerOnline` and `partnerActivity` have no write path at
/// all (purely realtime-driven, via `_initPresence`'s presence channel and
/// the partner-row sync respectively); only `yourActivity` has one
/// (`updateCurrentActivity`), delegated below. No forcing function requires
/// converting this controller's UI consumers in the same step (the same
/// reasoning as units 2/3, applied without re-litigating it) -- deferred to
/// Phase 6b-2. See docs/architecture/migration-roadmap.md's Phase 6b-1 unit
/// 4 corrections.
class PresenceController extends Notifier<PresenceState> {
  @override
  PresenceState build() => const PresenceState();

  /// Called from `main.dart`'s `_PresenceControllerBridge` on every
  /// `CoupleSession` change. Only updates (and so only notifies watchers)
  /// when a field actually differs, via [PresenceState]'s value equality.
  void updateFromSession(CoupleSession session) {
    final next = PresenceState(
      isPartnerOnline: session.isPartnerOnline,
      yourActivity: session.yourActivity,
      partnerActivity: session.partnerActivity,
    );
    if (next != state) {
      state = next;
    }
  }

  Future<void> updateCurrentActivity(String? activity) =>
      ref.read(coupleSessionProvider).updateCurrentActivity(activity);
}

final presenceControllerProvider = NotifierProvider<PresenceController, PresenceState>(
  PresenceController.new,
  dependencies: [coupleSessionProvider],
);
