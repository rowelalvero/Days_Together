import 'package:flutter/foundation.dart';
import 'package:days_together/providers/relationship_provider.dart';

/// The app's single readiness/routing state, replacing today's inline
/// conditional chain in `main.dart`'s `AppHome._buildHomeContent`.
///
/// CURRENT STATE (Phase 1 of the architecture migration): computing this
/// correctly needs one field beyond `CoupleSession`'s own five identity
/// fields -- [startDate] -- to distinguish [needsWorkspace]/[needsGenesis]/
/// [needsAvatar]. The roadmap's original Phase 1 text ("computed once from
/// the five identity fields") undercounted this by one field; `startDate`
/// belongs to `WorkspaceController` (Phase 5), so until that extraction
/// lands, callers pass it in from `RelationshipProvider` directly. See
/// docs/architecture/migration-roadmap.md, Phase 1.
enum SessionStage {
  loading,
  unauthenticated,
  needsWorkspace,
  needsCouple,
  needsGenesis,
  needsAvatar,
  ready,
}

/// Pure readiness computation -- the one function in the codebase that
/// decides "is the user ready for the main app," matching
/// `main.dart`'s pre-Phase-1 `_buildHomeContent` branch-for-branch
/// (verified against `main.dart:188-218`).
SessionStage computeSessionStage({
  required bool isInitialized,
  required String? userId,
  required String? coupleId,
  required bool isCreator,
  required bool isPaired,
  required bool onboardingCompleted,
  required DateTime? startDate,
}) {
  if (!isInitialized) return SessionStage.loading;
  if (userId == null) return SessionStage.unauthenticated;
  if (onboardingCompleted && coupleId != null) return SessionStage.ready;

  if (coupleId != null) {
    if (isCreator) {
      if (!isPaired && startDate == null) return SessionStage.needsWorkspace;
      if (startDate == null) return SessionStage.needsGenesis;
    }
    return SessionStage.needsAvatar;
  }

  return SessionStage.needsCouple;
}

/// Owns the app's session-identity state: the four fields every domain
/// feature provider actually depends on (`userId`, `coupleId`, `partnerId`,
/// `isSupabaseAvailable` -- verified by grep, see
/// docs/architecture/migration-roadmap.md's "Fact 1"), plus the three
/// closely-related pairing/onboarding flags and their five SharedPreferences
/// keys (`PrefsKeys`' "Session / pairing identity" group).
///
/// CURRENT STATE (Phase 1): mirrors [RelationshipProvider] rather than owning
/// the auth listener directly. [RelationshipProvider] remains the single
/// source of truth for these fields until Phase 5 decomposes it field by
/// field. This is a deliberate, lower-risk deviation from the roadmap's
/// original Phase 1 text ("absorbs the auth-listener... becomes the emitter
/// for handlePair/handleRepair/handleDisconnect/handleLogout"): mirroring
/// achieves the identical decoupling of the 12 domain providers (not 13 --
/// `main.dart` has exactly 12 `ChangeNotifierProxyProvider<RelationshipProvider,
/// X>` entries, matching Phase 6's own "12 domain providers" count, which
/// this corrects) with none of the flagged risk (two independent auth
/// listeners racing to fire `handlePair`, or a partially-hydrated listener
/// flashing `unauthenticated` for a signed-in user). The literal
/// auth-listener ownership transfer happens naturally as Phase 5 decomposes
/// `RelationshipProvider`, at which point this class is "formally ported to
/// a Riverpod Notifier" per the roadmap's own Phase 5, step 1.
class CoupleSession extends ChangeNotifier {
  bool _isInitialized = false;
  String? _userId;
  String? _coupleId;
  String? _partnerId;
  bool _isPaired = false;
  bool _isCreator = false;
  bool _onboardingCompleted = false;
  bool _isSupabaseAvailable = false;

  bool get isInitialized => _isInitialized;
  String? get userId => _userId;
  String? get coupleId => _coupleId;
  String? get partnerId => _partnerId;
  bool get isPaired => _isPaired;
  bool get isCreator => _isCreator;
  bool get onboardingCompleted => _onboardingCompleted;
  bool get isSupabaseAvailable => _isSupabaseAvailable;

  /// Called from `main.dart`'s `ChangeNotifierProxyProvider<RelationshipProvider,
  /// CoupleSession>` on every upstream change. Only notifies this session's
  /// own listeners (the 12 domain providers) when an owned field actually
  /// differs -- stricter than `RelationshipProvider`'s own notifications,
  /// which fire on any state change (e.g. a license field edit). This is
  /// safe: every current consumer of these fields already no-ops internally
  /// unless its own credentials changed (see
  /// `RelationshipLifecycleProvider.updateSession`'s `credentialsChanged`
  /// check, and `NoteitSyncManager.initialize`'s idempotent re-init).
  void updateFromRelationship(RelationshipProvider relationship) {
    final changed = _isInitialized != relationship.isInitialized ||
        _userId != relationship.userId ||
        _coupleId != relationship.coupleId ||
        _partnerId != relationship.partnerId ||
        _isPaired != relationship.isPaired ||
        _isCreator != relationship.isCreator ||
        _onboardingCompleted != relationship.onboardingCompleted ||
        _isSupabaseAvailable != relationship.isSupabaseAvailable;

    if (!changed) return;

    _isInitialized = relationship.isInitialized;
    _userId = relationship.userId;
    _coupleId = relationship.coupleId;
    _partnerId = relationship.partnerId;
    _isPaired = relationship.isPaired;
    _isCreator = relationship.isCreator;
    _onboardingCompleted = relationship.onboardingCompleted;
    _isSupabaseAvailable = relationship.isSupabaseAvailable;
    notifyListeners();
  }
}
