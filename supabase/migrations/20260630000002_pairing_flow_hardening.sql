-- Migration: Harden pairing flow, enforce unique active code per creator, and validate relationship statuses
-- Created: 2026-06-30

-- 1. ENFORCE ONE ACTIVE CODE PER USER
-- Try to drop existing constraint if it exists
ALTER TABLE public.pairing_codes DROP CONSTRAINT IF EXISTS pairing_codes_creator_id_key;
ALTER TABLE public.pairing_codes ADD CONSTRAINT pairing_codes_creator_id_key UNIQUE (creator_id);

-- 2. HARDEN JOIN RELATIONSHIP RPC
CREATE OR REPLACE FUNCTION public.join_couple_with_code(pairing_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
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

  -- Retrieve and lock pairing code row to prevent race conditions (FOR UPDATE)
  SELECT creator_id, created_at
  INTO v_creator_id, v_created_at
  FROM public.pairing_codes
  WHERE code = upper(trim(pairing_code))
  FOR UPDATE;

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

  -- Check if joiner is already paired (to prevent hijacking/breaking existing relationship)
  IF EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = v_joiner_id AND partner_id IS NOT NULL
  ) THEN
    RETURN json_build_object('success', false, 'error', 'You are already paired in a relationship');
  END IF;

  -- Check if creator is already paired
  IF EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = v_creator_id AND partner_id IS NOT NULL
  ) THEN
    RETURN json_build_object('success', false, 'error', 'The creator of this code is already paired');
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
