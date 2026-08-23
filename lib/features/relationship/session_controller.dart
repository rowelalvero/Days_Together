import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/features/relationship/session_state.dart';
import 'package:days_together/providers/couple_session.dart';

/// Owns a Riverpod-native read+write surface over `CoupleSession`'s
/// identity/session-lifecycle fields (`isInitialized`, `userId`, `coupleId`,
/// `partnerId`, `isPaired`, `isCreator`, `onboardingCompleted`,
/// `showPartnerDeletedNotice`) -- Item 3 gap-fix, Phase 3 (front 4 of the
/// architecture migration's `provider`-removal item), unit 5, the last of
/// the five hub controllers (after `WorkspaceController`/`ProfileController`/
/// `PresenceController`/`LicenseController`).
///
/// **Delegates to `CoupleSession`, does not duplicate its fields** -- same
/// reasoning as `WorkspaceController`/`ProfileController`. Unlike those two,
/// this controller is **not** `.autoDispose`: it must be readable from the
/// very first frame regardless of pairing state, since `app_router.dart`'s
/// `appRedirect` depends on it for every route decision, including fully
/// logged-out ones -- there is no screen-lifetime or couple-scoping reason
/// to ever tear it down.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  /// Called from `main.dart`'s session bridge on every `CoupleSession`
  /// change. Only updates (and so only notifies watchers) when a field
  /// actually differs, via [SessionState]'s value equality.
  void updateFromSession(CoupleSession session) {
    final next = SessionState(
      isInitialized: session.isInitialized,
      userId: session.userId,
      coupleId: session.coupleId,
      partnerId: session.partnerId,
      isPaired: session.isPaired,
      isCreator: session.isCreator,
      onboardingCompleted: session.onboardingCompleted,
      showPartnerDeletedNotice: session.showPartnerDeletedNotice,
    );
    if (next != state) {
      state = next;
    }
  }

  Future<bool> joinWithCode(String code) => ref.read(coupleSessionProvider).joinWithCode(code);

  Future<void> completeOnboarding() => ref.read(coupleSessionProvider).completeOnboarding();

  Future<bool> recoverRelationship(String code) =>
      ref.read(coupleSessionProvider).recoverRelationship(code);

  Future<void> unlinkPartner() => ref.read(coupleSessionProvider).unlinkPartner();

  Future<void> deleteAccount() => ref.read(coupleSessionProvider).deleteAccount();

  Future<void> signUpWithEmail(String email, String password) =>
      ref.read(coupleSessionProvider).signUpWithEmail(email, password);

  Future<void> signInWithEmail(String email, String password) =>
      ref.read(coupleSessionProvider).signInWithEmail(email, password);

  Future<void> signInWithGoogle() => ref.read(coupleSessionProvider).signInWithGoogle();

  Future<void> logout({bool wipeAll = false}) =>
      ref.read(coupleSessionProvider).logout(wipeAll: wipeAll);

  void forceInitialized() => ref.read(coupleSessionProvider).forceInitialized();

  void clearPartnerDeletedNotice() => ref.read(coupleSessionProvider).clearPartnerDeletedNotice();
}

final sessionControllerProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
  dependencies: [coupleSessionProvider],
);
