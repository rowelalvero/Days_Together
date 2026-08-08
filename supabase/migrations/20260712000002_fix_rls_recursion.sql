-- Migration: Fix RLS Policy Infinite Recursion
-- Created: 2026-07-12

-- 1. Drop the redundant and recursive SELECT policy on users
DROP POLICY IF EXISTS "Enable select for self and partner" ON public.users;

-- 2. Drop and recreate the UPDATE policy on users to use couples table checks instead of self-referencing users table checks
DROP POLICY IF EXISTS "Enable update for own profile" ON public.users;
CREATE POLICY "Enable update for own profile" ON public.users 
  FOR UPDATE TO authenticated 
  USING (
    auth.uid() = id 
    OR 
    (couple_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.couples c 
      WHERE c.id = public.users.couple_id 
        AND (c.partner_a_id = auth.uid() OR c.partner_b_id = auth.uid())
    ))
  );

-- 3. Automatic user profile creation trigger on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, display_name, couple_id)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'name', 'New User'),
    NULL
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. Backfill public.users for any existing auth.users
INSERT INTO public.users (id, display_name)
SELECT 
  id, 
  COALESCE(raw_user_meta_data->>'display_name', raw_user_meta_data->>'name', 'New User')
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- 5. Add relationship metadata columns to license_details and clean up legacy profile fields
ALTER TABLE public.license_details ADD COLUMN IF NOT EXISTS certificate_number text;
ALTER TABLE public.license_details ADD COLUMN IF NOT EXISTS issue_date timestamptz DEFAULT now();
ALTER TABLE public.license_details ADD COLUMN IF NOT EXISTS anniversary timestamptz;
ALTER TABLE public.license_details ADD COLUMN IF NOT EXISTS theme text DEFAULT 'classic';
ALTER TABLE public.license_details ADD COLUMN IF NOT EXISTS relationship_title text DEFAULT 'Together Forever';

-- Clean up profile fields from license_details
ALTER TABLE public.license_details 
  DROP COLUMN IF EXISTS your_name,
  DROP COLUMN IF EXISTS partner_name,
  DROP COLUMN IF EXISTS your_gender,
  DROP COLUMN IF EXISTS partner_gender,
  DROP COLUMN IF EXISTS your_phone,
  DROP COLUMN IF EXISTS partner_phone,
  DROP COLUMN IF EXISTS your_birthdate,
  DROP COLUMN IF EXISTS partner_birthdate,
  DROP COLUMN IF EXISTS your_address,
  DROP COLUMN IF EXISTS partner_address,
  DROP COLUMN IF EXISTS your_nationality,
  DROP COLUMN IF EXISTS partner_nationality,
  DROP COLUMN IF EXISTS your_weight,
  DROP COLUMN IF EXISTS partner_weight,
  DROP COLUMN IF EXISTS your_height,
  DROP COLUMN IF EXISTS partner_height,
  DROP COLUMN IF EXISTS your_blood_type,
  DROP COLUMN IF EXISTS partner_blood_type,
  DROP COLUMN IF EXISTS your_eye_color,
  DROP COLUMN IF EXISTS partner_eye_color,
  DROP COLUMN IF EXISTS your_conditions,
  DROP COLUMN IF EXISTS partner_conditions,
  DROP COLUMN IF EXISTS your_date_issued,
  DROP COLUMN IF EXISTS partner_date_issued,
  DROP COLUMN IF EXISTS your_signature,
  DROP COLUMN IF EXISTS partner_signature,
  DROP COLUMN IF EXISTS your_avatar_path,
  DROP COLUMN IF EXISTS partner_avatar_path;


