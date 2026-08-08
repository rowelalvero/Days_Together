-- Migration: Recovery Hardening (H-3, H-4, H-5)
-- Created: 2026-08-08

-- ============================================================
-- 1. Add recovery_code_generated_at column (Audit H-3)
-- ============================================================
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS recovery_code_generated_at timestamptz DEFAULT now();

-- ============================================================
-- 2. Per-User Recovery Rate Limiting Table (Audit H-5)
-- Prevents attackers from bypassing rate limits by switching accounts
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_recovery_attempts (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  failed_attempts integer DEFAULT 0,
  locked_until timestamptz
);

ALTER TABLE public.user_recovery_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable select for own recovery attempts" ON public.user_recovery_attempts;
CREATE POLICY "Enable select for own recovery attempts" ON public.user_recovery_attempts
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- ============================================================
-- 3. Hardened recover_relationship_with_code RPC Function (Audit H-3, H-5)
-- Includes 90-day expiration and layered per-user + per-couple rate limiting
-- ============================================================
CREATE OR REPLACE FUNCTION public.recover_relationship_with_code(p_recovery_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_code_clean text;
  v_first_hyphen_pos integer;
  v_lookup_key text;
  v_secret text;
  v_secret_clean text;
  v_couple_row record;
  v_user_email text;
  v_success boolean := false;
  v_assigned_slot text;
  v_user_attempts record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND couple_id IS NOT NULL) THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  -- Layer 1: Check Per-User Rate Limit (Audit H-5)
  SELECT * INTO v_user_attempts FROM public.user_recovery_attempts WHERE user_id = auth.uid();
  IF v_user_attempts.locked_until IS NOT NULL AND v_user_attempts.locked_until > now() THEN
    RAISE EXCEPTION 'Too many failed recovery attempts from this account. Try again after %',
      to_char(v_user_attempts.locked_until, 'HH24:MI:SS');
  END IF;

  v_code_clean := upper(trim(p_recovery_code));
  v_first_hyphen_pos := position('-' in v_code_clean);

  IF v_first_hyphen_pos > 1 THEN
    v_lookup_key := substr(v_code_clean, 1, v_first_hyphen_pos - 1);
    v_secret := substr(v_code_clean, v_first_hyphen_pos + 1);
    v_secret_clean := replace(v_secret, '-', '');

    SELECT * INTO v_couple_row
    FROM public.couples
    WHERE recovery_lookup_key = v_lookup_key
    FOR UPDATE;

    IF v_couple_row.id IS NOT NULL THEN
      -- Layer 2: Check Per-Couple Rate Limit
      IF v_couple_row.recovery_locked_until IS NOT NULL
         AND v_couple_row.recovery_locked_until > now() THEN
        RAISE EXCEPTION 'Too many failed attempts on this recovery key. Try again after %',
          to_char(v_couple_row.recovery_locked_until, 'HH24:MI:SS');
      END IF;

      -- Check Expiration (90 Days - Audit H-3)
      IF v_couple_row.recovery_code_generated_at IS NOT NULL
         AND v_couple_row.recovery_code_generated_at < (now() - interval '90 days') THEN
        RAISE EXCEPTION 'Recovery code has expired (valid for 90 days). Request a new recovery code.';
      END IF;

      -- Verify Bcrypt Hash
      IF v_couple_row.recovery_code_hash = crypt(v_secret_clean, v_couple_row.recovery_code_hash) THEN
        v_success := true;
        -- Reset per-couple rate limit on success
        UPDATE public.couples
        SET failed_recovery_attempts = 0, recovery_locked_until = NULL
        WHERE id = v_couple_row.id;
      ELSE
        -- Increment per-couple rate limit
        UPDATE public.couples
        SET
          failed_recovery_attempts = COALESCE(v_couple_row.failed_recovery_attempts, 0) + 1,
          recovery_locked_until = CASE
            WHEN COALESCE(v_couple_row.failed_recovery_attempts, 0) + 1 >= 5
            THEN now() + interval '15 minutes'
            ELSE NULL
          END
        WHERE id = v_couple_row.id;
      END IF;
    END IF;
  END IF;

  IF NOT v_success THEN
    -- Increment per-user rate limit on failure (Audit H-5)
    INSERT INTO public.user_recovery_attempts (user_id, failed_attempts, locked_until)
    VALUES (auth.uid(), 1, NULL)
    ON CONFLICT (user_id) DO UPDATE SET
      failed_attempts = public.user_recovery_attempts.failed_attempts + 1,
      locked_until = CASE
        WHEN public.user_recovery_attempts.failed_attempts + 1 >= 5 THEN now() + interval '15 minutes'
        ELSE NULL
      END;

    RAISE EXCEPTION 'Invalid recovery code';
  END IF;

  -- Reset per-user rate limit on success
  UPDATE public.user_recovery_attempts
  SET failed_attempts = 0, locked_until = NULL
  WHERE user_id = auth.uid();

  SELECT email INTO v_user_email FROM auth.users WHERE id = auth.uid();

  -- Deterministic Assignment via Recorded Emails
  IF v_couple_row.partner_a_email = v_user_email THEN
    UPDATE public.couples SET partner_a_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    v_assigned_slot := 'partner_a';
  ELSIF v_couple_row.partner_b_email = v_user_email THEN
    UPDATE public.couples SET partner_b_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    v_assigned_slot := 'partner_b';
  ELSE
    IF v_couple_row.partner_a_id IS NULL THEN
      UPDATE public.couples SET partner_a_id = auth.uid(), partner_a_email = v_user_email, status = 'active' WHERE id = v_couple_row.id;
      v_assigned_slot := 'partner_a';
    ELSIF v_couple_row.partner_b_id IS NULL THEN
      UPDATE public.couples SET partner_b_id = auth.uid(), partner_b_email = v_user_email, status = 'active' WHERE id = v_couple_row.id;
      v_assigned_slot := 'partner_b';
    ELSE
      RAISE EXCEPTION 'No vacant slot available in this relationship workspace';
    END IF;
  END IF;

  UPDATE public.users SET couple_id = v_couple_row.id WHERE id = auth.uid();

  RETURN json_build_object('success', true, 'couple_id', v_couple_row.id, 'slot', v_assigned_slot);
END;
$$;

-- ============================================================
-- 4. User Deletion Cleanup Trigger Invalidation (Audit H-4)
-- Invalidates recovery codes when a user leaves/deletes so old codes cannot claim cleared slots
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_user_deletion_cleanup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id uuid;
  v_couple_id uuid;
BEGIN
  v_couple_id := OLD.couple_id;

  IF v_couple_id IS NOT NULL THEN
    -- Look up partner from couples table
    SELECT
      CASE WHEN partner_a_id = OLD.id THEN partner_b_id ELSE partner_a_id END
    INTO v_partner_id
    FROM public.couples
    WHERE id = v_couple_id;

    -- Notify the remaining partner
    IF v_partner_id IS NOT NULL THEN
      UPDATE public.users
      SET partner_deleted_notice = TRUE
      WHERE id = v_partner_id;
    END IF;

    -- Clear the deleted user's slot, email, and invalidate old recovery key (Audit H-4)
    UPDATE public.couples
    SET
      partner_a_id          = CASE WHEN partner_a_id = OLD.id THEN NULL ELSE partner_a_id END,
      partner_b_id          = CASE WHEN partner_b_id = OLD.id THEN NULL ELSE partner_b_id END,
      partner_a_email       = CASE WHEN partner_a_id = OLD.id THEN NULL ELSE partner_a_email END,
      partner_b_email       = CASE WHEN partner_b_id = OLD.id THEN NULL ELSE partner_b_email END,
      recovery_lookup_key   = NULL,
      recovery_code_hash    = NULL,
      recovery_code_generated_at = NULL
    WHERE id = v_couple_id;

    -- Clean up couples row only if no users remain in it
    IF NOT EXISTS (
      SELECT 1 FROM public.users
      WHERE couple_id = v_couple_id AND id != OLD.id
    ) THEN
      DELETE FROM public.couples WHERE id = v_couple_id;
    END IF;
  END IF;

  RETURN OLD;
END;
$$;
