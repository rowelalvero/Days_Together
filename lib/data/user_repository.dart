import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/models/user_profile.dart';

/// Typed access to the `users` table (ADR-003). Qualifies for a repository
/// under the two-part test: read by multiple consumers (`CoupleSession`,
/// `ProfileController`, presence, `relationship_license_screen.dart`) and
/// its rows become a [UserProfile] that outlives the query, rather than
/// being displayed once.
///
/// CURRENT STATE (Phase 4 of the architecture migration): this repository is
/// additive -- existing call sites in `relationship_provider.dart` (18 raw
/// `.from('users')` sites) and `profile_service.dart` (its
/// `updateUserDetails`) are deliberately left untouched here. Rewiring them
/// is Phase 5's job, done as each state slice (`LicenseController`,
/// `ProfileController`) is extracted and can be born calling this repository
/// directly, rather than adding a second, competing code path into the same
/// 2,000+ line file Phase 5 is about to decompose. See
/// docs/architecture/migration-roadmap.md's Phase 4 corrections.
class UserRepository {
  UserRepository._();

  static final UserRepository instance = UserRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Fetches a single user row by id, or null if it doesn't exist.
  Future<UserProfile?> fetchUser(String userId) async {
    final row = await _client.from('users').select().eq('id', userId).maybeSingle();
    return row != null ? UserProfile.fromMap(row) : null;
  }

  /// Updates profile columns in the `users` table for the given user id.
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _client.from('users').update(data).eq('id', userId);
  }

  /// Updates a partner's profile fields via the `update_partner_profile` RPC
  /// -- RLS prevents a direct `users` update for a row that isn't the
  /// caller's own, so this SECURITY DEFINER function is the write path, but
  /// it is still conceptually a `users`-table write and belongs on this
  /// repository rather than a separate service.
  Future<void> updatePartnerProfile(String targetUserId, Map<String, dynamic> updates) async {
    await _client.rpc('update_partner_profile', params: {
      'p_target_user_id': targetUserId,
      'p_updates': updates,
    });
  }
}
