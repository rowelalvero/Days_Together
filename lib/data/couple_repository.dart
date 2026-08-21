import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/models/relationship_workspace.dart';

/// Typed access to the `couples` table (ADR-003). Qualifies for a repository
/// under the two-part test: read by multiple consumers (`CoupleSession`,
/// the future `WorkspaceController`, pairing/recovery flows) and its rows
/// become a [RelationshipWorkspace] that outlives the query.
///
/// Pairing/recovery *transactions* (creating a workspace, joining with a
/// code, recovering, disconnecting) stay in `CoupleService` -- they are
/// multi-step RPCs with ad-hoc response shapes (`{couple_id, pairing_code,
/// recovery_code}`), not `couples`-row CRUD, so they don't satisfy this
/// repository's two-part test the way a typed fetch/update does.
///
/// CURRENT STATE (Phase 4): additive, like `UserRepository` -- see its doc
/// comment for why `relationship_provider.dart`'s existing raw `.from('couples')`
/// sites aren't rewired in this phase.
class CoupleRepository {
  CoupleRepository._();

  static final CoupleRepository instance = CoupleRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Fetches a single couple row by id, or null if it doesn't exist.
  Future<RelationshipWorkspace?> fetchCouple(String coupleId) async {
    final row = await _client.from('couples').select().eq('id', coupleId).maybeSingle();
    return row != null ? RelationshipWorkspace.fromMap(row) : null;
  }

  /// Updates relationship details in the `couples` table.
  Future<void> updateCouple(String coupleId, Map<String, dynamic> data) async {
    await _client.from('couples').update(data).eq('id', coupleId);
  }
}
