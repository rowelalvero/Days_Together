-- Migration: Unlink invalidates the recovery credential (audit F-05 /
--            invariant S06)
-- Created: 2026-10-03
--
-- PROBLEM
-- Both partners are shown the couple's recovery code. disconnect_relationship
-- _workspace cleared the leaver's slot but left the recovery code valid, and
-- recover_relationship_with_code claims any EMPTY slot for a valid code -- so
-- the partner who unlinked (or anyone they showed the code to) could walk
-- straight back in, unannounced, with full access to all past and future
-- shared data. The remaining partner's device would then auto-wrap the couple
-- photo key for the "new" partner identity.
--
-- PREVIOUS BEHAVIOUR
-- Unlink: users.couple_id cleared, slot cleared, recovery code untouched.
-- (Account deletion already nulled the code -- handle_user_deletion_cleanup,
-- 20260808000001 -- so unlink was the inconsistent path.)
--
-- NEW INVARIANT
-- After any partner leaves, no recovery code issued before the departure
-- works. Re-entry needs a code the remaining partner regenerates afterwards
-- (regenerate_recovery_code) and chooses to share -- consent is explicit.
--
-- WHY THIS IS SAFE
-- Body is the previous live definition (20260712000001) plus: the three
-- recovery columns are nulled, and the leaver's recorded email slot (dead
-- since audit F-24, see 20261003010400) is cleared alongside their id. The
-- remaining partner is unaffected (their couple_id and slot stay); they only
-- lose a code that was already compromised by being known to the leaver.
-- NOTE: when the second partner also unlinks, the couple and its data become
-- unreachable (no member, no valid code). That was already true for account
-- deletion; data retention for such couples is a separate decision.
--
-- REGRESSION TEST
-- supabase/tests/006_unlink.sql (old code rejected; consented re-entry with a
-- freshly regenerated code still works).

CREATE OR REPLACE FUNCTION public.disconnect_relationship_workspace()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_couple_id uuid;
  v_other_connected boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT couple_id INTO v_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_couple_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not in a relationship');
  END IF;

  PERFORM 1 FROM public.couples WHERE id = v_couple_id FOR UPDATE;

  UPDATE public.users SET couple_id = NULL WHERE id = auth.uid();

  UPDATE public.couples
  SET
    partner_a_email = CASE WHEN partner_a_id = auth.uid() THEN NULL ELSE partner_a_email END,
    partner_b_email = CASE WHEN partner_b_id = auth.uid() THEN NULL ELSE partner_b_email END,
    partner_a_id = CASE WHEN partner_a_id = auth.uid() THEN NULL ELSE partner_a_id END,
    partner_b_id = CASE WHEN partner_b_id = auth.uid() THEN NULL ELSE partner_b_id END,
    -- The leaver has seen the current code: it can no longer prove consent.
    recovery_lookup_key = NULL,
    recovery_code_hash = NULL,
    recovery_code_generated_at = NULL
  WHERE id = v_couple_id;

  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE couple_id = v_couple_id AND id != auth.uid()
  ) INTO v_other_connected;

  IF NOT v_other_connected THEN
    UPDATE public.couples SET status = 'disconnected' WHERE id = v_couple_id;
  END IF;

  RETURN json_build_object('success', true);
END;
$$;
