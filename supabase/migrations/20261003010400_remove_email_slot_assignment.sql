-- Migration: Remove email-based slot assignment from recovery (audit F-24)
-- Created: 2026-10-03
--
-- PROBLEM (reproduced by supabase/tests/005_recovery.sql, F-24 block)
-- recover_relationship_with_code first checked whether the caller's email
-- matched partner_a_email / partner_b_email and, if so, wrote the caller into
-- that slot -- WITHOUT checking whether the slot was occupied. Any account
-- whose email matched a stale recorded address, and that held a valid code,
-- displaced the current partner. The logic was also dead for every couple
-- created after 20260808000003: create/join stopped recording emails, and
-- disconnect never cleared them, so only legacy rows carried (stale) emails.
--
-- NEW INVARIANT
-- A valid recovery code can only ever claim an EMPTY slot. Email addresses
-- play no part in relationship ownership and are no longer stored on couples.
--
-- WHY THIS IS SAFE
-- * Body is the previous live definition (20260926000000) minus the email
--   branch and the email writes; rate limiting, expiry, lockouts, structured
--   failures and the public-key write are unchanged.
-- * The recorded emails are cleared: nothing reads them for logic (the
--   RelationshipWorkspace model maps them as nullable fields, unused), and
--   keeping partner email addresses that drive nothing is needless PII. The
--   columns themselves are left in place to avoid a model/schema change.
--
-- REGRESSION TEST
-- supabase/tests/005_recovery.sql ("an email match cannot displace the
-- current occupant", "recovery no longer records email addresses").

CREATE OR REPLACE FUNCTION public.recover_relationship_with_code(
  p_recovery_code text,
  p_public_key text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
  v_code_clean text;
  v_first_hyphen_pos integer;
  v_lookup_key text;
  v_secret_clean text;
  v_couple_row record;
  v_user_couple_id uuid;
  v_user_attempts record;
  v_couple_attempts integer;
  v_success boolean := false;
  v_assigned_slot text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- Serialize attempts by one account, including the first attempt before
  -- its user_recovery_attempts row exists.
  SELECT couple_id INTO v_user_couple_id
  FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User profile unavailable';
  END IF;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  SELECT * INTO v_user_attempts
  FROM public.user_recovery_attempts WHERE user_id = auth.uid();
  IF v_user_attempts.locked_until > now() THEN
    RETURN json_build_object(
      'success', false, 'error_code', 'USER_LOCKED',
      'retry_after', v_user_attempts.locked_until
    );
  END IF;

  v_code_clean := upper(trim(coalesce(p_recovery_code, '')));
  v_first_hyphen_pos := position('-' in v_code_clean);

  IF v_first_hyphen_pos > 1 THEN
    v_lookup_key := substr(v_code_clean, 1, v_first_hyphen_pos - 1);
    v_secret_clean := replace(substr(v_code_clean, v_first_hyphen_pos + 1), '-', '');

    SELECT * INTO v_couple_row
    FROM public.couples
    WHERE recovery_lookup_key = v_lookup_key
    FOR UPDATE;

    IF v_couple_row.id IS NOT NULL THEN
      IF v_couple_row.recovery_locked_until > now() THEN
        RETURN json_build_object(
          'success', false, 'error_code', 'COUPLE_LOCKED',
          'retry_after', v_couple_row.recovery_locked_until
        );
      END IF;

      IF v_couple_row.recovery_code_generated_at IS NOT NULL
         AND v_couple_row.recovery_code_generated_at < now() - interval '90 days' THEN
        RAISE EXCEPTION 'Recovery code has expired (valid for 90 days). Request a new recovery code.';
      END IF;

      IF v_couple_row.recovery_code_hash = crypt(v_secret_clean, v_couple_row.recovery_code_hash) THEN
        v_success := true;
        UPDATE public.couples
        SET failed_recovery_attempts = 0, recovery_locked_until = NULL
        WHERE id = v_couple_row.id;
      ELSE
        v_couple_attempts := CASE
          WHEN v_couple_row.recovery_locked_until IS NOT NULL
               AND v_couple_row.recovery_locked_until <= now() THEN 0
          ELSE coalesce(v_couple_row.failed_recovery_attempts, 0)
        END;
        UPDATE public.couples
        SET failed_recovery_attempts = v_couple_attempts + 1,
            recovery_locked_until = CASE
              WHEN v_couple_attempts + 1 >= 5 THEN now() + interval '15 minutes'
              ELSE NULL
            END
        WHERE id = v_couple_row.id;
      END IF;
    END IF;
  END IF;

  IF NOT v_success THEN
    INSERT INTO public.user_recovery_attempts (user_id, failed_attempts, locked_until)
    VALUES (auth.uid(), 1, NULL)
    ON CONFLICT (user_id) DO UPDATE SET
      failed_attempts = CASE
        WHEN public.user_recovery_attempts.locked_until IS NOT NULL
             AND public.user_recovery_attempts.locked_until <= now() THEN 1
        ELSE public.user_recovery_attempts.failed_attempts + 1
      END,
      locked_until = CASE
        WHEN (CASE
          WHEN public.user_recovery_attempts.locked_until IS NOT NULL
               AND public.user_recovery_attempts.locked_until <= now() THEN 1
          ELSE public.user_recovery_attempts.failed_attempts + 1
        END) >= 5 THEN now() + interval '15 minutes'
        ELSE NULL
      END;

    RETURN json_build_object('success', false, 'error_code', 'INVALID_CODE');
  END IF;

  UPDATE public.user_recovery_attempts
  SET failed_attempts = 0, locked_until = NULL
  WHERE user_id = auth.uid();

  -- A valid code claims an EMPTY slot only. Never an occupied one.
  IF v_couple_row.partner_a_id IS NULL THEN
    UPDATE public.couples
    SET partner_a_id = auth.uid(), status = 'active'
    WHERE id = v_couple_row.id;
    v_assigned_slot := 'partner_a';
  ELSIF v_couple_row.partner_b_id IS NULL THEN
    UPDATE public.couples
    SET partner_b_id = auth.uid(), status = 'active'
    WHERE id = v_couple_row.id;
    v_assigned_slot := 'partner_b';
  ELSE
    RAISE EXCEPTION 'No vacant slot available in this relationship workspace';
  END IF;

  UPDATE public.users
  SET couple_id = v_couple_row.id, public_key = p_public_key
  WHERE id = auth.uid();

  RETURN json_build_object(
    'success', true, 'couple_id', v_couple_row.id, 'slot', v_assigned_slot
  );
END;
$$;

UPDATE public.couples
SET partner_a_email = NULL, partner_b_email = NULL
WHERE partner_a_email IS NOT NULL OR partner_b_email IS NOT NULL;
