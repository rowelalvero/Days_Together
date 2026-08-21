import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/features/relationship/profile_state.dart';
import 'package:days_together/providers/relationship_provider.dart';

/// Mirrors `RelationshipProvider`'s 6 profile fields (name, avatar path,
/// join date -- both "your" and "partner" sides) into a Riverpod-native
/// read surface (Phase 5 of the architecture migration, unit 3).
///
/// **Mirror, not a cutover -- deliberately, unlike `LicenseController`.**
/// The license fields were pure local writes with no realtime dependency,
/// which is what made deleting them from `RelationshipProvider` and moving
/// the write path safe. These 6 fields are different: they are actively
/// kept in sync by live Supabase realtime streams woven through
/// `_initSupabaseSync`'s and `_initPartnerUserSync`'s ~400 combined lines in
/// `relationship_provider.dart` -- the same kind of deep entanglement Phase
/// 1 found for `CoupleSession` and deliberately did not disturb. Extracting
/// the realtime logic itself now would be surgery on a live, working
/// subscription callback for comparatively little benefit, since nothing
/// yet depends on `ProfileController` the way the 12 domain providers
/// depend on `CoupleSession`.
///
/// So, like `CoupleSession`: `RelationshipProvider` remains the single
/// source of truth and keeps every one of its existing name/avatar/
/// join-date fields and realtime sync logic untouched. `ProfileController`
/// is updated via [updateFromRelationship], called by `main.dart`'s
/// `_ProfileControllerBridge` on every `RelationshipProvider` change. No
/// write methods exist here -- writes still go through
/// `RelationshipProvider.setYourName`/`setNames`/`setAvatars` directly,
/// unchanged, and flow into this mirror the same way any other field
/// change does. The real ownership transfer (moving the realtime listener
/// itself) is deferred to Phase 6, alongside `CoupleSession`'s own -- see
/// docs/architecture/migration-roadmap.md's Phase 5 corrections.
class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() => const ProfileState();

  /// Called from `main.dart`'s `_ProfileControllerBridge` on every
  /// `RelationshipProvider` change. Only updates (and so only notifies
  /// watchers) when a field actually differs, via [ProfileState]'s value
  /// equality -- the same "don't rebuild for no reason" contract
  /// `CoupleSession.updateFromRelationship` established in Phase 1.
  void updateFromRelationship(RelationshipProvider relationship) {
    final next = ProfileState(
      yourName: relationship.yourName,
      partnerName: relationship.partnerName,
      yourAvatarPath: relationship.yourAvatarPath,
      partnerAvatarPath: relationship.partnerAvatarPath,
      yourJoinDate: relationship.yourJoinDate,
      partnerJoinDate: relationship.partnerJoinDate,
    );
    if (next != state) {
      state = next;
    }
  }
}

final profileControllerProvider = NotifierProvider<ProfileController, ProfileState>(
  ProfileController.new,
);
