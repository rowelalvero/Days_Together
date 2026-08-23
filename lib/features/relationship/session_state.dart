/// The identity/session-lifecycle fields `SessionController` mirrors from
/// `CoupleSession` (Item 3 gap-fix, Phase 3 -- front 4 of the architecture
/// migration's `provider`-removal item, unit 5, the last of the five hub
/// controllers). See `session_controller.dart`'s doc comment for the
/// delegation design shared with `WorkspaceController`/`ProfileController`/
/// `PresenceController`.
///
/// [isOnboardingComplete]/[isSupabaseAvailable] stay as derived getters,
/// computed the same way `CoupleSession` computes them, rather than stored
/// fields -- mirroring how `WorkspaceState.storyTitle` already mirrors a
/// derived (defaulted) value instead of a raw nullable one.
class SessionState {
  final bool isInitialized;
  final String? userId;
  final String? coupleId;
  final String? partnerId;
  final bool isPaired;
  final bool isCreator;
  final bool onboardingCompleted;
  final bool showPartnerDeletedNotice;

  const SessionState({
    this.isInitialized = false,
    this.userId,
    this.coupleId,
    this.partnerId,
    this.isPaired = false,
    this.isCreator = false,
    this.onboardingCompleted = false,
    this.showPartnerDeletedNotice = false,
  });

  bool get isOnboardingComplete => onboardingCompleted && coupleId != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionState &&
        other.isInitialized == isInitialized &&
        other.userId == userId &&
        other.coupleId == coupleId &&
        other.partnerId == partnerId &&
        other.isPaired == isPaired &&
        other.isCreator == isCreator &&
        other.onboardingCompleted == onboardingCompleted &&
        other.showPartnerDeletedNotice == showPartnerDeletedNotice;
  }

  @override
  int get hashCode => Object.hash(
        isInitialized,
        userId,
        coupleId,
        partnerId,
        isPaired,
        isCreator,
        onboardingCompleted,
        showPartnerDeletedNotice,
      );
}
