-- Migration: 20-Minute Periodic Pairing Code Rotation (Preserves code until rotated or paired)
-- Created: 2026-08-08

-- ============================================================
-- 1. Add pairing_code_updated_at Timestamp Column to public.couples
-- ============================================================
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS pairing_code_updated_at timestamptz DEFAULT now();

-- Ensure default timestamps for existing rows
UPDATE public.couples SET pairing_code_updated_at = now() WHERE pairing_code_updated_at IS NULL;

-- ============================================================
-- 2. Update create_relationship_workspace RPC
-- Sets initial pairing_code_updated_at timestamp
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_relationship_workspace()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
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
  -- Lock caller row to prevent concurrent updates
  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  v_couple_id := gen_random_uuid();
  
  -- Retry loop to generate unique codes
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

  -- Generate 16-char secret key grouped with hyphens
  v_secret_clean := '';
  FOR i IN 1..16 LOOP
    v_secret_clean := v_secret_clean || substr(chars, floor(random() * 36)::integer + 1, 1);
  END LOOP;

  v_secret_formatted := substr(v_secret_clean, 1, 4) || '-' ||
                        substr(v_secret_clean, 5, 4) || '-' ||
                        substr(v_secret_clean, 9, 4) || '-' ||
                        substr(v_secret_clean, 13, 4);

  -- Insert couple row
  INSERT INTO public.couples (
    id, status, partner_a_id, pairing_code, pairing_code_updated_at, recovery_lookup_key, recovery_code_hash
  )
  VALUES (
    v_couple_id,
    'waiting',
    auth.uid(),
    v_pairing_code,
    now(),
    v_lookup_key,
    crypt(v_secret_clean, gen_salt('bf', 10))
  );

  -- Update user couple_id
  UPDATE public.users SET couple_id = v_couple_id WHERE id = auth.uid();

  RETURN json_build_object(
    'success', true,
    'couple_id', v_couple_id,
    'pairing_code', v_pairing_code,
    'recovery_code', v_lookup_key || '-' || v_secret_formatted,
    'expires_in_seconds', 1200
  );
END;
$$;

-- ============================================================
-- 3. Define get_or_rotate_pairing_code RPC Function
-- Rotates pairing code every 20 mins while waiting for partner
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_or_rotate_pairing_code(p_force_rotate boolean DEFAULT false)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_couple_id uuid;
  v_current_code text;
  v_updated_at timestamptz;
  v_status text;
  v_new_code text;
  v_code_exists boolean;
  chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  i integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT id, status, pairing_code, pairing_code_updated_at
  INTO v_couple_id, v_status, v_current_code, v_updated_at
  FROM public.couples
  WHERE (partner_a_id = auth.uid() OR partner_b_id = auth.uid())
  FOR UPDATE;

  IF v_couple_id IS NULL THEN
    RAISE EXCEPTION 'User is not in a relationship workspace';
  END IF;

  IF v_status != 'waiting' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Relationship is already active'
    );
  END IF;

  -- Rotate code if missing, older than 20 mins (1200s), or explicitly requested
  IF p_force_rotate OR v_current_code IS NULL OR v_updated_at IS NULL OR (now() - v_updated_at) > interval '20 minutes' THEN
    LOOP
      v_new_code := '';
      FOR i IN 1..6 LOOP
        v_new_code := v_new_code || substr(chars, floor(random() * 36)::integer + 1, 1);
      END LOOP;

      SELECT EXISTS(SELECT 1 FROM public.couples WHERE pairing_code = v_new_code) INTO v_code_exists;
      IF NOT v_code_exists THEN
        EXIT;
      END IF;
    END LOOP;

    UPDATE public.couples
    SET pairing_code = v_new_code,
        pairing_code_updated_at = now()
    WHERE id = v_couple_id;

    v_current_code := v_new_code;
    v_updated_at := now();
  END IF;

  RETURN json_build_object(
    'success', true,
    'couple_id', v_couple_id,
    'pairing_code', v_current_code,
    'expires_in_seconds', GREATEST(0, extract(epoch from (v_updated_at + interval '20 minutes' - now()))::integer)
  );
END;
$$;

-- ============================================================
-- 4. Update join_relationship_with_code RPC
-- Enforces 20-minute validity boundary
-- ============================================================
CREATE OR REPLACE FUNCTION public.join_relationship_with_code(p_pairing_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_couple_row public.couples%ROWTYPE;
  v_user_couple_id uuid;
BEGIN
  -- Lock caller row to prevent race conditions
  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  -- Find and lock couples row matching code and waiting status
  SELECT * INTO v_couple_row
  FROM public.couples
  WHERE upper(pairing_code) = upper(trim(p_pairing_code))
    AND status = 'waiting'
    AND partner_b_id IS NULL
  FOR UPDATE;

  IF v_couple_row.id IS NULL THEN
    RAISE EXCEPTION 'Invalid connection code. Please check the code and try again.';
  END IF;

  IF v_couple_row.partner_a_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot pair with yourself';
  END IF;

  -- Enforce 20-minute expiration limit
  IF v_couple_row.pairing_code_updated_at IS NOT NULL AND (now() - v_couple_row.pairing_code_updated_at) > interval '20 minutes' THEN
    RAISE EXCEPTION 'This connection code has expired (20 min limit). Please ask your partner for their updated code.';
  END IF;

  -- Update couple record to active, clear pairing_code upon successful pairing
  UPDATE public.couples
  SET 
    partner_b_id = auth.uid(),
    status = 'active',
    pairing_code = NULL
  WHERE id = v_couple_row.id;

  -- Update user record
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
