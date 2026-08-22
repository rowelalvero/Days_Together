import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/features/relationship/profile_state.dart';
import 'package:days_together/providers/couple_session.dart';

/// Owns a Riverpod-native read+write surface over `CoupleSession`'s 6
/// profile fields (name, avatar path, join date -- both "your" and
/// "partner" sides) -- Phase 6b-1 of the architecture migration, unit 2
/// ("ProfileController real").
///
/// **Delegates to `CoupleSession`, does not duplicate its fields.**
/// `CoupleSession` (Phase 6b-1 unit 1) is the sole permitted subscriber to
/// the `users`/`couples` realtime streams that keep these 6 fields live --
/// see couple_session.dart's doc comment for why a second independent
/// owner isn't possible. Unlike unit 1 (`CoupleSession` itself), there is
/// no forcing function requiring this controller's UI consumers to convert
/// in the same step: `RelationshipProvider`'s facade already serves these
/// fields correctly to every current reader with zero regression, so UI
/// conversion is deferred to Phase 6b-2 (or, for the two largest consumers,
/// `relationship_license_screen.dart`/`relationship_profile_screen.dart`,
/// to Phase 8's already-planned decomposition of those files) rather than
/// bundled here. See docs/architecture/migration-roadmap.md's Phase 6b-1
/// unit 2 corrections for the full investigation.
///
/// [setYourName]/[setNames]/[setAvatars] are one-line delegations to the
/// live `CoupleSession` instance -- the actual field mutation, persistence,
/// and Supabase sync logic already lives there (moved from
/// `RelationshipProvider` in unit 1) and is not duplicated here. The state
/// update this controller's watchers see flows back through the same
/// `updateFromSession` mirror path every other change does, via
/// `main.dart`'s `_ProfileControllerBridge` reacting to `CoupleSession`'s
/// `notifyListeners()`.
class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() => const ProfileState();

  /// Called from `main.dart`'s `_ProfileControllerBridge` on every
  /// `CoupleSession` change. Only updates (and so only notifies watchers)
  /// when a field actually differs, via [ProfileState]'s value equality --
  /// the same "don't rebuild for no reason" contract
  /// `CoupleSession`'s own hydration establishes.
  void updateFromSession(CoupleSession session) {
    final next = ProfileState(
      yourName: session.yourName,
      partnerName: session.partnerName,
      yourAvatarPath: session.yourAvatarPath,
      partnerAvatarPath: session.partnerAvatarPath,
      yourJoinDate: session.yourJoinDate,
      partnerJoinDate: session.partnerJoinDate,
    );
    if (next != state) {
      state = next;
    }
  }

  Future<void> setYourName(String name) => ref.read(coupleSessionProvider).setYourName(name);

  Future<void> setNames(String yours, String partner) =>
      ref.read(coupleSessionProvider).setNames(yours, partner);

  Future<void> setAvatars({String? yourPath, String? partnerPath}) => ref
      .read(coupleSessionProvider)
      .setAvatars(yourPath: yourPath, partnerPath: partnerPath);
}

final profileControllerProvider = NotifierProvider<ProfileController, ProfileState>(
  ProfileController.new,
  dependencies: [coupleSessionProvider],
);
