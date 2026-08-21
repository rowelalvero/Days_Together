import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/features/relationship/presence_state.dart';
import 'package:days_together/providers/relationship_provider.dart';

/// Mirrors `RelationshipProvider`'s 3 presence fields (`isPartnerOnline`,
/// `yourActivity`, `partnerActivity`) into a Riverpod-native read surface
/// (Phase 5 of the architecture migration, unit 5 -- the last of the five).
///
/// **Mirror, not a cutover -- same reasoning as `ProfileController` (unit 3)
/// and `WorkspaceController` (unit 4).** All 3 fields are realtime-driven:
/// `isPartnerOnline` is flipped inside `_initPresence`'s `onPresenceSync`
/// callback on the `couple_presence_<coupleId>` channel
/// (`relationship_provider.dart:615-662`); `partnerActivity` is set from the
/// partner-row realtime sync callback (`_initPartnerUserSync`); and
/// `yourActivity` is both a direct local write
/// (`updateCurrentActivity`) and set from the current user's own realtime
/// row sync. Unlike the license fields (a cutover, Phase 5 unit 2), moving
/// this data's ownership would mean moving `_initPresence` itself --
/// `_presenceChannel`'s full subscribe/unsubscribe/track lifecycle, wired
/// into `_coupleId` change handling, pairing, disconnect, and logout in
/// several places across `relationship_provider.dart`. That is exactly the
/// kind of surgery on a live, working realtime subscription Phase 1 and
/// units 3/4 already declined to attempt in this phase, deferred instead to
/// Phase 6 alongside `CoupleSession`'s, `ProfileController`'s, and
/// `WorkspaceController`'s own equivalent deferrals.
///
/// `RelationshipProvider` remains the single source of truth and keeps
/// `_initPresence`, the presence channel, and `updateCurrentActivity`
/// unchanged. `PresenceController` is updated via [updateFromRelationship],
/// called by `main.dart`'s `_PresenceControllerBridge` on every
/// `RelationshipProvider` change. No write methods exist here -- writes
/// still go through `RelationshipProvider.updateCurrentActivity` directly,
/// unchanged, and flow into this mirror the same way any other field change
/// does.
class PresenceController extends Notifier<PresenceState> {
  @override
  PresenceState build() => const PresenceState();

  /// Called from `main.dart`'s `_PresenceControllerBridge` on every
  /// `RelationshipProvider` change. Only updates (and so only notifies
  /// watchers) when a field actually differs, via [PresenceState]'s value
  /// equality -- the same "don't rebuild for no reason" contract
  /// `CoupleSession.updateFromRelationship` established in Phase 1.
  void updateFromRelationship(RelationshipProvider relationship) {
    final next = PresenceState(
      isPartnerOnline: relationship.isPartnerOnline,
      yourActivity: relationship.yourActivity,
      partnerActivity: relationship.partnerActivity,
    );
    if (next != state) {
      state = next;
    }
  }
}

final presenceControllerProvider = NotifierProvider<PresenceController, PresenceState>(
  PresenceController.new,
);
