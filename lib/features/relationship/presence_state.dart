/// The 3 presence fields `PresenceController` mirrors from `CoupleSession`
/// (Phase 6b-1 of the architecture migration, unit 4). See
/// `presence_controller.dart`'s doc comment for the delegation design.
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
