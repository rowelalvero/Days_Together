-- Migration: Security Hardening - Search Path, Rate Limiting, and RLS Isolation
-- Created: 2026-07-07

-- 1. ADD PAIRING CODE RATE LIMITING
CREATE TABLE IF NOT EXISTS public.failed_pairing_attempts (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  attempts integer DEFAULT 0 NOT NULL,
  locked_until timestamp with time zone,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.failed_pairing_attempts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable select/update for own pairing attempts" ON public.failed_pairing_attempts;
CREATE POLICY "Enable select/update for own pairing attempts" ON public.failed_pairing_attempts
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 2. HARDEN SECURITY DEFINER FUNCTIONS (SET search_path)
-- This prevents search path hijacking attacks.

-- get_user_couple_id
CREATE OR REPLACE FUNCTION public.get_user_couple_id(user_id uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT couple_id::text FROM public.users WHERE id = user_id;
$$;

-- is_member_of_couple
CREATE OR REPLACE FUNCTION public.is_member_of_couple(couple_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.couples c ON c.id = u.couple_id
    WHERE u.id = auth.uid()
      AND u.couple_id = is_member_of_couple.couple_id
      AND (c.partner_a_id = auth.uid() OR c.partner_b_id = auth.uid())
      AND c.status != 'archived'
  );
END;
$$;

-- handle_user_deletion_cleanup
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
  v_partner_id := OLD.partner_id;
  v_couple_id := OLD.couple_id;

  IF v_partner_id IS NOT NULL THEN
    UPDATE public.users
    SET
      partner_id = NULL,
      couple_id = NULL,
      partner_deleted_notice = TRUE
    WHERE id = v_partner_id;
  END IF;

  IF v_couple_id IS NOT NULL THEN
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

-- delete_current_user
CREATE OR REPLACE FUNCTION public.delete_current_user()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  DELETE FROM auth.users WHERE id = v_user_id;

  RETURN json_build_object('success', true);
END;
$$;

-- create_relationship_workspace
CREATE OR REPLACE FUNCTION public.create_relationship_workspace()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_couple_id uuid;
  v_pairing_code text;
  v_lookup_key text;
  v_secret_formatted text;
  v_secret_clean text;
  v_user_couple_id uuid;
  v_code_exists boolean;
  v_lookup_exists boolean;
  chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  i integer;
BEGIN
  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  v_couple_id := gen_random_uuid();

  LOOP
    v_pairing_code := '';
    FOR i IN 1..6 LOOP
      v_pairing_code := v_pairing_code || substr(chars, floor(random() * 36)::integer + 1, 1);
    END LOOP;

    v_lookup_key := '';
    FOR i IN 1..6 LOOP
      v_lookup_key := v_lookup_key || substr(chars, floor(random() * 36)::integer + 1, 1);
    END LOOP;

    SELECT EXISTS(SELECT 1 FROM public.couples WHERE pairing_code = v_pairing_code) INTO v_code_exists;
    SELECT EXISTS(SELECT 1 FROM public.couples WHERE recovery_lookup_key = v_lookup_key) INTO v_lookup_exists;

    IF NOT v_code_exists AND NOT v_lookup_exists THEN
      EXIT;
    END IF;
  END LOOP;

  v_secret_clean := '';
  FOR i IN 1..16 LOOP
    v_secret_clean := v_secret_clean || substr(chars, floor(random() * 36)::integer + 1, 1);
  END LOOP;

  v_secret_formatted := substr(v_secret_clean, 1, 4) || '-' ||
                        substr(v_secret_clean, 5, 4) || '-' ||
                        substr(v_secret_clean, 9, 4) || '-' ||
                        substr(v_secret_clean, 13, 4);

  INSERT INTO public.couples (id, status, partner_a_id, pairing_code, recovery_lookup_key, recovery_code_hash)
  VALUES (
    v_couple_id,
    'waiting',
    auth.uid(),
    v_pairing_code,
    v_lookup_key,
    crypt(v_secret_clean, gen_salt('bf', 10))
  );

  UPDATE public.users SET couple_id = v_couple_id WHERE id = auth.uid();

  RETURN json_build_object(
    'success', true,
    'couple_id', v_couple_id,
    'pairing_code', v_pairing_code,
    'recovery_code', v_lookup_key || '-' || v_secret_formatted
  );
END;
$$;

-- join_relationship_with_code (Updated with rate limiting)
CREATE OR REPLACE FUNCTION public.join_relationship_with_code(p_pairing_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_couple_row public.couples%ROWTYPE;
  v_user_couple_id uuid;
  v_attempts integer;
  v_locked_until timestamp with time zone;
BEGIN
  -- 1. Check rate limiting
  SELECT attempts, locked_until INTO v_attempts, v_locked_until
  FROM public.failed_pairing_attempts
  WHERE user_id = auth.uid()
  FOR UPDATE;

  IF v_locked_until IS NOT NULL AND v_locked_until > now() THEN
    RAISE EXCEPTION 'Too many failed attempts. Try again after %', v_locked_until;
  END IF;

  -- 2. Lock caller row
  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  -- 3. Find and lock couples row
  SELECT * INTO v_couple_row
  FROM public.couples
  WHERE upper(pairing_code) = upper(trim(p_pairing_code))
    AND status = 'waiting'
    AND partner_b_id IS NULL
  FOR UPDATE;

  IF v_couple_row.id IS NULL THEN
    -- Log failed attempt
    INSERT INTO public.failed_pairing_attempts (user_id, attempts, locked_until)
    VALUES (auth.uid(), 1, NULL)
    ON CONFLICT (user_id) DO UPDATE SET
      attempts = failed_pairing_attempts.attempts + 1,
      locked_until = CASE WHEN failed_pairing_attempts.attempts + 1 >= 5 THEN now() + interval '15 minutes' ELSE NULL END,
      updated_at = now();

    RAISE EXCEPTION 'Invalid or expired pairing code';
  END IF;

  IF v_couple_row.partner_a_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot pair with yourself';
  END IF;

  -- 4. Success: Reset attempts and update records
  INSERT INTO public.failed_pairing_attempts (user_id, attempts, locked_until)
  VALUES (auth.uid(), 0, NULL)
  ON CONFLICT (user_id) DO UPDATE SET attempts = 0, locked_until = NULL;

  UPDATE public.couples
  SET
    partner_b_id = auth.uid(),
    status = 'active',
    pairing_code = NULL
  WHERE id = v_couple_row.id;

  UPDATE public.users
  SET couple_id = v_couple_row.id
  WHERE id = auth.uid();

  RETURN json_build_object(
    'success', true,
    'couple_id', v_couple_row.id,
    'partner_id', v_couple_row.partner_a_id
  );
END;
$$;

-- recover_relationship_with_code
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
  v_couple_id uuid;
  v_couple_row record;
  v_attempts integer;
  v_locked_until timestamp with time zone;
  v_user_couple_id uuid;
  v_success boolean := false;
BEGIN
  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  SELECT attempts, locked_until INTO v_attempts, v_locked_until
  FROM public.failed_recovery_attempts
  WHERE user_id = auth.uid()
  FOR UPDATE;

  IF v_locked_until IS NOT NULL AND v_locked_until > now() THEN
    RAISE EXCEPTION 'Too many failed attempts. Try again after %', v_locked_until;
  END IF;

  v_code_clean := upper(trim(p_recovery_code));
  v_first_hyphen_pos := position('-' in v_code_clean);

  IF v_first_hyphen_pos > 1 THEN
    v_lookup_key := substr(v_code_clean, 1, v_first_hyphen_pos - 1);
    v_secret := substr(v_code_clean, v_first_hyphen_pos + 1);
    v_secret_clean := replace(replace(v_secret, '-', ''), ' ', '');

    SELECT * INTO v_couple_row
    FROM public.couples
    WHERE recovery_lookup_key = v_lookup_key
    FOR UPDATE;

    IF v_couple_row.id IS NOT NULL THEN
      IF v_couple_row.recovery_code_hash = crypt(v_secret_clean, v_couple_row.recovery_code_hash) THEN
        IF v_couple_row.partner_a_id = auth.uid() OR v_couple_row.partner_b_id = auth.uid() OR v_couple_row.partner_a_id IS NULL OR v_couple_row.partner_b_id IS NULL THEN
          v_success := true;
        END IF;
      END IF;
    END IF;
  END IF;

  IF v_success THEN
    IF v_couple_row.partner_a_id IS NULL AND (v_couple_row.partner_b_id IS NULL OR v_couple_row.partner_b_id != auth.uid()) THEN
      UPDATE public.couples SET partner_a_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    ELSIF v_couple_row.partner_b_id IS NULL AND (v_couple_row.partner_a_id IS NULL OR v_couple_row.partner_a_id != auth.uid()) THEN
      UPDATE public.couples SET partner_b_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    ELSE
      UPDATE public.couples SET status = 'active' WHERE id = v_couple_row.id;
    END IF;

    INSERT INTO public.failed_recovery_attempts (user_id, attempts, locked_until)
    VALUES (auth.uid(), 0, NULL)
    ON CONFLICT (user_id) DO UPDATE SET attempts = 0, locked_until = NULL;

    UPDATE public.users SET couple_id = v_couple_row.id WHERE id = auth.uid();

    RETURN json_build_object(
      'success', true,
      'couple_id', v_couple_row.id
    );
  ELSE
    INSERT INTO public.failed_recovery_attempts (user_id, attempts, locked_until)
    VALUES (auth.uid(), 1, NULL)
    ON CONFLICT (user_id) DO UPDATE SET
      attempts = failed_recovery_attempts.attempts + 1,
      locked_until = CASE WHEN failed_recovery_attempts.attempts + 1 >= 5 THEN now() + interval '15 minutes' ELSE NULL END,
      updated_at = now();

    RAISE EXCEPTION 'Invalid recovery code';
  END IF;
END;
$$;

-- regenerate_recovery_code
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
  v_lookup_exists boolean;
  chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  i integer;
BEGIN
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
    v_lookup_key := '';
    FOR i IN 1..6 LOOP
      v_lookup_key := v_lookup_key || substr(chars, floor(random() * 36)::integer + 1, 1);
    END LOOP;

    SELECT EXISTS (SELECT 1 FROM public.couples WHERE recovery_lookup_key = v_lookup_key) INTO v_lookup_exists;
    IF NOT v_lookup_exists THEN
      EXIT;
    END IF;
  END LOOP;

  v_secret_clean := '';
  FOR i IN 1..16 LOOP
    v_secret_clean := v_secret_clean || substr(chars, floor(random() * 36)::integer + 1, 1);
  END LOOP;

  v_secret_formatted := substr(v_secret_clean, 1, 4) || '-' ||
                        substr(v_secret_clean, 5, 4) || '-' ||
                        substr(v_secret_clean, 9, 4) || '-' ||
                        substr(v_secret_clean, 13, 4);

  UPDATE public.couples
  SET
    recovery_lookup_key = v_lookup_key,
    recovery_code_hash = crypt(v_secret_clean, gen_salt('bf', 10))
  WHERE id = v_couple_id;

  RETURN json_build_object(
    'success', true,
    'recovery_code', v_lookup_key || '-' || v_secret_formatted
  );
END;
$$;

-- disconnect_relationship_workspace
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
  SELECT couple_id INTO v_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_couple_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not in a relationship');
  END IF;

  PERFORM 1 FROM public.couples WHERE id = v_couple_id FOR UPDATE;

  UPDATE public.users SET couple_id = NULL WHERE id = auth.uid();

  UPDATE public.couples
  SET
    partner_a_id = CASE WHEN partner_a_id = auth.uid() THEN NULL ELSE partner_a_id END,
    partner_b_id = CASE WHEN partner_b_id = auth.uid() THEN NULL ELSE partner_b_id END
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

-- 3. TIGHTEN RLS POLICIES

-- public.users: Restrict SELECT to self and partner only
DROP POLICY IF EXISTS "Enable select for authenticated users" ON public.users;
CREATE POLICY "Enable select for self and partner" ON public.users
  FOR SELECT TO authenticated
  USING (
    id = auth.uid()
    OR
    (couple_id IS NOT NULL AND couple_id = (SELECT u.couple_id FROM public.users u WHERE u.id = auth.uid()))
  );

-- public.couples: Restrict SELECT/UPDATE to members
DROP POLICY IF EXISTS "Enable select for couple members" ON public.couples;
CREATE POLICY "Enable select for members" ON public.couples
  FOR SELECT TO authenticated
  USING (partner_a_id = auth.uid() OR partner_b_id = auth.uid());

DROP POLICY IF EXISTS "Enable update for couple members" ON public.couples;
CREATE POLICY "Enable update for members" ON public.couples
  FOR UPDATE TO authenticated
  USING (partner_a_id = auth.uid() OR partner_b_id = auth.uid())
  WITH CHECK (partner_a_id = auth.uid() OR partner_b_id = auth.uid());

-- Ensure other tables have strictly scoped policies
-- All feature tables (love_notes, timeline_items, etc.) use is_member_of_couple(couple_id).
-- Since we hardened is_member_of_couple above, those tables are now more secure.
