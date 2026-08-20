-- Migration: Protect users.couple_id from client tampering (SEC-2)
-- Created: 2026-08-20
--
-- PROBLEM
-- The "Enable update for own profile" policy (20260808000000_security_remediation.sql)
-- is USING (auth.uid() = id) WITH CHECK (auth.uid() = id) with no column constraint,
-- so any authenticated user could run:
--     UPDATE public.users SET couple_id = '<victim_couple_id>' WHERE id = auth.uid();
-- and thereby pivot into another couple's data. The INSERT policy
-- (20260712000001_refactor_users_profiles.sql) has the same hole.
--
-- This mattered because several policies resolve the caller's couple via the
-- unverified `SELECT couple_id FROM public.users WHERE id = auth.uid()` predicate:
--   * storage.objects read/write policies (foldername(name)[2] = couple_id)
--   * public.topic_card_likes and public.love_taps (fixed in section 3 below)
--
-- APPROACH
-- Validate rather than blanket-block. A blanket block cannot work because
-- auth.role() stays 'authenticated' inside SECURITY DEFINER functions, so the
-- pairing/recovery RPCs cannot be exempted by role. Validation is safe because
-- every live RPC sets couples.partner_a_id / partner_b_id BEFORE writing
-- users.couple_id, so the EXISTS check below already passes at write time.
--
-- ROLLBACK
--   DROP TRIGGER IF EXISTS trg_protect_users_couple_id ON public.users;
--   DROP FUNCTION IF EXISTS public.protect_users_couple_id();
--   (Sections 2 and 3 are not auto-reversible; see notes inline.)


-- =====================================================================
-- 1. VALIDATING TRIGGER ON public.users.couple_id
-- =====================================================================
-- Mirrors the existing protect_premium_status() pattern
-- (20260711000000_audit_fixes.sql): a BEFORE trigger that silently reverts an
-- illegitimate value instead of raising, so clients see no behavioural change.
--
-- SECURITY DEFINER is REQUIRED. As an invoker-rights function the EXISTS check
-- would be filtered by the couples SELECT policy
-- (20260713000000_audit_p1_hardening.sql), which returns FALSE whenever
-- NEW.id != auth.uid() -- that would break update_partner_profile and the
-- partner-notify write inside handle_user_deletion_cleanup.
CREATE OR REPLACE FUNCTION public.protect_users_couple_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  -- INSERT: OLD is unassigned, so there is nothing to revert to. An
  -- unsubstantiated couple_id is downgraded to NULL rather than rejected, so
  -- handle_new_user() and the client's self-heal upsert keep working.
  IF TG_OP = 'INSERT' THEN
    IF NEW.couple_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.couples
      WHERE id = NEW.couple_id
        AND (partner_a_id = NEW.id OR partner_b_id = NEW.id)
    ) THEN
      NEW.couple_id := NULL;
    END IF;
    RETURN NEW;
  END IF;

  -- UPDATE. Three guards, all load-bearing:
  --   IS DISTINCT FROM -> skip the subquery on unrelated updates (FCM token
  --     sync, current_activity, partner_deleted_notice, the profile setters).
  --   IS NOT NULL      -> clearing the link must always be permitted.
  --     disconnect_relationship_workspace (20260712000001) clears
  --     users.couple_id BEFORE clearing couples.partner_*_id, the FK is
  --     ON DELETE SET NULL, and the client self-heal writes NULL directly.
  --     Without this exemption, unlink silently becomes a no-op.
  --   NOT EXISTS       -> the actual authorisation check.
  IF NEW.couple_id IS DISTINCT FROM OLD.couple_id
     AND NEW.couple_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM public.couples
       WHERE id = NEW.couple_id
         AND (partner_a_id = NEW.id OR partner_b_id = NEW.id)
     ) THEN
    NEW.couple_id := OLD.couple_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_users_couple_id ON public.users;
CREATE TRIGGER trg_protect_users_couple_id
  BEFORE INSERT OR UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_users_couple_id();
-- Note: shares BEFORE UPDATE timing with set_users_updated_at
-- (20260808000002_database_constraints.sql). Same-timing triggers fire in
-- alphabetical order, so this one runs first; harmless, as handle_updated_at()
-- only touches NEW.updated_at.


-- =====================================================================
-- 2. DROP THE ORPHANED LEGACY PAIRING FUNCTION
-- =====================================================================
-- public.join_couple_with_code(text) (20260630000002_pairing_flow_hardening.sql)
-- was superseded by join_relationship_with_code() but never dropped. It is:
--   * unreachable  -- no Dart caller (verified by grep across lib/)
--   * unsafe       -- SECURITY DEFINER with NO `SET search_path`
--   * an escalation vector -- it writes ANOTHER user's couple_id and partner_id
--   * incompatible -- it never populates couples.partner_a_id/partner_b_id, so
--     it is the one function the trigger above would break.
-- Not reversible: restore from 20260630000002 if ever needed.
DROP FUNCTION IF EXISTS public.join_couple_with_code(text);


-- =====================================================================
-- 3. MIGRATE topic_card_likes AND love_taps ONTO is_member_of_couple()
-- =====================================================================
-- These two tables were never moved onto the hardened helper and still trust
-- users.couple_id directly. Every other couple-scoped table (bucket_list,
-- calendar_events, daily_questions, gift_reminders, love_notes, moods,
-- time_capsules, timeline_items, topic_cards, vault_items) already uses
-- is_member_of_couple(), which additionally verifies membership against
-- couples.partner_a_id/partner_b_id and excludes archived couples.
--
-- Behaviour change: rows belonging to an ARCHIVED couple become inaccessible,
-- matching how the other ten tables already behave.
--
-- Policy names collide across the two tables ("Enable select for same couple"
-- exists on both), so every DROP below is table-qualified.

-- 3a. topic_card_likes
DROP POLICY IF EXISTS "Enable select for same couple" ON public.topic_card_likes;
CREATE POLICY "Enable select for same couple" ON public.topic_card_likes
  FOR SELECT TO authenticated
  USING (public.is_member_of_couple(couple_id));

DROP POLICY IF EXISTS "Enable insert for own user" ON public.topic_card_likes;
CREATE POLICY "Enable insert for own user" ON public.topic_card_likes
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND public.is_member_of_couple(couple_id)
  );

-- The DELETE policy is deliberately left as-is: USING (user_id = auth.uid())
-- is already a strong predicate (you may only delete your own like), and
-- re-scoping it to is_member_of_couple() would prevent users from removing
-- their own likes once a couple is archived.

-- 3b. love_taps
DROP POLICY IF EXISTS "Enable select for same couple" ON public.love_taps;
CREATE POLICY "Enable select for same couple" ON public.love_taps
  FOR SELECT TO authenticated
  USING (public.is_member_of_couple(couple_id));

DROP POLICY IF EXISTS "Enable insert for same couple" ON public.love_taps;
CREATE POLICY "Enable insert for same couple" ON public.love_taps
  FOR INSERT TO authenticated
  WITH CHECK (public.is_member_of_couple(couple_id));

DROP POLICY IF EXISTS "Enable update for same couple" ON public.love_taps;
CREATE POLICY "Enable update for same couple" ON public.love_taps
  FOR UPDATE TO authenticated
  USING (public.is_member_of_couple(couple_id))
  WITH CHECK (public.is_member_of_couple(couple_id));
