import 'package:supabase_flutter/supabase_flutter.dart';

/// A service to encapsulate all relationship pairing, unlinking, and recovery transactions.
class CoupleService {
  CoupleService._();

  /// The singleton instance of the CoupleService.
  static final CoupleService instance = CoupleService._();

  /// Creates a new relationship workspace.
  /// Returns a map containing 'couple_id', 'pairing_code', and 'recovery_code'.
  Future<Map<String, dynamic>> createRelationshipWorkspace() async {
    final response = await Supabase.instance.client.rpc(
      'create_relationship_workspace',
    );
    return Map<String, dynamic>.from(response);
  }

  /// Fetches the active pairing code or rotates it if older than 20 minutes.
  Future<Map<String, dynamic>> getOrRotatePairingCode({bool forceRotate = false}) async {
    final response = await Supabase.instance.client.rpc(
      'get_or_rotate_pairing_code',
      params: {'p_force_rotate': forceRotate},
    );
    return Map<String, dynamic>.from(response);
  }

  /// Attempts to join a workspace using a 6-digit invitation code via Database RPC.
  Future<Map<String, dynamic>> joinWithCode(String code) async {
    final response = await Supabase.instance.client.rpc(
      'join_relationship_with_code',
      params: {'p_pairing_code': code},
    );
    return Map<String, dynamic>.from(response);
  }

  /// Reconnects a user to a workspace using a recovery code.
  Future<Map<String, dynamic>> recoverWithCode(String code) async {
    final response = await Supabase.instance.client.rpc(
      'recover_relationship_with_code',
      params: {'p_recovery_code': code},
    );
    return Map<String, dynamic>.from(response);
  }

  /// Regenerates a new recovery code for the workspace.
  Future<Map<String, dynamic>> regenerateRecoveryCode() async {
    final response = await Supabase.instance.client.rpc(
      'regenerate_recovery_code',
    );
    return Map<String, dynamic>.from(response);
  }

  /// Unlinks the current user, clearing workspace links in the database.
  Future<void> disconnectRelationshipWorkspace() async {
    await Supabase.instance.client.rpc(
      'disconnect_relationship_workspace',
    );
  }
}
