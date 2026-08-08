-- Migration: Secure Storage Buckets Write Policies
-- Created: 2026-07-13
-- Addresses: Audit issue 7.3, 7.4 (Broken Object Level Authorization on Storage)

-- 1. Drop legacy/permissive write policies on love-notes, timeline, vault-photos
DROP POLICY IF EXISTS "Allow authenticated uploads to love-notes, timeline, vault" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated updates to love-notes, timeline, vault" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes from love-notes, timeline, vault" ON storage.objects;

-- 2. Create secured write policies for love-notes, timeline, vault-photos
CREATE POLICY "Allow authenticated uploads to love-notes, timeline, vault" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id IN ('love-notes', 'timeline', 'vault-photos')
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );

CREATE POLICY "Allow authenticated updates to love-notes, timeline, vault" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id IN ('love-notes', 'timeline', 'vault-photos')
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );

CREATE POLICY "Allow authenticated deletes from love-notes, timeline, vault" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id IN ('love-notes', 'timeline', 'vault-photos')
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );

-- 3. Drop legacy/permissive write policies for avatars
DROP POLICY IF EXISTS "Allow authenticated uploads to avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated updates to avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes from avatars" ON storage.objects;

-- 4. Create secured write policies for avatars
CREATE POLICY "Allow authenticated uploads to avatars" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );

CREATE POLICY "Allow authenticated updates to avatars" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );

CREATE POLICY "Allow authenticated deletes from avatars" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );
