-- Migration: Refactor Users, Couples, and License Tables for Slot-Based Identity
-- Created: 2026-07-12

-- 1. Add profile columns to public.users table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS gender text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS birthdate timestamptz;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS address text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS nationality text DEFAULT 'Love Land'::text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS weight text DEFAULT '—'::text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS height text DEFAULT '—'::text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS blood_type text DEFAULT '—'::text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS eye_color text DEFAULT '—'::text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS conditions text DEFAULT 'Madly in Love'::text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS date_issued timestamptz;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS signature text;

-- 2. Add email slots to couples table
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS partner_a_email text;
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS partner_b_email text;

-- 3. Add slot tracking to shared history tables and update FKs to ON DELETE SET NULL
ALTER TABLE public.love_notes DROP CONSTRAINT IF EXISTS love_notes_sender_id_fkey;
ALTER TABLE public.love_notes ADD COLUMN IF NOT EXISTS sender_slot text; -- 'partner_a' | 'partner_b'
ALTER TABLE public.love_notes ADD CONSTRAINT love_notes_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.moods DROP CONSTRAINT IF EXISTS moods_user_id_fkey;
ALTER TABLE public.moods ADD COLUMN IF NOT EXISTS user_slot text; -- 'partner_a' | 'partner_b'
ALTER TABLE public.moods ADD CONSTRAINT moods_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- 4. Clean up license_details table (metadata only)
DROP INDEX IF EXISTS public.license_details_creator_id_idx;
ALTER TABLE public.license_details DROP COLUMN IF EXISTS creator_id;

-- 5. RLS Policies Hardening
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable select for authenticated users" ON public.users;
CREATE POLICY "Enable select for authenticated users" ON public.users 
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Enable insert for own profile" ON public.users;
CREATE POLICY "Enable insert for own profile" ON public.users 
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Enable update for own profile" ON public.users;
CREATE POLICY "Enable update for own profile" ON public.users 
  FOR UPDATE TO authenticated 
  USING (
    auth.uid() = id 
    OR 
    (couple_id IS NOT NULL AND couple_id = (SELECT u.couple_id FROM public.users u WHERE u.id = auth.uid()))
  );

DROP POLICY IF EXISTS "Enable delete for own profile" ON public.users;
CREATE POLICY "Enable delete for own profile" ON public.users 
  FOR DELETE TO authenticated USING (auth.uid() = id);

DROP POLICY IF EXISTS "Enable update for own profile or pairing partner" ON public.users;

-- couples table policies
ALTER TABLE public.couples ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable select for couple members" ON public.couples;
CREATE POLICY "Enable select for couple members" ON public.couples 
  FOR SELECT TO authenticated USING (auth.uid() = partner_a_id OR auth.uid() = partner_b_id);

DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.couples;
CREATE POLICY "Enable insert for authenticated users" ON public.couples 
  FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Enable update for couple members" ON public.couples;
CREATE POLICY "Enable update for couple members" ON public.couples 
  FOR UPDATE TO authenticated USING (auth.uid() = partner_a_id OR auth.uid() = partner_b_id)
  WITH CHECK (auth.uid() = partner_a_id OR auth.uid() = partner_b_id);

-- license_details table policies
ALTER TABLE public.license_details ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable select for couple members" ON public.license_details;
CREATE POLICY "Enable select for couple members" ON public.license_details 
  FOR SELECT TO authenticated 
  USING (EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.couple_id = license_details.couple_id));

DROP POLICY IF EXISTS "Enable insert for couple members" ON public.license_details;
CREATE POLICY "Enable insert for couple members" ON public.license_details 
  FOR INSERT TO authenticated 
  WITH CHECK (EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.couple_id = license_details.couple_id));

DROP POLICY IF EXISTS "Enable update for couple members" ON public.license_details;
CREATE POLICY "Enable update for couple members" ON public.license_details 
  FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.couple_id = license_details.couple_id));

-- Storage objects read policies (security validation)
DROP POLICY IF EXISTS "Allow public read from love-notes, timeline, vault" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated read from love-notes, timeline, vault" ON storage.objects;
CREATE POLICY "Allow authenticated read from love-notes, timeline, vault" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id IN ('love-notes', 'timeline', 'vault-photos')
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );

-- 6. Re-create RPC Functions
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
  v_secret_clean text;
  v_secret_formatted text;
  v_user_email text;
  chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  i integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND couple_id IS NOT NULL) THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  v_couple_id := gen_random_uuid();

  LOOP
    v_pairing_code := '';
    v_lookup_key := '';
    FOR i IN 1..6 LOOP
      v_pairing_code := v_pairing_code || substr(chars, floor(random() * 36)::integer + 1, 1);
      v_lookup_key := v_lookup_key || substr(chars, floor(random() * 36)::integer + 1, 1);
    END LOOP;
    
    IF NOT EXISTS(SELECT 1 FROM public.couples WHERE pairing_code = v_pairing_code) AND
       NOT EXISTS(SELECT 1 FROM public.couples WHERE recovery_lookup_key = v_lookup_key) THEN
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

  SELECT email INTO v_user_email FROM auth.users WHERE id = auth.uid();

  INSERT INTO public.couples (id, status, partner_a_id, partner_a_email, pairing_code, recovery_lookup_key, recovery_code_hash)
  VALUES (v_couple_id, 'waiting', auth.uid(), v_user_email, v_pairing_code, v_lookup_key, crypt(v_secret_clean, gen_salt('bf', 10)));

  UPDATE public.users SET couple_id = v_couple_id WHERE id = auth.uid();

  INSERT INTO public.license_details (couple_id, certificate_number)
  VALUES (v_couple_id, 'DT-' || to_char(now(), 'YYYYMMDD') || '-' || substr(v_couple_id::text, 1, 4));

  RETURN json_build_object(
    'success', true,
    'couple_id', v_couple_id,
    'pairing_code', v_pairing_code,
    'recovery_code', v_lookup_key || '-' || v_secret_formatted
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.join_relationship_with_code(p_pairing_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_couple_row public.couples%ROWTYPE;
  v_user_email text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND couple_id IS NOT NULL) THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

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

  SELECT email INTO v_user_email FROM auth.users WHERE id = auth.uid();

  UPDATE public.couples
  SET partner_b_id = auth.uid(), partner_b_email = v_user_email, status = 'active', pairing_code = NULL
  WHERE id = v_couple_row.id;

  UPDATE public.users SET couple_id = v_couple_row.id WHERE id = auth.uid();

  RETURN json_build_object('success', true, 'couple_id', v_couple_row.id);
END;
$$;

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
      IF v_couple_row.recovery_code_hash = crypt(v_secret_clean, v_couple_row.recovery_code_hash) THEN
        v_success := true;
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
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

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
