-- Migration: Restore owner-only UPDATE on user_fcm_tokens (audit F-12 /
--            invariant S10)
-- Created: 2026-10-03
--
-- PROBLEM
-- 20260808000004 replaced the owner-only UPDATE policy with
--   USING (auth.role() = 'authenticated') WITH CHECK (auth.uid() = user_id)
-- A filtered UPDATE was still stopped by the owner-only SELECT policy (Postgres
-- applies SELECT policies when the UPDATE reads columns in WHERE), but an
-- UNFILTERED `UPDATE user_fcm_tokens SET user_id = auth.uid()` needs no
-- SELECT rights: every row passed USING, the new value passed WITH CHECK,
-- and the caller took over every device token in the system -- receiving
-- every other user's partner notifications (reproduced by
-- 008_fcm_tokens.sql before this migration).
--
-- PREVIOUS BEHAVIOUR
-- Any authenticated user could reassign any token row to themselves.
--
-- NEW INVARIANT
-- A user can only ever UPDATE token rows they already own, and only to keep
-- owning them.
--
-- WHY THIS IS SAFE
-- The policy was loosened to let a device's token move to a newly signed-in
-- account. That handoff has gone through the SECURITY DEFINER RPC
-- upsert_user_fcm_token (same migration, 20260808000004) ever since, which is
-- unaffected by RLS; the client only falls back to direct writes when the RPC
-- is missing, and that fallback deletes then upserts its *own* rows.
--
-- REGRESSION TEST
-- supabase/tests/008_fcm_tokens.sql

DROP POLICY IF EXISTS "Users can update FCM tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Users can update their own FCM tokens" ON public.user_fcm_tokens;

CREATE POLICY "Users can update their own FCM tokens" ON public.user_fcm_tokens
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
