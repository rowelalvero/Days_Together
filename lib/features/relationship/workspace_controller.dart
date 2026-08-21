import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/features/relationship/workspace_state.dart';
import 'package:days_together/providers/relationship_provider.dart';

/// Mirrors `RelationshipProvider`'s 7 workspace fields (pairing code, story
/// title, start date/time, premium flag, status, recovery code) into a
/// Riverpod-native read surface (Phase 5 of the architecture migration,
/// unit 4).
///
/// **Mirror, not a cutover -- same reasoning as `ProfileController`
/// (unit 3), extended to cover a field with no realtime dependency.** 6 of
/// the 7 fields (`coupleCode`, `storyTitle`, `startDate`, `startTime`,
/// `isPremium`, `status`) are written live inside `_initSupabaseSync`'s
/// `_coupleSub` Supabase realtime listener (`relationship_provider.dart`,
/// the `.from('couples').stream(...)` callback) -- the same entanglement
/// that made `ProfileController` a mirror. The 7th, `recoveryCode`, is not
/// realtime-synced, but its value is produced by
/// `RelationshipProvider.createRelationshipWorkspace()`'s single RPC call,
/// the same call that also sets `CoupleSession`-owned fields (`coupleId`,
/// `isPaired`, `isCreator`) and this controller's own `coupleCode`/`status`.
/// Cutting `recoveryCode` over on its own would mean either duplicating that
/// RPC call from a new write path (risking two workspaces being created) or
/// having `RelationshipProvider` push into Riverpod from non-widget code --
/// exactly the global-container infrastructure the Phase 5/5b merge
/// decision already ruled out. So all 7 fields are mirrored together.
///
/// `RelationshipProvider` remains the single source of truth and keeps
/// every one of its existing workspace fields, setters
/// (`setStoryTitle`/`setStartDate`/`setStartTime`/`setPremium`/
/// `regenerateRecoveryCode`/`clearRecoveryCode`/`createRelationshipWorkspace`/
/// `joinWithCode`/etc.), and realtime sync logic untouched. `togglePremium()`
/// was confirmed to have zero callers repo-wide during this unit's
/// investigation and was left in place rather than ported -- it was already
/// dead before this extraction, and porting unreachable API surface forward
/// would be exactly the kind of unrequested feature-preservation
/// `CLAUDE.md` asks this codebase to avoid.
///
/// `WorkspaceController` is updated via [updateFromRelationship], called by
/// `main.dart`'s `_WorkspaceControllerBridge` on every `RelationshipProvider`
/// change. No write methods exist here -- writes still go through
/// `RelationshipProvider` directly, unchanged, and flow into this mirror the
/// same way any other field change does. The real ownership transfer
/// (moving the realtime listener itself) is deferred to Phase 6, alongside
/// `CoupleSession`'s and `ProfileController`'s own -- see
/// docs/architecture/migration-roadmap.md's Phase 5 corrections.
class WorkspaceController extends Notifier<WorkspaceState> {
  @override
  WorkspaceState build() => const WorkspaceState();

  /// Called from `main.dart`'s `_WorkspaceControllerBridge` on every
  /// `RelationshipProvider` change. Only updates (and so only notifies
  /// watchers) when a field actually differs, via [WorkspaceState]'s value
  /// equality -- the same "don't rebuild for no reason" contract
  /// `CoupleSession.updateFromRelationship` established in Phase 1.
  void updateFromRelationship(RelationshipProvider relationship) {
    final next = WorkspaceState(
      coupleCode: relationship.coupleCode,
      storyTitle: relationship.storyTitle,
      startDate: relationship.startDate,
      startTime: relationship.startTime,
      isPremium: relationship.isPremium,
      status: relationship.status,
      recoveryCode: relationship.recoveryCode,
    );
    if (next != state) {
      state = next;
    }
  }
}

final workspaceControllerProvider = NotifierProvider<WorkspaceController, WorkspaceState>(
  WorkspaceController.new,
);
