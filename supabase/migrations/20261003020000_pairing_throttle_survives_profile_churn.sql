-- Migration: Pairing throttle cannot be reset via one's own profile row
--            (re-audit R-01 / invariant S03)
-- Created: 2026-10-03
--
-- PROBLEM (reproduced by supabase/tests/003_pairing.sql, R-01 block)
-- Both pairing counters -- failed_pairing_attempts (per-user lockout) and
-- pairing_attempt_failures (global circuit breaker) -- referenced
-- public.users(id) ON DELETE CASCADE, and the baseline policy
-- "Enable delete for own profile" (20260621000000, re-created in
-- 20260712000001) let any user delete their own public.users row. So:
--   5 wrong codes -> RATE_LIMITED
--   DELETE FROM users WHERE id = auth.uid()   -- cascades both counters away
--   INSERT INTO users (id) VALUES (auth.uid()) -- the "own profile" policy
--   -> the next guess is evaluated again.
-- One account could guess without limit (~5 guesses per 3 requests).
-- Deleting one's own row also impersonated account deletion: the deletion
-- trigger told the partner "your partner deleted their account", vacated the
-- slot and voided the recovery code, while the login account lived on.
--
-- NEW INVARIANT
-- Clients cannot delete public.users rows; account removal goes only through
-- delete_current_user(). The attempt counters are attached to the auth
-- identity (auth.users), so even trusted removal of a profile row can no
-- longer reset them.
--
-- WHY THIS IS SAFE
-- * No client code deletes users rows (verified by grep); account deletion
--   is the delete_current_user() RPC (SECURITY DEFINER, unaffected), and the
--   cascade from auth.users -> public.users runs with the FK's own rights.
-- * The INSERT ("self-heal") and UPDATE policies are unchanged.
-- * users.id already references auth.users(id), so every existing counter
--   row satisfies the new foreign keys; ON DELETE CASCADE from auth.users
--   still removes them when an account is really deleted.
--
-- REGRESSION TEST
-- supabase/tests/003_pairing.sql (R-01 block).

DROP POLICY IF EXISTS "Enable delete for own profile" ON public.users;
REVOKE DELETE, TRUNCATE ON TABLE public.users FROM anon, authenticated;

ALTER TABLE public.failed_pairing_attempts
  DROP CONSTRAINT failed_pairing_attempts_user_id_fkey,
  ADD CONSTRAINT failed_pairing_attempts_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.pairing_attempt_failures
  DROP CONSTRAINT pairing_attempt_failures_user_id_fkey,
  ADD CONSTRAINT pairing_attempt_failures_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
