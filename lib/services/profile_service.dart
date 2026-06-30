import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Updates relationship details in the `couples` table.
  Future<void> updateCoupleDetails(String coupleId, Map<String, dynamic> data) async {
    await Supabase.instance.client
        .from('couples')
        .update(data)
        .eq('id', coupleId);
  }

  /// Updates fields in the `relationship_licenses` table.
  Future<void> updateLicenseDetails(String coupleId, Map<String, dynamic> data) async {
    await Supabase.instance.client
        .from('relationship_licenses')
        .update(data)
        .eq('couple_id', coupleId);
  }

  /// Fetches relationship license details for a specific couple.
  Future<Map<String, dynamic>?> fetchLicenseDetails(String coupleId) async {
    final list = await Supabase.instance.client
        .from('relationship_licenses')
        .select()
        .eq('couple_id', coupleId);
    return list.isNotEmpty ? list.first : null;
  }

  /// Uploads an avatar image to the specified storage bucket and returns its public URL.
  Future<String> uploadAvatar({
    required String bucketName,
    required String filePath,
    required String storagePath,
  }) async {
    final file = File(filePath);
    await Supabase.instance.client.storage
        .from(bucketName)
        .upload(
          storagePath,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    return Supabase.instance.client.storage
        .from(bucketName)
        .getPublicUrl(storagePath);
  }
}
