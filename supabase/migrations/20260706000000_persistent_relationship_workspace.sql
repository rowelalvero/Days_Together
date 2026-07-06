-- Migration: Implement Persistent Relationship Workspace Schema and secure transaction-safe RPCs
-- Created: 2026-07-06

-- Enable pgcrypto if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Create failed_recovery_attempts table for rate limiting/cooldown
CREATE TABLE IF NOT EXISTS public.failed_recovery_attempts (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  attempts integer DEFAULT 0 NOT NULL,
  locked_until timestamp with time zone,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Enable RLS on rate limit table
ALTER TABLE public.failed_recovery_attempts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable select/update for own attempts" ON public.failed_recovery_attempts;
CREATE POLICY "Enable select/update for own attempts" ON public.failed_recovery_attempts
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 2. Alter couples table to support workspace state
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS status text DEFAULT 'waiting' NOT NULL;
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS partner_a_id uuid REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS partner_b_id uuid REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS pairing_code character varying(6) UNIQUE;
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS recovery_lookup_key text UNIQUE;
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS recovery_code_hash text;
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();

CREATE UNIQUE INDEX IF NOT EXISTS couples_recovery_lookup_key_idx ON public.couples (recovery_lookup_key);

-- 3. Populate existing couples from users table
DO $$
DECLARE
  r record;
  v_partner_a uuid;
  v_partner_b uuid;
BEGIN
  FOR r IN SELECT DISTINCT couple_id FROM public.users WHERE couple_id IS NOT NULL LOOP
    SELECT id INTO v_partner_a FROM public.users WHERE couple_id = r.couple_id ORDER BY id ASC LIMIT 1;
    SELECT id INTO v_partner_b FROM public.users WHERE couple_id = r.couple_id ORDER BY id ASC LIMIT 1 OFFSET 1;

    UPDATE public.couples
    SET 
      partner_a_id = v_partner_a,
      partner_b_id = v_partner_b,
      status = CASE WHEN v_partner_b IS NOT NULL THEN 'active' ELSE 'waiting' END
    WHERE id = r.couple_id;
  END LOOP;
END;
$$;

-- 4. Clean up users table
ALTER TABLE public.users DROP COLUMN IF EXISTS partner_id;

-- 5. Drop old pairing_codes table
DROP TABLE IF EXISTS public.pairing_codes CASCADE;

-- 6. Redefine is_member_of_couple to verify workspace and active status
CREATE OR REPLACE FUNCTION public.is_member_of_couple(couple_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
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

-- 7. Trigger function to automatically update updated_at on couples
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_couples_updated_at ON public.couples;
CREATE TRIGGER update_couples_updated_at
  BEFORE UPDATE ON public.couples
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- 8. Define create_relationship_workspace RPC
CREATE OR REPLACE FUNCTION public.create_relationship_workspace()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
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

  -- Insert couple row with Blowfish hash of the clean secret
  INSERT INTO public.couples (id, status, partner_a_id, pairing_code, recovery_lookup_key, recovery_code_hash)
  VALUES (
    v_couple_id,
    'waiting',
    auth.uid(),
    v_pairing_code,
    v_lookup_key,
    crypt(v_secret_clean, gen_salt('bf', 10))
  );

  -- Update user couple_id
  UPDATE public.users SET couple_id = v_couple_id WHERE id = auth.uid();

  RETURN json_build_object(
    'success', true,
    'couple_id', v_couple_id,
    'pairing_code', v_pairing_code,
    'recovery_code', v_lookup_key || '-' || v_secret_formatted
  );
END;
$$;

-- 9. Define join_relationship_with_code RPC
CREATE OR REPLACE FUNCTION public.join_relationship_with_code(p_pairing_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
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

  -- Find and lock couples row
  SELECT * INTO v_couple_row
  FROM public.couples
  WHERE upper(pairing_code) = upper(trim(p_pairing_code))
    AND status = 'waiting'
    AND partner_b_id IS NULL
  FOR UPDATE;

  IF v_couple_row.id IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired pairing code';
  END IF;

  IF v_couple_row.partner_a_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot pair with yourself';
  END IF;

  -- Update couple record
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

-- 10. Define recover_relationship_with_code RPC
CREATE OR REPLACE FUNCTION public.recover_relationship_with_code(p_recovery_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_lookup_key text;
  v_secret text;
  v_secret_clean text;
  v_couple_id uuid;
  v_couple_row record;
  v_attempts integer;
  v_locked_until timestamp with time zone;
  v_user_couple_id uuid;
BEGIN
  -- Lock user row to prevent race conditions
  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  -- Check rate limiting
  SELECT attempts, locked_until INTO v_attempts, v_locked_until
  FROM public.failed_recovery_attempts
  WHERE user_id = auth.uid()
  FOR UPDATE;

  IF v_locked_until IS NOT NULL AND v_locked_until > now() THEN
    RAISE EXCEPTION 'Too many failed attempts. Try again after %', v_locked_until;
  END IF;

  -- Parse lookup key and secret
  IF position('-' in p_recovery_code) = 0 THEN
    GOTO failed_attempt;
  END IF;

  v_lookup_key := upper(trim(split_part(p_recovery_code, '-', 1)));
  v_secret := substr(p_recovery_code, position('-' in p_recovery_code) + 1);
  v_secret_clean := replace(v_secret, '-', '');

  -- Query couples using index on lookup key and lock it
  SELECT * INTO v_couple_row
  FROM public.couples
  WHERE recovery_lookup_key = v_lookup_key
  FOR UPDATE;

  IF v_couple_row.id IS NULL THEN
    GOTO failed_attempt;
  END IF;

  -- Verify BCrypt hash
  IF v_couple_row.recovery_code_hash != crypt(v_secret_clean, v_couple_row.recovery_code_hash) THEN
    GOTO failed_attempt;
  END IF;

  -- Validate ownership
  IF v_couple_row.partner_a_id != auth.uid() AND v_couple_row.partner_b_id != auth.uid() THEN
    GOTO failed_attempt;
  END IF;

  -- Success: Reset attempts, connect user, update workspace status
  INSERT INTO public.failed_recovery_attempts (user_id, attempts, locked_until)
  VALUES (auth.uid(), 0, NULL)
  ON CONFLICT (user_id) DO UPDATE SET attempts = 0, locked_until = NULL;

  UPDATE public.users SET couple_id = v_couple_row.id WHERE id = auth.uid();
  UPDATE public.couples SET status = 'active' WHERE id = v_couple_row.id;

  RETURN json_build_object(
    'success', true,
    'couple_id', v_couple_row.id
  );

<<failed_attempt>>
BEGIN
  INSERT INTO public.failed_recovery_attempts (user_id, attempts, locked_until)
  VALUES (auth.uid(), 1, NULL)
  ON CONFLICT (user_id) DO UPDATE SET
    attempts = failed_recovery_attempts.attempts + 1,
    locked_until = CASE WHEN failed_recovery_attempts.attempts + 1 >= 5 THEN now() + interval '15 minutes' ELSE NULL END,
    updated_at = now();
    
  RAISE EXCEPTION 'Invalid recovery code';
END;
END;
$$;

-- 11. Define regenerate_recovery_code RPC
CREATE OR REPLACE FUNCTION public.regenerate_recovery_code()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
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
  -- Lock user row
  SELECT couple_id INTO v_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_couple_id IS NULL THEN
    RAISE EXCEPTION 'Not in a relationship';
  END IF;

  -- Lock couples row
  IF NOT EXISTS (
    SELECT 1 FROM public.couples WHERE id = v_couple_id AND (partner_a_id = auth.uid() OR partner_b_id = auth.uid()) FOR UPDATE
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- Generate lookup key in retry loop
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

  -- Generate 16-char secret key
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

-- 12. Define disconnect_relationship_workspace RPC
CREATE OR REPLACE FUNCTION public.disconnect_relationship_workspace()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_couple_id uuid;
  v_other_connected boolean;
BEGIN
  -- Lock caller user row
  SELECT couple_id INTO v_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_couple_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not in a relationship');
  END IF;

  -- Lock couple row
  PERFORM 1 FROM public.couples WHERE id = v_couple_id FOR UPDATE;

  -- Update user to null
  UPDATE public.users SET couple_id = NULL WHERE id = auth.uid();

  -- Check if other partner is still connected
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
