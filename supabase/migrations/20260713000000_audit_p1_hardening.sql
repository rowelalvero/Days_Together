-- Migration: Audit P1 Hardening
-- Created: 2026-07-13
-- Addresses: Audit issues 1.1, 1.5, 2.2, 3.1, 7.1, 7.2, 8.1, 8.5, 14.3

-- ============================================================
-- 1A. Recovery Code Brute-Force Rate Limiting (Audit 7.1)
-- ============================================================
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS failed_recovery_attempts integer DEFAULT 0;
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS recovery_locked_until timestamptz;

-- ============================================================
-- 1B. Unique Index on recovery_lookup_key (Audit 2.2, 8.1)
-- ============================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_couples_recovery_lookup_key
  ON public.couples (recovery_lookup_key) WHERE recovery_lookup_key IS NOT NULL;

-- ============================================================
-- 1C + 1D. Idempotent Deletion Trigger with Slot/Email Clearing (Audit 1.5, 8.5)
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

    -- Clear the deleted user's slot AND email from the couples row (Audit 1.5)
    UPDATE public.couples
    SET
      partner_a_id    = CASE WHEN partner_a_id = OLD.id THEN NULL ELSE partner_a_id END,
      partner_b_id    = CASE WHEN partner_b_id = OLD.id THEN NULL ELSE partner_b_id END,
      partner_a_email = CASE WHEN partner_a_id = OLD.id THEN NULL ELSE partner_a_email END,
      partner_b_email = CASE WHEN partner_b_id = OLD.id THEN NULL ELSE partner_b_email END
    WHERE id = v_couple_id;

    -- Clean up couples row only if no users remain in it (idempotent guard - Audit 8.5)
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

-- ============================================================
-- 1E. Verify love_notes FK is ON DELETE SET NULL (Audit 2.1, 14.3)
-- Already applied in 20260712000001 migration. Re-apply idempotently.
-- ============================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'love_notes_sender_id_fkey'
      AND table_name = 'love_notes'
  ) THEN
    -- Check if the current FK has CASCADE instead of SET NULL
    IF EXISTS (
      SELECT 1 FROM information_schema.referential_constraints
      WHERE constraint_name = 'love_notes_sender_id_fkey'
        AND delete_rule = 'CASCADE'
    ) THEN
      ALTER TABLE public.love_notes DROP CONSTRAINT love_notes_sender_id_fkey;
      ALTER TABLE public.love_notes ADD CONSTRAINT love_notes_sender_id_fkey
        FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;
  END IF;
END $$;

-- ============================================================
-- 1F. Couples SELECT RLS — Explicit auth.uid() guard (Audit 7.2)
-- ============================================================
DROP POLICY IF EXISTS "Enable select for couple members" ON public.couples;
CREATE POLICY "Enable select for couple members" ON public.couples
  FOR SELECT TO authenticated
  USING (auth.uid() IS NOT NULL AND (auth.uid() = partner_a_id OR auth.uid() = partner_b_id));

-- ============================================================
-- 1A (continued). Update recover_relationship_with_code with rate limiting
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
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND couple_id IS NOT NULL) THEN
    RAISE EXCEPTION 'User is already in a relationship';
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
      -- Rate limiting check (Audit 7.1)
      IF v_couple_row.recovery_locked_until IS NOT NULL
         AND v_couple_row.recovery_locked_until > now() THEN
        RAISE EXCEPTION 'Too many failed attempts. Try again after %',
          to_char(v_couple_row.recovery_locked_until, 'HH24:MI:SS');
      END IF;

      IF v_couple_row.recovery_code_hash = crypt(v_secret_clean, v_couple_row.recovery_code_hash) THEN
        v_success := true;
        -- Reset failed attempts on success
        UPDATE public.couples
        SET failed_recovery_attempts = 0, recovery_locked_until = NULL
        WHERE id = v_couple_row.id;
      ELSE
        -- Increment failed attempts
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
    RAISE EXCEPTION 'Invalid recovery code';
  END IF;

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
