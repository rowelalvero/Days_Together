-- Migration: Drop unused legacy database objects (audit Phase 7 cleanup,
--            re-audit R-08)
-- Created: 2026-10-03
--
-- * public.failed_recovery_attempts -- the first recovery limiter
--   (20260706000000). Superseded by public.user_recovery_attempts and the
--   couples.failed_recovery_attempts / recovery_locked_until columns
--   (20260808000001 onward); no function, policy, view or client reads or
--   writes it (verified against pg_proc/pg_policies/pg_depend and by grep).
--   It still carried a FOR ALL "own row" policy, so a client could write to
--   it -- harmless while unused, but a trap for anyone who wires it back up.
--   It holds no data worth keeping (a dead rate-limit counter).
-- * public.get_user_couple_id(uuid) -- a SECURITY DEFINER helper from the
--   original schema. No policy, function or Dart call site uses it; since
--   20261003000100 only service_role could execute it.
--
-- NOT dropped: public.storage_cleanup_queue (used by
-- 20261003060000_storage_cleanup_queue) and
-- user_notification_preferences.vault_enabled (20260911010000 deliberately
-- kept it; harmless).
--
-- REGRESSION TEST
-- supabase/tests/001_rpc_privileges.sql (the dropped function is gone and
-- the privilege model still holds for everything that remains).

DROP TABLE IF EXISTS public.failed_recovery_attempts;
DROP FUNCTION IF EXISTS public.get_user_couple_id(uuid);
