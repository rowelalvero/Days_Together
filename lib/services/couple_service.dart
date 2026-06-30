import 'package:supabase_flutter/supabase_flutter.dart';

/// A service to encapsulate all relationship pairing and unlinking transactions.
class CoupleService {
  CoupleService._();

  /// The singleton instance of the CoupleService.
  static final CoupleService instance = CoupleService._();

  /// Attempts to join a couple using a 6-digit invitation code via Database RPC.
  Future<Map<String, dynamic>> joinWithCode(String code) async {
    final response = await Supabase.instance.client.rpc(
      'join_couple_with_code',
      params: {'code': code},
    );
    return Map<String, dynamic>.from(response);
  }

  /// Unlinks the current user, clearing couple and partner links in the database.
  Future<void> unlinkPartner({required String userId}) async {
    await Supabase.instance.client
        .from('users')
        .update({'couple_id': null, 'partner_id': null})
        .eq('id', userId);
  }
}
