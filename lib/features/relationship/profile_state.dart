/// The 6 profile fields `ProfileController` mirrors from `CoupleSession`
/// (originally mirrored from `RelationshipProvider`, Phase 5 of the
/// architecture migration, unit 3, before `RelationshipProvider` was
/// deleted). See `profile_controller.dart`'s doc comment for why this is a
/// mirror rather than a cutover, unlike `LicenseController`.
class ProfileState {
  final String? yourName;
  final String? partnerName;
  final String? yourAvatarPath;
  final String? partnerAvatarPath;
  final DateTime? yourJoinDate;
  final DateTime? partnerJoinDate;

  const ProfileState({
    this.yourName,
    this.partnerName,
    this.yourAvatarPath,
    this.partnerAvatarPath,
    this.yourJoinDate,
    this.partnerJoinDate,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileState &&
        other.yourName == yourName &&
        other.partnerName == partnerName &&
        other.yourAvatarPath == yourAvatarPath &&
        other.partnerAvatarPath == partnerAvatarPath &&
        other.yourJoinDate == yourJoinDate &&
        other.partnerJoinDate == partnerJoinDate;
  }

  @override
  int get hashCode => Object.hash(
        yourName,
        partnerName,
        yourAvatarPath,
        partnerAvatarPath,
        yourJoinDate,
        partnerJoinDate,
      );
}
