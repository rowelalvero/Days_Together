-- Migration: Pin an explicit search_path on every SECURITY DEFINER function
-- Created: 2026-09-11
--
-- A SECURITY DEFINER function executes with its owner's privileges. If it
-- resolves an unqualified name through the *caller's* search_path, any role
-- that can create objects in a schema sitting earlier on that path can
-- shadow a table, function, or operator the body relies on and have its own
-- version run as the owner. Supabase's database linter reports this as
-- `function_search_path_mutable`.
--
-- The newer functions already get this right -- see
-- 20260822000000_fix_create_relationship_workspace_search_path.sql and
-- 20260823000000_robust_pairing_code_rotation.sql -- but a number of older
-- ones were created without any SET search_path at all, among them:
--   * handle_user_deletion_cleanup(), delete_current_user()
--     (20260630000003_account_deletion_cleanup.sql)
--   * is_member_of_couple(), update_updated_at_column()
--     (20260706000000_persistent_relationship_workspace.sql)
--   * handle_new_user_notification_preferences()
--     (20260702000000_user_notification_preferences.sql)
--   * the ten log_*_activity() trigger functions
--     (20260702000001_relationship_activities.sql)
--   * join_couple_with_code() (20260630000000 / 20260630000002)
--
-- This reads pg_proc and pins the path only on functions that still lack
-- one, rather than re-declaring each by hand. Re-declaring would mean
-- reproducing bodies that several later migrations have since rewritten --
-- an easy way to silently revert a fix. `ALTER FUNCTION ... SET` touches
-- only the function's config setting: body, signature, owner, and grants are
-- left exactly as they are. That makes this idempotent, and a no-op for
-- every function that is already hardened.
--
-- The path mirrors what the already-correct functions use (`public, auth,
-- extensions` -- `extensions` is where pgcrypto's gen_salt()/crypt() live,
-- per 20260621000000_remote_schema.sql), with pg_temp pinned last so a
-- caller cannot shadow anything with a temporary table.

DO $$
DECLARE
  fn record;
BEGIN
  FOR fn IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef
      AND p.prokind = 'f'
      AND NOT EXISTS (
        SELECT 1
        FROM unnest(COALESCE(p.proconfig, ARRAY[]::text[])) AS cfg
        WHERE split_part(cfg, '=', 1) = 'search_path'
      )
  LOOP
    EXECUTE format(
      'ALTER FUNCTION %s SET search_path = public, auth, extensions, pg_temp',
      fn.signature
    );
    RAISE NOTICE 'Pinned search_path on SECURITY DEFINER function %', fn.signature;
  END LOOP;
END
$$;
