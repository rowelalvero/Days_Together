-- Migration: Robust Pairing Code Rotation & Expiration
-- Created: 2026-08-23

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
  WHERE id = (SELECT couple_id FROM public.users WHERE id = auth.uid())
     OR partner_a_id = auth.uid()
     OR partner_b_id = auth.uid()
  ORDER BY created_at DESC
  LIMIT 1
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
