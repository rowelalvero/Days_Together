import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/services/encrypted_storage_service.dart';

/// A service to encapsulate user profile, registry metadata, and avatar storage actions.
class ProfileService {
  ProfileService._();

  /// The singleton instance of the ProfileService.
  static final ProfileService instance = ProfileService._();

  /// Updates profile columns in the `users` table for a specific user ID.
  Future<void> updateUserDetails(String userId, Map<String, dynamic> data) async {
    await Supabase.instance.client
        .from('users')
        .update(data)
        .eq('id', userId);
  }

  /// Updates partner profile fields via the update_partner_profile RPC (Audit C-2).
  Future<void> updatePartnerProfile(String targetUserId, Map<String, dynamic> updates) async {
    await Supabase.instance.client.rpc('update_partner_profile', params: {
      'p_target_user_id': targetUserId,
      'p_updates': updates,
    });
  }

  /// Updates relationship details in the `couples` table.
  Future<void> updateCoupleDetails(String coupleId, Map<String, dynamic> data) async {
    await Supabase.instance.client
        .from('couples')
        .update(data)
        .eq('id', coupleId);
  }

  /// Updates fields in the `license_details` table.
  Future<void> updateLicenseDetails(String coupleId, Map<String, dynamic> data) async {
    await Supabase.instance.client
        .from('license_details')
        .update(data)
        .eq('couple_id', coupleId);
  }

  /// Upserts registry/license metadata in the `license_details` table.
  Future<void> upsertLicenseDetails(Map<String, dynamic> data) async {
    await Supabase.instance.client
        .from('license_details')
        .upsert(data);
  }

  /// Fetches relationship license details for a specific couple.
  Future<Map<String, dynamic>?> fetchLicenseDetails(String coupleId) async {
    final list = await Supabase.instance.client
        .from('license_details')
        .select()
        .eq('couple_id', coupleId);
    return list.isNotEmpty ? list.first : null;
  }

  /// Uploads an avatar image to [bucketName] and returns its **storage path**
  /// (not a URL).
  ///
  /// The buckets are private, so a durable public URL does not exist. Callers
  /// persist this path and render it through `StorageImage`, which mints a
  /// short-lived signed URL on demand.
  ///
  /// The upload is end-to-end encrypted via [EncryptedStorageService]: what
  /// lands in the bucket is AES-256-GCM ciphertext under the couple's shared
  /// photo key, not the plaintext image.
  Future<String> uploadAvatar({
    required String bucketName,
    required String filePath,
    required String storagePath,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Avatar image file does not exist at $filePath');
    }

    await EncryptedStorageService.instance.encryptAndUpload(
      bucket: bucketName,
      storagePath: storagePath,
      plaintext: await file.readAsBytes(),
    );

    return storagePath;
  }
}
