-- Migration: Regenerated recovery codes start a fresh validity period
--            (audit F-09 / invariant S07; audit F-17 / invariant S04)
-- Created: 2026-10-03
--
-- PROBLEM
-- regenerate_recovery_code (last defined in 20260711000000) predates the
-- recovery_code_generated_at column and the per-couple lockout columns
-- (20260713000000, 20260808000001), so it never touched them:
--  * For a couple created more than 90 days ago, a freshly regenerated code
--    was already "expired" -- the recovery RPC checks generated_at -- so the
--    only way back in after losing a device was dead on arrival.
--  * After a partner's account deletion nulls generated_at, a regenerated
--    code never expired at all.
--  * An active per-couple lockout survived regeneration, refusing the new
--    code for up to 15 minutes.
--  * The code itself came from random(), not a CSPRNG.
--
-- NEW INVARIANT
-- Regeneration atomically replaces the lookup key and secret hash, stamps
-- recovery_code_generated_at = now(), and clears the per-couple lockout; the
-- previous code stops working immediately.
--
-- WHY THIS IS SAFE
-- Body is the previous live definition (20260711000000) with the code drawn
-- from generate_secure_code (20261003000200) and the three extra columns set
-- in the same UPDATE. Signature, return shape and grants are unchanged.
--
-- REGRESSION TEST
-- supabase/tests/005_recovery.sql (S07 block); 006_unlink.sql (consented
-- re-entry uses a regenerated code).

CREATE OR REPLACE FUNCTION public.regenerate_recovery_code()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_couple_id uuid;
  v_lookup_key text;
  v_secret_clean text;
  v_secret_formatted text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT couple_id INTO v_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_couple_id IS NULL THEN
    RAISE EXCEPTION 'Not in a relationship';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.couples WHERE id = v_couple_id AND (partner_a_id = auth.uid() OR partner_b_id = auth.uid()) FOR UPDATE
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  LOOP
    v_lookup_key := public.generate_secure_code(6);
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.couples WHERE recovery_lookup_key = v_lookup_key);
  END LOOP;

  v_secret_clean := public.generate_secure_code(16);
  v_secret_formatted := substr(v_secret_clean, 1, 4) || '-' ||
                        substr(v_secret_clean, 5, 4) || '-' ||
                        substr(v_secret_clean, 9, 4) || '-' ||
                        substr(v_secret_clean, 13, 4);

  UPDATE public.couples
  SET
    recovery_lookup_key = v_lookup_key,
    recovery_code_hash = crypt(v_secret_clean, gen_salt('bf', 10)),
    recovery_code_generated_at = now(),
    failed_recovery_attempts = 0,
    recovery_locked_until = NULL
  WHERE id = v_couple_id;

  RETURN json_build_object(
    'success', true,
    'recovery_code', v_lookup_key || '-' || v_secret_formatted
  );
END;
$$;
