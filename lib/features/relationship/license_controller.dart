import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/constants/prefs_keys.dart';
import 'package:days_together/data/user_repository.dart';
import 'package:days_together/features/relationship/license_details.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/services/recent_activity_service.dart';

/// Sentinel distinguishing "field not provided" from "explicitly cleared".
/// Mirrors [LicenseDetails.copyWith]'s sentinel and the pattern
/// `relationship_provider.dart`'s old `updateLicense` used.
const Object _unset = Object();

/// Owns the 24 paired license fields (Phase 5 of the architecture
/// migration, extracted from `relationship_provider.dart`).
///
/// **Only one write path exists in the live codebase.** A repo-wide search
/// (see docs/architecture/migration-roadmap.md's Phase 5 corrections) found
/// `relationship_provider.dart`'s 10 individual setters (`setGenders`,
/// `setPhoneNumbers`, etc.) have zero callers anywhere in `lib/` or `test/`
/// -- only the bulk `updateLicense` method is actually invoked, from exactly
/// two call sites in `relationship_license_screen.dart`, both of which only
/// ever populate "your" fields (never "partner" fields, despite the method
/// accepting both). This controller exposes one bulk [updateFields] method
/// matching `updateLicense`'s shape (minus `yourName`/`partnerName`/
/// `yourAvatarPath`/`partnerAvatarPath`, which are `ProfileController`'s
/// fields, not this one's) rather than porting the 10 dead setters forward.
class LicenseController extends AsyncNotifier<LicenseDetails> {
  @override
  Future<LicenseDetails> build() async {
    final prefs = await SharedPreferences.getInstance();
    DateTime? parseDate(String key) {
      final raw = prefs.getString(key);
      return raw != null ? DateTime.parse(raw) : null;
    }

    return LicenseDetails(
      yourGender: prefs.getString(PrefsKeys.yourGender),
      partnerGender: prefs.getString(PrefsKeys.partnerGender),
      yourPhone: prefs.getString(PrefsKeys.yourPhone),
      partnerPhone: prefs.getString(PrefsKeys.partnerPhone),
      yourBirthdate: parseDate(PrefsKeys.yourBirthdate),
      partnerBirthdate: parseDate(PrefsKeys.partnerBirthdate),
      yourAddress: prefs.getString(PrefsKeys.yourAddress),
      partnerAddress: prefs.getString(PrefsKeys.partnerAddress),
      yourNationality: prefs.getString(PrefsKeys.yourNationality),
      partnerNationality: prefs.getString(PrefsKeys.partnerNationality),
      yourWeight: prefs.getString(PrefsKeys.yourWeight),
      partnerWeight: prefs.getString(PrefsKeys.partnerWeight),
      yourHeight: prefs.getString(PrefsKeys.yourHeight),
      partnerHeight: prefs.getString(PrefsKeys.partnerHeight),
      yourBloodType: prefs.getString(PrefsKeys.yourBloodType),
      partnerBloodType: prefs.getString(PrefsKeys.partnerBloodType),
      yourEyeColor: prefs.getString(PrefsKeys.yourEyeColor),
      partnerEyeColor: prefs.getString(PrefsKeys.partnerEyeColor),
      yourConditions: prefs.getString(PrefsKeys.yourConditions),
      partnerConditions: prefs.getString(PrefsKeys.partnerConditions),
      yourDateIssued: parseDate(PrefsKeys.yourDateIssued),
      partnerDateIssued: parseDate(PrefsKeys.partnerDateIssued),
      yourSignature: prefs.getString(PrefsKeys.yourSignature),
      partnerSignature: prefs.getString(PrefsKeys.partnerSignature),
    );
  }

  /// Bulk update -- the direct replacement for `RelationshipProvider`'s old
  /// `updateLicense`. Any parameter left as the sentinel is untouched;
  /// passing `null` explicitly clears that field. Persists to
  /// SharedPreferences immediately, then best-effort pushes to Supabase via
  /// [UserRepository] (the live write path is the `users` table, not
  /// `license_details` -- see `lib/data/license_repository.dart`'s doc
  /// comment).
  Future<void> updateFields({
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
  }) async {
    final current = state.value ?? const LicenseDetails();
    final next = current.copyWith(
      yourGender: yourGender,
      partnerGender: partnerGender,
      yourPhone: yourPhone,
      partnerPhone: partnerPhone,
      yourBirthdate: yourBirthdate,
      partnerBirthdate: partnerBirthdate,
      yourAddress: yourAddress,
      partnerAddress: partnerAddress,
      yourNationality: yourNationality,
      partnerNationality: partnerNationality,
      yourWeight: yourWeight,
      partnerWeight: partnerWeight,
      yourHeight: yourHeight,
      partnerHeight: partnerHeight,
      yourBloodType: yourBloodType,
      partnerBloodType: partnerBloodType,
      yourEyeColor: yourEyeColor,
      partnerEyeColor: partnerEyeColor,
      yourConditions: yourConditions,
      partnerConditions: partnerConditions,
      yourDateIssued: yourDateIssued,
      partnerDateIssued: partnerDateIssued,
      yourSignature: yourSignature,
      partnerSignature: partnerSignature,
    );
    state = AsyncData(next);

    final prefs = await SharedPreferences.getInstance();
    Future<void> saveString(String key, String? value) =>
        value != null ? prefs.setString(key, value) : prefs.remove(key);
    Future<void> saveDate(String key, DateTime? value) =>
        value != null ? prefs.setString(key, value.toIso8601String()) : prefs.remove(key);

    await saveString(PrefsKeys.yourGender, next.yourGender);
    await saveString(PrefsKeys.partnerGender, next.partnerGender);
    await saveString(PrefsKeys.yourPhone, next.yourPhone);
    await saveString(PrefsKeys.partnerPhone, next.partnerPhone);
    await saveDate(PrefsKeys.yourBirthdate, next.yourBirthdate);
    await saveDate(PrefsKeys.partnerBirthdate, next.partnerBirthdate);
    await saveString(PrefsKeys.yourAddress, next.yourAddress);
    await saveString(PrefsKeys.partnerAddress, next.partnerAddress);
    await saveString(PrefsKeys.yourNationality, next.yourNationality);
    await saveString(PrefsKeys.partnerNationality, next.partnerNationality);
    await saveString(PrefsKeys.yourWeight, next.yourWeight);
    await saveString(PrefsKeys.partnerWeight, next.partnerWeight);
    await saveString(PrefsKeys.yourHeight, next.yourHeight);
    await saveString(PrefsKeys.partnerHeight, next.partnerHeight);
    await saveString(PrefsKeys.yourBloodType, next.yourBloodType);
    await saveString(PrefsKeys.partnerBloodType, next.partnerBloodType);
    await saveString(PrefsKeys.yourEyeColor, next.yourEyeColor);
    await saveString(PrefsKeys.partnerEyeColor, next.partnerEyeColor);
    await saveString(PrefsKeys.yourConditions, next.yourConditions);
    await saveString(PrefsKeys.partnerConditions, next.partnerConditions);
    await saveDate(PrefsKeys.yourDateIssued, next.yourDateIssued);
    await saveDate(PrefsKeys.partnerDateIssued, next.partnerDateIssued);
    await saveString(PrefsKeys.yourSignature, next.yourSignature);
    await saveString(PrefsKeys.partnerSignature, next.partnerSignature);

    final session = ref.read(coupleSessionProvider);
    if (session.isSupabaseAvailable) {
      if (session.userId != null) {
        final selfData = <String, dynamic>{};
        if (!identical(yourGender, _unset)) selfData['gender'] = next.yourGender;
        if (!identical(yourPhone, _unset)) selfData['phone'] = next.yourPhone;
        if (!identical(yourBirthdate, _unset)) selfData['birthdate'] = next.yourBirthdate?.toIso8601String();
        if (!identical(yourAddress, _unset)) selfData['address'] = next.yourAddress;
        if (!identical(yourNationality, _unset)) selfData['nationality'] = next.yourNationality;
        if (!identical(yourWeight, _unset)) selfData['weight'] = next.yourWeight;
        if (!identical(yourHeight, _unset)) selfData['height'] = next.yourHeight;
        if (!identical(yourBloodType, _unset)) selfData['blood_type'] = next.yourBloodType;
        if (!identical(yourEyeColor, _unset)) selfData['eye_color'] = next.yourEyeColor;
        if (!identical(yourConditions, _unset)) selfData['conditions'] = next.yourConditions;
        if (!identical(yourDateIssued, _unset)) selfData['date_issued'] = next.yourDateIssued?.toIso8601String();
        if (!identical(yourSignature, _unset)) selfData['signature'] = next.yourSignature;
        if (selfData.isNotEmpty) {
          try {
            await UserRepository.instance.updateUser(session.userId!, selfData);
          } catch (_) {}
        }
      }

      if (session.partnerId != null) {
        final partnerData = <String, dynamic>{};
        if (!identical(partnerGender, _unset)) partnerData['gender'] = next.partnerGender;
        if (!identical(partnerPhone, _unset)) partnerData['phone'] = next.partnerPhone;
        if (!identical(partnerBirthdate, _unset)) {
          partnerData['birthdate'] = next.partnerBirthdate?.toIso8601String();
        }
        if (!identical(partnerAddress, _unset)) partnerData['address'] = next.partnerAddress;
        if (!identical(partnerNationality, _unset)) partnerData['nationality'] = next.partnerNationality;
        if (!identical(partnerWeight, _unset)) partnerData['weight'] = next.partnerWeight;
        if (!identical(partnerHeight, _unset)) partnerData['height'] = next.partnerHeight;
        if (!identical(partnerBloodType, _unset)) partnerData['blood_type'] = next.partnerBloodType;
        if (!identical(partnerEyeColor, _unset)) partnerData['eye_color'] = next.partnerEyeColor;
        if (!identical(partnerConditions, _unset)) partnerData['conditions'] = next.partnerConditions;
        if (!identical(partnerDateIssued, _unset)) {
          partnerData['date_issued'] = next.partnerDateIssued?.toIso8601String();
        }
        if (!identical(partnerSignature, _unset)) partnerData['signature'] = next.partnerSignature;
        if (partnerData.isNotEmpty) {
          try {
            await UserRepository.instance.updatePartnerProfile(session.partnerId!, partnerData);
          } catch (_) {}
        }
      }
    }

    await RecentActivityService.instance.logActivity(
      activityType: 'updated',
      title: 'Profile updated 💕',
      description: 'Relationship profile details updated',
      icon: '💕',
      referenceId: 'relationship_profile_details',
      route: 'relationship_profile',
    );
  }

}

/// A default (non-`autoDispose`) `AsyncNotifierProvider` stays alive for the
/// whole app session -- unlike `RelationshipProvider`, whose fields were
/// re-initialized to null as a direct part of its own `logout()`/
/// `unlinkPartner()` methods, `LicenseController`'s cached state has no such
/// hook by default, and would otherwise leak a signed-out user's license
/// data into a second account signed into the same app session. `main.dart`'s
/// `_LicenseLifecycleBridge` watches `RelationshipProvider`'s identity
/// fields and calls `ref.invalidate(licenseControllerProvider)` on
/// logout/disconnect, discarding the cached state so the next read re-runs
/// [LicenseController.build] against SharedPreferences -- already cleared by
/// that point, since `RelationshipProvider.logout()` awaits `prefs.clear()`
/// before its final `notifyListeners()`. Deliberately invalidate-and-rebuild
/// rather than a hand-written `reset()` method, so there is exactly one
/// code path (`build()`) responsible for what "empty" state looks like.
final licenseControllerProvider = AsyncNotifierProvider<LicenseController, LicenseDetails>(
  LicenseController.new,
  dependencies: [coupleSessionProvider],
);
