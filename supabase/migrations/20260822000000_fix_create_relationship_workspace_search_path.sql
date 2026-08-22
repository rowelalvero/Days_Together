-- Migration: Fix create_relationship_workspace's missing `extensions` schema
-- Created: 2026-08-22
--
-- Bug: 20260808000003_pairing_code_rotation.sql redefined
-- create_relationship_workspace() (to add the pairing_code_updated_at
-- timestamp) but its SET search_path only listed `public, auth`, dropping
-- `extensions` -- the schema pgcrypto's gen_salt()/crypt() actually live in
-- (see 20260621000000_remote_schema.sql's
-- `CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions"`).
-- Every prior version of this function (20260707000001_security_hardening
-- .sql, 20260711000000_audit_fixes.sql, 20260712000001_refactor_users_
-- profiles.sql) correctly included `extensions`. Without it, Postgres can't
-- resolve gen_salt(), failing every call to this RPC with:
--   PostgrestException(message: function gen_salt(unknown, integer) does
--   not exist, code: 42883, ...)
--
-- Fix: re-create the function with the exact same body as
-- 20260808000003_pairing_code_rotation.sql, only restoring `extensions` to
-- the search_path.

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
