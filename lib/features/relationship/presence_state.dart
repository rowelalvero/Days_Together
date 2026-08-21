/// The 3 presence fields `PresenceController` mirrors from
/// `RelationshipProvider` (Phase 5 of the architecture migration, unit 5).
/// See `presence_controller.dart`'s doc comment for why this is a mirror
/// rather than a cutover, consistent with `ProfileController`/
/// `WorkspaceController`.
class PresenceState {
  final bool isPartnerOnline;
  final String? yourActivity;
  final String? partnerActivity;

  const PresenceState({
    this.isPartnerOnline = false,
    this.yourActivity,
    this.partnerActivity,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresenceState &&
        other.isPartnerOnline == isPartnerOnline &&
        other.yourActivity == yourActivity &&
        other.partnerActivity == partnerActivity;
  }

  @override
  int get hashCode => Object.hash(isPartnerOnline, yourActivity, partnerActivity);
}
