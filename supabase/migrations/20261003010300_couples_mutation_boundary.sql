-- Migration: Column-level write boundary on couples (audit F-11 /
--            invariants S08, S09)
-- Created: 2026-10-03
--
-- PROBLEM
-- Two live UPDATE policies ("Enable update for members", 20260707000001, and
-- "Enable update for couple members", 20260712000001) let either partner
-- update ANY column of their couple row, and the baseline DELETE policy
-- ("Enable delete for couple members", 20260621000000) was never dropped. A
-- member -- or a bug, or a compromised device -- could, through plain
-- PostgREST calls:
--   * set the other partner's slot to NULL (evicting them without the RPC),
--   * set status = 'archived' (is_member_of_couple then locks BOTH out),
--   * replace recovery_code_hash / recovery_lookup_key / pairing_code,
--   * reset the recovery lockout counters,
--   * DELETE the couple, cascading away the entire shared history and
--     orphaning its storage objects, in one request.
--
-- NEW INVARIANT
-- Clients may change exactly the fields the app edits -- story_title,
-- start_date, start_time_hour, start_time_minute (CoupleSession; verified by
-- grep: no other client write to couples remains) -- and nothing else.
-- Membership, status, codes and lockouts change only inside SECURITY DEFINER
-- functions (owned by postgres, unaffected by these grants). Clients can
-- never INSERT or DELETE couples rows.
--
-- WHY THIS IS SAFE
-- * Column privileges are checked against the columns named in the UPDATE;
--   BEFORE-trigger writes (updated_at, protect_premium_status) are not, so
--   the timestamp trigger keeps working.
-- * is_premium was already silently reverted for authenticated callers by
--   protect_premium_status; the client write is removed in the same change
--   (CoupleSession.setPremium), so nothing user-visible changes.
-- * SELECT is untouched: the realtime .stream() on couples and the existing
--   SELECT policy keep working. The duplicate SELECT/UPDATE policies are
--   dropped; the remaining ones are identical in meaning.
-- * anon loses every table privilege on couples (it had full grants, with
--   policies alone keeping it out).
--
-- REGRESSION TEST
-- supabase/tests/010_couples_mutation.sql

DROP POLICY IF EXISTS "Enable delete for couple members" ON public.couples;
DROP POLICY IF EXISTS "Enable select for members" ON public.couples;
DROP POLICY IF EXISTS "Enable update for members" ON public.couples;

REVOKE ALL ON TABLE public.couples FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.couples FROM authenticated;
GRANT UPDATE (story_title, start_date, start_time_hour, start_time_minute) ON TABLE public.couples TO authenticated;
