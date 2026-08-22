import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/models/relationship_metadata.dart';

/// Typed access to the `license_details` table (ADR-003). Qualifies for a
/// repository under the two-part test: read by `ProfileService.fetchLicenseDetails`
/// today and subscribed to via realtime, and its rows become a
/// [RelationshipMetadata] that outlives the query.
///
/// **Live-schema verification, resolved by reading the full migration
/// history rather than the live database directly.** ADR-003 and
/// `migration-roadmap.md`'s Phase 0 section flagged `license_details` as a
/// confirmed case of "undocumented schema drift" and made connecting to the
/// live Supabase project to run `\d license_details` a mandatory
/// prerequisite for this repository. That finding was based on reading only
/// `supabase/migrations/20260621000000_remote_schema.sql` (the original
/// `CREATE TABLE`, which has 30 paired `your_*`/`partner_*` columns and no
/// `certificate_number`/`issue_date`/`anniversary`/`theme`/`relationship_title`).
/// A later migration was missed: `20260712000002_fix_rls_recursion.sql:54-89`
/// both **adds** exactly the five columns [RelationshipMetadata] already
/// expects and **drops all 30** legacy paired columns from `license_details`
/// in the same statement. Reading the complete, ordered migration history
/// (confirmed: no later migration touches this table's shape, only
/// `20260711100000_database_indexing_optimizations.sql:40` adds an index on
/// `creator_id`) resolves the question definitively without needing a live
/// connection: current `license_details` columns are `couple_id`,
/// `creator_id`, `certificate_number`, `issue_date`, `anniversary`, `theme`,
/// `relationship_title` -- exactly [RelationshipMetadata]'s shape.
/// `creator_id` is deliberately not modeled here: no Dart call site reads it
/// (guarded by `couple_session_test.dart`'s "Codebase contains no reference
/// to nonexistent license_details.creator_id" test), so it stays a
/// server-only column.
///
/// The 28 `_your*`/`_partner*` license fields the UI calls "License" are a
/// separate concern entirely -- they live-write through the **`users`**
/// table today (see `UserRepository`), not this one; `LicenseController`
/// (Phase 5) depends on `UserRepository`, not this repository, despite the
/// naming similarity (see `state-management.md`).
///
/// CURRENT STATE (Phase 4): additive, like `UserRepository` -- see its doc
/// comment for why `profile_service.dart`'s existing raw `.from('license_details')`
/// sites aren't rewired in this phase.
class LicenseRepository {
  LicenseRepository._();

  static final LicenseRepository instance = LicenseRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Fetches the certificate/metadata row for a couple, or null if it
  /// doesn't exist yet.
  Future<RelationshipMetadata?> fetchLicense(String coupleId) async {
    final row =
        await _client.from('license_details').select().eq('couple_id', coupleId).maybeSingle();
    return row != null ? RelationshipMetadata.fromMap(row) : null;
  }

  /// Updates existing fields in the `license_details` table.
  Future<void> updateLicense(String coupleId, Map<String, dynamic> data) async {
    await _client.from('license_details').update(data).eq('couple_id', coupleId);
  }

  /// Upserts a `license_details` row (insert-or-update).
  Future<void> upsertLicense(Map<String, dynamic> data) async {
    await _client.from('license_details').upsert(data);
  }
}
