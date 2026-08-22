/// Sentinel used by [LicenseDetails.copyWith] to distinguish "not provided"
/// from "explicitly cleared to null" for nullable fields.
const Object _unset = Object();

/// The 12 paired `your*`/`partner*` license fields `LicenseController` owns
/// (Phase 5 of the architecture migration).
///
/// **Scope correction vs. the roadmap's original "28 fields" figure:**
/// `relationship_provider.dart`'s `updateLicense` method has 28 parameters,
/// but 4 of them (`yourName`/`partnerName`/`yourAvatarPath`/`partnerAvatarPath`)
/// are `ProfileController`'s fields (per the roadmap's own "Profile fields"
/// `PrefsKeys` group and its own separate Phase 5 unit 3 description) that
/// happen to be updatable through the same bulk-edit method, not
/// `LicenseController`'s. This model owns exactly the 12 pairs (24 fields)
/// verified against the now-deleted `relationship_provider.dart`'s getters
/// (`:184-207` as of the migration phase that did the verification): gender,
/// phone, birthdate, address, nationality, weight, height, blood type, eye
/// color, conditions, date issued, signature.
///
/// Deliberately **not** baking the UI-display defaults
/// (the old `RelationshipProvider.yourNationality` etc. returned `'Love
/// Land'` when null, several returned `'—'` or `'Madly in Love'`) into this
/// model --
/// consistent with `UserRepository`/`CoupleRepository`/`LicenseRepository`'s
/// models (Phase 4), a value object represents raw data, not presentation
/// formatting. Call sites apply the same fallback inline, matching exactly
/// what the getter they're replacing did.
class LicenseDetails {
  final String? yourGender;
  final String? partnerGender;
  final String? yourPhone;
  final String? partnerPhone;
  final DateTime? yourBirthdate;
  final DateTime? partnerBirthdate;
  final String? yourAddress;
  final String? partnerAddress;
  final String? yourNationality;
  final String? partnerNationality;
  final String? yourWeight;
  final String? partnerWeight;
  final String? yourHeight;
  final String? partnerHeight;
  final String? yourBloodType;
  final String? partnerBloodType;
  final String? yourEyeColor;
  final String? partnerEyeColor;
  final String? yourConditions;
  final String? partnerConditions;
  final DateTime? yourDateIssued;
  final DateTime? partnerDateIssued;
  final String? yourSignature;
  final String? partnerSignature;

  const LicenseDetails({
    this.yourGender,
    this.partnerGender,
    this.yourPhone,
    this.partnerPhone,
    this.yourBirthdate,
    this.partnerBirthdate,
    this.yourAddress,
    this.partnerAddress,
    this.yourNationality,
    this.partnerNationality,
    this.yourWeight,
    this.partnerWeight,
    this.yourHeight,
    this.partnerHeight,
    this.yourBloodType,
    this.partnerBloodType,
    this.yourEyeColor,
    this.partnerEyeColor,
    this.yourConditions,
    this.partnerConditions,
    this.yourDateIssued,
    this.partnerDateIssued,
    this.yourSignature,
    this.partnerSignature,
  });

  LicenseDetails copyWith({
    Object? yourGender = _unset,
    Object? partnerGender = _unset,
    Object? yourPhone = _unset,
    Object? partnerPhone = _unset,
    Object? yourBirthdate = _unset,
    Object? partnerBirthdate = _unset,
    Object? yourAddress = _unset,
    Object? partnerAddress = _unset,
    Object? yourNationality = _unset,
    Object? partnerNationality = _unset,
    Object? yourWeight = _unset,
    Object? partnerWeight = _unset,
    Object? yourHeight = _unset,
    Object? partnerHeight = _unset,
    Object? yourBloodType = _unset,
    Object? partnerBloodType = _unset,
    Object? yourEyeColor = _unset,
    Object? partnerEyeColor = _unset,
    Object? yourConditions = _unset,
    Object? partnerConditions = _unset,
    Object? yourDateIssued = _unset,
    Object? partnerDateIssued = _unset,
    Object? yourSignature = _unset,
    Object? partnerSignature = _unset,
  }) {
    return LicenseDetails(
      yourGender: identical(yourGender, _unset) ? this.yourGender : yourGender as String?,
      partnerGender: identical(partnerGender, _unset) ? this.partnerGender : partnerGender as String?,
      yourPhone: identical(yourPhone, _unset) ? this.yourPhone : yourPhone as String?,
      partnerPhone: identical(partnerPhone, _unset) ? this.partnerPhone : partnerPhone as String?,
      yourBirthdate: identical(yourBirthdate, _unset) ? this.yourBirthdate : yourBirthdate as DateTime?,
      partnerBirthdate:
          identical(partnerBirthdate, _unset) ? this.partnerBirthdate : partnerBirthdate as DateTime?,
      yourAddress: identical(yourAddress, _unset) ? this.yourAddress : yourAddress as String?,
      partnerAddress: identical(partnerAddress, _unset) ? this.partnerAddress : partnerAddress as String?,
      yourNationality:
          identical(yourNationality, _unset) ? this.yourNationality : yourNationality as String?,
      partnerNationality: identical(partnerNationality, _unset)
          ? this.partnerNationality
          : partnerNationality as String?,
      yourWeight: identical(yourWeight, _unset) ? this.yourWeight : yourWeight as String?,
      partnerWeight: identical(partnerWeight, _unset) ? this.partnerWeight : partnerWeight as String?,
      yourHeight: identical(yourHeight, _unset) ? this.yourHeight : yourHeight as String?,
      partnerHeight: identical(partnerHeight, _unset) ? this.partnerHeight : partnerHeight as String?,
      yourBloodType: identical(yourBloodType, _unset) ? this.yourBloodType : yourBloodType as String?,
      partnerBloodType:
          identical(partnerBloodType, _unset) ? this.partnerBloodType : partnerBloodType as String?,
      yourEyeColor: identical(yourEyeColor, _unset) ? this.yourEyeColor : yourEyeColor as String?,
      partnerEyeColor: identical(partnerEyeColor, _unset) ? this.partnerEyeColor : partnerEyeColor as String?,
      yourConditions: identical(yourConditions, _unset) ? this.yourConditions : yourConditions as String?,
      partnerConditions:
          identical(partnerConditions, _unset) ? this.partnerConditions : partnerConditions as String?,
      yourDateIssued: identical(yourDateIssued, _unset) ? this.yourDateIssued : yourDateIssued as DateTime?,
      partnerDateIssued:
          identical(partnerDateIssued, _unset) ? this.partnerDateIssued : partnerDateIssued as DateTime?,
      yourSignature: identical(yourSignature, _unset) ? this.yourSignature : yourSignature as String?,
      partnerSignature:
          identical(partnerSignature, _unset) ? this.partnerSignature : partnerSignature as String?,
    );
  }
}
