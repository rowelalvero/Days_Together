/// Centralized registry of every SharedPreferences key originally owned by
/// `RelationshipProvider` (session identity, pairing, license fields, and
/// workspace fields) -- 41 keys, verified by direct extraction from
/// `lib/providers/relationship_provider.dart` as of architecture Phase 0.
/// `RelationshipProvider` itself was later deleted (Definition-of-Done
/// sweep item 4); these keys are now owned by `CoupleSession` and the
/// controllers it feeds. 1 more (`timelineIsAscending`)
/// were added once the Definition-of-Done sweep found their owning
/// controllers already touched but still using raw literals, per the
/// incremental-centralization plan below.
///
/// This is a **compatibility contract**, not a convenience list: these exact
/// strings are the hydration data for real, already-installed users on real
/// devices. Never rename a value here without a deliberate migration
/// mechanism (read-old-write-new-drop-old over a release cycle) -- see
/// docs/architecture/caching-strategy.md.
///
/// Scope note (Phase 0): this registry originally covered only
/// RelationshipProvider's 41 keys, matching that phase's exit criteria.
/// Theme/music settings and the noteit draft key remain separate and are
/// centralized incrementally as their owning features are touched -- see
/// docs/architecture/architecture-rules.md, Rule 14.
///
/// Existing call sites in `relationship_provider.dart` are NOT rewritten to
/// use this registry in Phase 0; that happens naturally as each field is
/// extracted into its owning controller in Phase 5
/// (docs/architecture/migration-roadmap.md).
class PrefsKeys {
  PrefsKeys._();

  // ---- Session / pairing identity (owned by CoupleSession, Phase 1) ----
  /// The signed-in Supabase user id, mirrored so a cold start knows who
  /// is signed in before the async auth listener resolves -- the same
  /// reason [coupleId] and [partnerId] are mirrored. Without it,
  /// `computeSessionStage` saw a null userId on a warm launch and could
  /// route a returning user to the welcome screen until auth caught up.
  ///
  /// Cleared explicitly on the auth listener's signed-out branch:
  /// `logout()` wipes all prefs, but a server-side revocation or an
  /// expired refresh token does not, and a stale id here would leave the
  /// app believing it is signed in.
  static const String userId = 'user_id';
  static const String coupleId = 'couple_id';
  static const String partnerId = 'partner_id';
  static const String isPaired = 'is_paired';
  static const String isCreator = 'is_creator';
  static const String onboardingCompleted = 'onboarding_completed';

  // ---- Workspace fields (owned by WorkspaceController, Phase 5) ----
  static const String coupleCode = 'couple_code';
  static const String isPremium = 'is_premium';
  static const String storyTitle = 'story_title';
  static const String relationshipStartDate = 'relationship_start_date';
  static const String relationshipStartHour = 'relationship_start_hour';
  static const String relationshipStartMinute = 'relationship_start_minute';

  // ---- Profile fields (owned by ProfileController, Phase 5) ----
  static const String yourName = 'your_name';
  static const String partnerName = 'partner_name';
  static const String yourAvatarPath = 'your_avatar_path';
  static const String partnerAvatarPath = 'partner_avatar_path';
  static const String yourJoinDate = 'your_join_date';
  static const String partnerJoinDate = 'partner_join_date';

  // ---- License fields, paired your_*/partner_* (owned by
  //      LicenseController, Phase 5 -- see migration-roadmap.md's Phase 0
  //      section for why these live-write through `users`, not
  //      `license_details`, despite the naming) ----
  static const String yourGender = 'your_gender';
  static const String partnerGender = 'partner_gender';
  static const String yourPhone = 'your_phone';
  static const String partnerPhone = 'partner_phone';
  static const String yourBirthdate = 'your_birthdate';
  static const String partnerBirthdate = 'partner_birthdate';
  static const String yourAddress = 'your_address';
  static const String partnerAddress = 'partner_address';
  static const String yourNationality = 'your_nationality';
  static const String partnerNationality = 'partner_nationality';
  static const String yourWeight = 'your_weight';
  static const String partnerWeight = 'partner_weight';
  static const String yourHeight = 'your_height';
  static const String partnerHeight = 'partner_height';
  static const String yourBloodType = 'your_blood_type';
  static const String partnerBloodType = 'partner_blood_type';
  static const String yourEyeColor = 'your_eye_color';
  static const String partnerEyeColor = 'partner_eye_color';
  static const String yourConditions = 'your_conditions';
  static const String partnerConditions = 'partner_conditions';
  static const String yourDateIssued = 'your_date_issued';
  static const String partnerDateIssued = 'partner_date_issued';
  static const String yourSignature = 'your_signature';
  static const String partnerSignature = 'partner_signature';

  // ---- Incrementally added as later-touched features' keys were found
  //      still using raw literals instead of this registry (per this
  //      file's own "centralized incrementally" scope note above) ----
  static const String timelineIsAscending = 'timeline_is_ascending';

  /// All 42 keys, for verification (e.g. the Phase 0 exit-criteria test
  /// asserting `PrefsKeys.all.length == 42`). Was 43 before the Secret
  /// Vault's `vaultPinFallback` was removed with that feature.
  static const List<String> all = [
    userId,
    coupleId,
    partnerId,
    isPaired,
    isCreator,
    onboardingCompleted,
    coupleCode,
    isPremium,
    storyTitle,
    relationshipStartDate,
    relationshipStartHour,
    relationshipStartMinute,
    yourName,
    partnerName,
    yourAvatarPath,
    partnerAvatarPath,
    yourJoinDate,
    partnerJoinDate,
    yourGender,
    partnerGender,
    yourPhone,
    partnerPhone,
    yourBirthdate,
    partnerBirthdate,
    yourAddress,
    partnerAddress,
    yourNationality,
    partnerNationality,
    yourWeight,
    partnerWeight,
    yourHeight,
    partnerHeight,
    yourBloodType,
    partnerBloodType,
    yourEyeColor,
    partnerEyeColor,
    yourConditions,
    partnerConditions,
    yourDateIssued,
    partnerDateIssued,
    yourSignature,
    partnerSignature,
    timelineIsAscending,
  ];
}
