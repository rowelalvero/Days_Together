import 'package:flutter/material.dart' show TimeOfDay;

import 'package:days_together/providers/couple_session.dart' show RelationshipStatus;

/// The 7 workspace fields `WorkspaceController` mirrors from
/// `RelationshipProvider` (Phase 5 of the architecture migration, unit 4).
/// See `workspace_controller.dart`'s doc comment for why this is a mirror
/// rather than a cutover, unlike `LicenseController`.
///
/// [storyTitle] mirrors `RelationshipProvider.storyTitle`'s own return value
/// as-is (already defaulted to `'Our Story'` when unset) rather than the raw
/// nullable field, since the provider exposes no raw getter to mirror
/// instead -- see `workspace_controller.dart`'s doc comment.
class WorkspaceState {
  final String? coupleCode;
  final String storyTitle;
  final DateTime? startDate;
  final TimeOfDay? startTime;
  final bool isPremium;
  final RelationshipStatus status;
  final String? recoveryCode;

  const WorkspaceState({
    this.coupleCode,
    this.storyTitle = 'Our Story',
    this.startDate,
    this.startTime,
    this.isPremium = false,
    this.status = RelationshipStatus.disconnected,
    this.recoveryCode,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkspaceState &&
        other.coupleCode == coupleCode &&
        other.storyTitle == storyTitle &&
        other.startDate == startDate &&
        other.startTime == startTime &&
        other.isPremium == isPremium &&
        other.status == status &&
        other.recoveryCode == recoveryCode;
  }

  @override
  int get hashCode => Object.hash(
        coupleCode,
        storyTitle,
        startDate,
        startTime,
        isPremium,
        status,
        recoveryCode,
      );
}
