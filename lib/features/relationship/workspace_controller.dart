import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/features/relationship/workspace_state.dart';
import 'package:days_together/providers/couple_session.dart';

/// Owns a Riverpod-native read+write surface over `CoupleSession`'s 7
/// workspace fields (pairing code, story title, start date/time, premium
/// flag, status, recovery code) -- Phase 6b-1 of the architecture
/// migration, unit 3 ("WorkspaceController real").
///
/// **Delegates to `CoupleSession`, does not duplicate its fields** -- same
/// reasoning as `ProfileController` (unit 2), extended to cover
/// `recoveryCode`'s entangled RPC: `createRelationshipWorkspace()`'s single
/// RPC call sets `CoupleSession`-owned identity fields (`coupleId`,
/// `isCreator`, `isPaired`) and this controller's own `coupleCode`/
/// `recoveryCode`/`status` together, atomically, so delegating the whole
/// call to `CoupleSession.createRelationshipWorkspace()` (rather than
/// reimplementing any slice of it here) is what keeps that atomicity intact.
///
/// **No forcing function requires converting this controller's UI
/// consumers in the same step, unlike unit 1 (`CoupleSession` itself).**
/// `RelationshipProvider`'s facade already serves these 7 fields correctly
/// to every current reader with zero regression regardless of what this
/// controller does, so UI conversion is deferred to Phase 6b-2 (or, for
/// `relationship_license_screen.dart`/`relationship_profile_screen.dart`,
/// to Phase 8's already-planned decomposition) -- the same scope decision
/// made for unit 2, applied here without re-litigating it since the
/// underlying situation (a real hub already serving a working facade) is
/// identical. See docs/architecture/migration-roadmap.md's Phase 6b-1 unit
/// 3 corrections.
class WorkspaceController extends Notifier<WorkspaceState> {
  @override
  WorkspaceState build() => const WorkspaceState();

  /// Called from `main.dart`'s `_WorkspaceControllerBridge` on every
  /// `CoupleSession` change. Only updates (and so only notifies watchers)
  /// when a field actually differs, via [WorkspaceState]'s value equality.
  void updateFromSession(CoupleSession session) {
    final next = WorkspaceState(
      coupleCode: session.coupleCode,
      storyTitle: session.storyTitle,
      startDate: session.startDate,
      startTime: session.startTime,
      isPremium: session.isPremium,
      status: session.status,
      recoveryCode: session.recoveryCode,
    );
    if (next != state) {
      state = next;
    }
  }

  Future<void> setStoryTitle(String title) => ref.read(coupleSessionProvider).setStoryTitle(title);

  Future<void> setStartDate(DateTime date) => ref.read(coupleSessionProvider).setStartDate(date);

  Future<void> setStartTime(TimeOfDay time) => ref.read(coupleSessionProvider).setStartTime(time);

  Future<void> setPremium(bool value) => ref.read(coupleSessionProvider).setPremium(value);

  Future<void> createRelationshipWorkspace() =>
      ref.read(coupleSessionProvider).createRelationshipWorkspace();

  String generateCoupleCode({bool forceRegenerate = false}) =>
      ref.read(coupleSessionProvider).generateCoupleCode(forceRegenerate: forceRegenerate);

  Future<String?> refreshPairingCode({bool forceRotate = false}) =>
      ref.read(coupleSessionProvider).refreshPairingCode(forceRotate: forceRotate);

  Future<void> regenerateRecoveryCode() => ref.read(coupleSessionProvider).regenerateRecoveryCode();

  void clearRecoveryCode() => ref.read(coupleSessionProvider).clearRecoveryCode();
}

final workspaceControllerProvider = NotifierProvider<WorkspaceController, WorkspaceState>(
  WorkspaceController.new,
  dependencies: [coupleSessionProvider],
);
