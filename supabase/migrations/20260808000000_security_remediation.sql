-- Migration: Security Remediation (C-2, C-4, H-2)
-- Created: 2026-08-08

-- ============================================================
-- 1. Fix Users SELECT RLS Policy (Audit C-4)
-- Restrict SELECT to own profile or partner profile in same couple
-- ============================================================
DROP POLICY IF EXISTS "Enable select for authenticated users" ON public.users;
DROP POLICY IF EXISTS "Enable select for self and partner" ON public.users;

CREATE POLICY "Enable select for self and partner" ON public.users
  FOR SELECT TO authenticated
  USING (
    auth.uid() = id
    OR
    (couple_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.couples c
      WHERE c.id = public.users.couple_id
        AND (c.partner_a_id = auth.uid() OR c.partner_b_id = auth.uid())
    ))
  );

-- ============================================================
-- 2. Fix Users UPDATE RLS Policy (Audit C-2)
-- Restrict direct UPDATE strictly to own profile. Partner updates must use update_partner_profile RPC.
-- ============================================================
DROP POLICY IF EXISTS "Enable update for own profile" ON public.users;

CREATE POLICY "Enable update for own profile" ON public.users
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================================
-- 3. Dedicated RPC Function for Partner Profile Updates (Audit C-2)
-- Whitelists profile columns and verifies target is caller's partner in same workspace.
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_partner_profile(
  p_target_user_id uuid,
  p_updates jsonb
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_caller_couple_id uuid;
  v_target_couple_id uuid;
  v_allowed_keys text[] := ARRAY[
    'display_name', 'gender', 'phone', 'birthdate', 'address',
    'nationality', 'weight', 'height', 'blood_type', 'eye_color',
    'conditions', 'date_issued', 'signature', 'avatar_url'
  ];
  v_key text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF auth.uid() = p_target_user_id THEN
    RAISE EXCEPTION 'Use self-update for your own profile';
  END IF;

  -- Get caller's couple_id
  SELECT couple_id INTO v_caller_couple_id FROM public.users WHERE id = auth.uid();
  IF v_caller_couple_id IS NULL THEN
    RAISE EXCEPTION 'Caller is not in a relationship workspace';
  END IF;

  -- Verify target is caller's partner in the same couple workspace
  SELECT couple_id INTO v_target_couple_id FROM public.users WHERE id = p_target_user_id;
  IF v_target_couple_id IS NULL OR v_target_couple_id != v_caller_couple_id THEN
    RAISE EXCEPTION 'Target user is not your partner in this relationship';
  END IF;

  -- Validate all keys in p_updates are whitelisted
  FOR v_key IN SELECT jsonb_object_keys(p_updates) LOOP
    IF NOT (v_key = ANY(v_allowed_keys)) THEN
      RAISE EXCEPTION 'Modification of column "%" is prohibited for partner updates', v_key;
    END IF;
  END LOOP;

  -- Perform safe update
  UPDATE public.users
  SET
    display_name = CASE WHEN p_updates ? 'display_name' THEN p_updates->>'display_name' ELSE display_name END,
    gender       = CASE WHEN p_updates ? 'gender' THEN p_updates->>'gender' ELSE gender END,
    phone        = CASE WHEN p_updates ? 'phone' THEN p_updates->>'phone' ELSE phone END,
    birthdate    = CASE WHEN p_updates ? 'birthdate' THEN (p_updates->>'birthdate')::timestamptz ELSE birthdate END,
    address      = CASE WHEN p_updates ? 'address' THEN p_updates->>'address' ELSE address END,
    nationality  = CASE WHEN p_updates ? 'nationality' THEN p_updates->>'nationality' ELSE nationality END,
    weight       = CASE WHEN p_updates ? 'weight' THEN p_updates->>'weight' ELSE weight END,
    height       = CASE WHEN p_updates ? 'height' THEN p_updates->>'height' ELSE height END,
    blood_type   = CASE WHEN p_updates ? 'blood_type' THEN p_updates->>'blood_type' ELSE blood_type END,
    eye_color    = CASE WHEN p_updates ? 'eye_color' THEN p_updates->>'eye_color' ELSE eye_color END,
    conditions   = CASE WHEN p_updates ? 'conditions' THEN p_updates->>'conditions' ELSE conditions END,
    date_issued  = CASE WHEN p_updates ? 'date_issued' THEN (p_updates->>'date_issued')::timestamptz ELSE date_issued END,
    signature    = CASE WHEN p_updates ? 'signature' THEN p_updates->>'signature' ELSE signature END,
    avatar_url   = CASE WHEN p_updates ? 'avatar_url' THEN p_updates->>'avatar_url' ELSE avatar_url END
  WHERE id = p_target_user_id;

  RETURN json_build_object('success', true);
END;
$$;

-- ============================================================
-- 4. Restrict Couples INSERT RLS Policy (Audit H-2)
-- Deny direct inserts into public.couples table. Workspaces must be created via RPC.
-- ============================================================
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.couples;

CREATE POLICY "Deny direct insert on couples" ON public.couples
  FOR INSERT TO authenticated
  WITH CHECK (false);
