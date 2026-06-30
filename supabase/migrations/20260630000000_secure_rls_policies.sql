-- Migration: Secure RLS Policies and Implement Join Couple RPC
-- Created: 2026-06-30

-- 1. DROP INSECURE POLICIES
DROP POLICY IF EXISTS "Enable select for authenticated users" ON public.pairing_codes;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.pairing_codes;
DROP POLICY IF EXISTS "Enable update for own profile or pairing partner" ON public.users;

-- 2. CREATE SECURE POLICIES FOR pairing_codes
-- Allow creators to select/read their own pairing codes
CREATE POLICY "Enable select for creator" ON public.pairing_codes
  FOR SELECT TO authenticated
  USING (auth.uid() = creator_id);

-- Allow creators to delete/cancel their own pairing codes
CREATE POLICY "Enable delete for creator" ON public.pairing_codes
  FOR DELETE TO authenticated
  USING (auth.uid() = creator_id);

-- 3. CREATE SECURE POLICIES FOR users
-- Restrict updates strictly to the user's own profile
CREATE POLICY "Enable update for own profile" ON public.users
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- 4. CREATE HIGH-PERFORMANCE INDEXES
CREATE UNIQUE INDEX IF NOT EXISTS pairing_codes_code_idx ON public.pairing_codes (code);
CREATE INDEX IF NOT EXISTS pairing_codes_creator_id_idx ON public.pairing_codes (creator_id);

-- 5. ATOMIC JOIN COUPLE RPC FUNCTION
CREATE OR REPLACE FUNCTION public.join_couple_with_code(pairing_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with elevated privileges to update creator profile and delete code
AS $$
DECLARE
  v_creator_id uuid;
  v_creator_couple_id uuid;
  v_joiner_id uuid;
  v_created_at timestamptz;
BEGIN
  -- Get active transaction user ID (joiner)
  v_joiner_id := auth.uid();
  IF v_joiner_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- Retrieve and lock pairing code row to prevent race conditions
  SELECT creator_id, created_at
  INTO v_creator_id, v_created_at
  FROM public.pairing_codes
  WHERE code = upper(trim(pairing_code))
  FOR UPDATE; -- Row-level lock

  IF v_creator_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Invalid pairing code');
  END IF;

  -- Prevent self-pairing
  IF v_creator_id = v_joiner_id THEN
    RETURN json_build_object('success', false, 'error', 'Cannot pair with yourself');
  END IF;

  -- Enforce 24-hour expiration on pairing codes
  IF v_created_at < now() - interval '24 hours' THEN
    DELETE FROM public.pairing_codes WHERE code = upper(trim(pairing_code));
    RETURN json_build_object('success', false, 'error', 'Pairing code has expired');
  END IF;

  -- Fetch the creator's couple_id
  SELECT couple_id
  INTO v_creator_couple_id
  FROM public.users
  WHERE id = v_creator_id;

  -- If creator doesn't have a couple_id yet, generate and assign one
  IF v_creator_couple_id IS NULL THEN
    v_creator_couple_id := gen_random_uuid();
    INSERT INTO public.couples (id, story_title)
    VALUES (v_creator_couple_id, 'Our Story');

    UPDATE public.users
    SET couple_id = v_creator_couple_id
    WHERE id = v_creator_id;
  END IF;

  -- Transaction: link both users
  UPDATE public.users
  SET partner_id = v_joiner_id, couple_id = v_creator_couple_id
  WHERE id = v_creator_id;

  UPDATE public.users
  SET partner_id = v_creator_id, couple_id = v_creator_couple_id
  WHERE id = v_joiner_id;

  -- Delete the used code
  DELETE FROM public.pairing_codes WHERE code = upper(trim(pairing_code));

  RETURN json_build_object(
    'success', true,
    'couple_id', v_creator_couple_id,
    'partner_id', v_creator_id
  );
END;
$$;
