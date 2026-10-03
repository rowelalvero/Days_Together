-- Migration: Explicit EXECUTE privilege model for SECURITY DEFINER functions
--            (audit F-04 / invariant S01)
-- Created: 2026-10-03
--
-- PROBLEM
-- Every SECURITY DEFINER function in public was executable by PUBLIC (the
-- Postgres default for new functions) and explicitly by anon
-- (20260621000000_remote_schema.sql: ALTER DEFAULT PRIVILEGES ... GRANT ALL
-- ON FUNCTIONS TO anon). Two of them -- create_relationship_workspace and
-- join_relationship_with_code -- had also lost their auth.uid() guard in the
-- 20260808000003 rewrite, so the public anon key alone could create orphan
-- workspaces or burn a waiting couple's pairing code (an anon join set the
-- couple 'active' with partner_b_id NULL, permanently blocking the real
-- partner -- reproduced by 001_rpc_privileges.sql before this migration).
--
-- PREVIOUS BEHAVIOUR
-- PUBLIC, anon, authenticated and service_role could all EXECUTE all 18
-- SECURITY DEFINER functions, trigger functions included.
--
-- NEW INVARIANT
--   PUBLIC        -> no EXECUTE on any SECURITY DEFINER function in public
--   anon          -> no EXECUTE on any SECURITY DEFINER function in public
--   authenticated -> EXECUTE only on the RPC allowlist below
--   service_role  -> EXECUTE on all of them (admin / edge functions)
-- Function bodies additionally reject auth.uid() IS NULL (defense in depth --
-- the guards for create/join are restored in 20261003000200).
--
-- WHY THIS IS SAFE
-- * Trigger functions need no EXECUTE grant to fire: Postgres checks EXECUTE
--   on a trigger function only when the trigger is CREATED (by the owner),
--   never when it fires. Revoking from PUBLIC therefore cannot break
--   handle_new_user, protect_users_couple_id, the deletion cleanup, etc.
-- * is_member_of_couple(uuid) stays granted to authenticated: RLS policies
--   execute with the querying role's privileges, and every couple-scoped
--   policy calls it. It is a side-effect-free predicate. anon loses it,
--   which turns an anon read of a couple-scoped table from "0 rows" into a
--   permission error -- no client code reads those tables while signed out.
-- * get_user_couple_id(uuid) is granted to nobody but service_role: no
--   policy, function or Dart call site uses it.
-- * The allowlist is exactly the set of RPCs the Flutter client calls
--   (lib/core/network/*.dart, couple_key_exchange.dart,
--   notification_service.dart) -- verified by grep.
-- * The schema-level default privilege that handed anon EXECUTE on every
--   future function is removed. The *global* PUBLIC default is deliberately
--   left alone (it would also strip PUBLIC EXECUTE from functions of
--   extensions created by postgres); instead 001_rpc_privileges.sql
--   enumerates pg_proc dynamically and fails on any SECURITY DEFINER
--   function a future migration adds without explicit grants.
--
-- REGRESSION TEST
-- supabase/tests/001_rpc_privileges.sql (set-based privilege checks, anon
-- refused with 42501 for every RPC, identity-less authenticated refused in
-- every body, unrelated user refused, authorized user succeeds).

DO $$
DECLARE
  fn regprocedure;
BEGIN
  FOR fn IN
    SELECT p.oid::regprocedure
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef
      AND p.prokind = 'f'
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', fn);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', fn);
  END LOOP;
END
$$;

GRANT EXECUTE ON FUNCTION public.create_relationship_workspace(text)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_relationship_with_code(text, text)    TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_rotate_pairing_code(boolean)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.recover_relationship_with_code(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.regenerate_recovery_code()                 TO authenticated;
GRANT EXECUTE ON FUNCTION public.disconnect_relationship_workspace()        TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_partner_profile(uuid, jsonb)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.store_wrapped_key(uuid, text)              TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_user_fcm_token(text, text)          TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_current_user()                      TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_member_of_couple(uuid)                  TO authenticated;

-- Stop handing anon EXECUTE on every function created in public from now on.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon;
