import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../models/relationship_workspace.dart';
import '../models/relationship_metadata.dart';

class RelationshipRepository {
  static final RelationshipRepository instance = RelationshipRepository._internal();
  RelationshipRepository._internal();

  final _client = Supabase.instance.client;

  Future<UserProfile?> fetchUserProfile(String userId) async {
    final res = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (res == null) return null;
    return UserProfile.fromMap(res);
  }

  Future<RelationshipWorkspace?> fetchWorkspace(String coupleId) async {
    final res = await _client
        .from('couples')
        .select()
        .eq('id', coupleId)
        .maybeSingle();
    if (res == null) return null;
    return RelationshipWorkspace.fromMap(res);
  }

  Future<RelationshipMetadata?> fetchMetadata(String coupleId) async {
    final res = await _client
        .from('license_details')
        .select()
        .eq('couple_id', coupleId)
        .maybeSingle();
    if (res == null) return null;
    return RelationshipMetadata.fromMap(res);
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    await _client.from('users').update(data).eq('id', userId);
  }

  Future<void> updatePartnerProfile(String targetUserId, Map<String, dynamic> data) async {
    await _client.rpc('update_partner_profile', params: {
      'p_target_user_id': targetUserId,
      'p_updates': data,
    });
  }

  Future<void> updateWorkspace(String coupleId, Map<String, dynamic> data) async {
    await _client.from('couples').update(data).eq('id', coupleId);
  }

  Future<void> updateMetadata(String coupleId, Map<String, dynamic> data) async {
    await _client.from('license_details').upsert({
      'couple_id': coupleId,
      ...data,
    });
  }

  Future<Map<String, dynamic>> createWorkspace() async {
    final res = await _client.rpc('create_relationship_workspace');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> joinWorkspace(String code) async {
    final res = await _client.rpc('join_relationship_with_code', params: {'p_pairing_code': code});
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> recoverWorkspace(String code) async {
    final res = await _client.rpc('recover_relationship_with_code', params: {'p_recovery_code': code});
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> disconnectWorkspace() async {
    final res = await _client.rpc('disconnect_relationship_workspace');
    return Map<String, dynamic>.from(res as Map);
  }
}
