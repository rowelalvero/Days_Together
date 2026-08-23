import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/services/auth_service.dart';
import 'package:days_together/services/key_management_service.dart';
import 'package:days_together/services/photo_encryption_service.dart';

/// The single choke point every couple-scoped photo upload goes through:
/// encrypts [plaintext] with the couple's shared AES-256 photo key and
/// uploads the ciphertext -- so Supabase Storage (and therefore whoever
/// holds the project's `service_role` key) only ever sees encrypted bytes
/// for anything uploaded through this class.
///
/// [KeyManagementService]/[PhotoEncryptionService] stay pure/Supabase-free
/// (see their own docs); this class is the one place that wires them to an
/// actual bucket upload, shared by every upload call site (avatar, vault,
/// timeline, note-it) so the encrypt-then-upload sequence exists exactly
/// once rather than being re-implemented at each site.
class EncryptedStorageService {
  EncryptedStorageService._();

  static final EncryptedStorageService instance = EncryptedStorageService._();

  /// Encrypts [plaintext] and uploads it to `[bucket]/[storagePath]`.
  ///
  /// Throws if the couple photo key hasn't arrived yet (key exchange with
  /// the partner is still in flight, e.g. right after pairing) -- callers
  /// should surface that as a clear "still syncing encryption keys" error
  /// rather than falling back to an unencrypted upload, which would defeat
  /// the whole point of this feature.
  Future<void> encryptAndUpload({
    required String bucket,
    required String storagePath,
    required Uint8List plaintext,
  }) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      throw Exception('Not signed in -- cannot encrypt/upload.');
    }
    final coupleKey = await KeyManagementService.instance.loadCoupleKey(userId);
    if (coupleKey == null) {
      throw Exception(
        'Still syncing encryption keys with your partner -- please try again in a moment.',
      );
    }

    final ciphertext = await PhotoEncryptionService.instance.encryptBytes(plaintext, coupleKey);

    await Supabase.instance.client.storage.from(bucket).uploadBinary(
      storagePath,
      ciphertext,
      fileOptions: const FileOptions(upsert: true, contentType: 'application/octet-stream'),
    );
  }
}
