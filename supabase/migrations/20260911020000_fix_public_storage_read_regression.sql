-- Migration: Remove the public storage read policy reintroduced by
--            20260911010000, and finish re-scoping the authenticated read.
-- Created: 2026-09-11
--
-- *** SECURITY FIX ***
--
-- 20260911010000_drop_secret_vault.sql re-created the four shared storage
-- policies in order to drop `vault-photos` from their bucket lists. It took
-- their definitions from 20260702000003 (original) and 20260713000001
-- (write-path hardening) -- but 20260712000001, under the heading "Storage
-- objects read policies (security validation)", had already replaced the
-- *read* policy:
--
--     DROP POLICY "Allow public read from love-notes, timeline, vault"
--     CREATE POLICY "Allow authenticated read from love-notes, timeline, vault"
--       FOR SELECT TO authenticated
--       USING (bucket_id IN (...) AND foldername(name)[2] = <caller couple_id>)
--
-- 20260713000001 only re-created the three write policies, so nothing since
-- has recreated a public read. 20260911010000's DROP of the public policy was
-- therefore a no-op against a policy that no longer existed, and its CREATE
-- reintroduced exactly the permissiveness 20260712000001 had removed.
--
-- Because RLS policies OR together, the result was that any caller -- `anon`
-- included -- could SELECT every couple's objects in `love-notes` and
-- `timeline`. The objects are AES-GCM ciphertext (see
-- EncryptedStorageService), so the bytes are not directly viewable, but the
-- access itself is unauthorized and object paths embed the couple id.
--
-- Two corrections here:
--   1. Drop the reintroduced public read policy outright. Nothing recreates
--      it; the authenticated policy below is the only read path.
--   2. Re-scope the surviving authenticated read policy to drop
--      `vault-photos`, which 20260911010000 set out to do for all four
--      policies but missed for this one -- it was editing the wrong policy
--      name, so the live read policy still lists a bucket whose objects and
--      table are gone.
--
-- Safe for the client: the app never uses public object URLs. Both read paths
-- in StorageUrlService go through `createSignedUrl`/`createSignedUrlsResult`,
-- which sign on behalf of the authenticated caller and so are permitted by
-- the couple-scoped policy below. This is the same change 20260820000001 made
-- for the `avatars` bucket, for the same reason.
--
-- ROLLBACK (restores the vulnerable state -- for reference only, do not run)
--   CREATE POLICY "Allow public read from love-notes, timeline, vault"
--     ON storage.objects FOR SELECT TO public
--     USING (bucket_id IN ('love-notes', 'timeline'));

-- 1. The reintroduced public read. Gone for good.
DROP POLICY IF EXISTS "Allow public read from love-notes, timeline, vault" ON storage.objects;

-- 2. The real read path, finally without vault-photos.
--    Path convention across every bucket is couples/{coupleId}/{feature}/{file},
--    so storage.foldername(name)[2] is always the coupleId. Both partners
--    share a coupleId, so each can still read the other's objects.
DROP POLICY IF EXISTS "Allow authenticated read from love-notes, timeline, vault" ON storage.objects;

CREATE POLICY "Allow authenticated read from love-notes, timeline, vault" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id IN ('love-notes', 'timeline')
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );
