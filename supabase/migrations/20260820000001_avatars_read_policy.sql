-- Migration: Scope avatar reads to the owning couple (SEC-1, part 1 of 2)
-- Created: 2026-08-20
--
-- CONTEXT
-- The other three buckets were moved to authenticated + couple-scoped reads in
-- 20260712000001_refactor_users_profiles.sql. The `avatars` bucket was missed:
-- it still carries the original "Allow public read from avatars" policy, which
-- is FOR SELECT TO public with no couple scoping at all.
--
-- This migration is SAFE TO APPLY IMMEDIATELY. While storage.buckets.public is
-- still true, object reads go through the /object/public/ route, which bypasses
-- storage.objects RLS entirely -- so changing these policies cannot break the
-- running app. What it does do is make createSignedUrl() correctly scoped once
-- the client starts using it.
--
-- THIS MIGRATION DOES NOT CLOSE SEC-1 ON ITS OWN.
-- The buckets remain publicly readable via the /object/public/ route until
-- `public` is flipped to false -- see supabase/manual/README.md, which must not
-- be run until the signed-URL client build has shipped.
--
-- ROLLBACK
--   DROP POLICY IF EXISTS "Allow authenticated read from avatars" ON storage.objects;
--   CREATE POLICY "Allow public read from avatars" ON storage.objects
--     FOR SELECT TO public USING (bucket_id = 'avatars');

-- Path convention across every bucket is couples/{coupleId}/{feature}/{file},
-- so storage.foldername(name)[2] is always the coupleId. Both partners share a
-- coupleId, so each can still read the other's avatar.
DROP POLICY IF EXISTS "Allow public read from avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated read from avatars" ON storage.objects;

CREATE POLICY "Allow authenticated read from avatars" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );
