-- STEP 5 of supabase/manual/README.md — THIS is the step that closes SEC-1.
--
-- DO NOT RUN until steps 2-4 are complete. Flipping `public` to false takes the
-- /storage/v1/object/public/ route offline; any client that has not been
-- upgraded to mint signed URLs will show no images at all.
--
-- PRE-FLIGHT: the SELECT policies below must already exist, otherwise
-- createSignedUrl() returns 400 and every image in the app disappears.
-- Run the first query and confirm you get two rows before running the UPDATE.

-- ---------------------------------------------------------------------------
-- PRE-FLIGHT CHECK — expect exactly these two SELECT policies on storage.objects:
--   "Allow authenticated read from love-notes, timeline, vault"
--   "Allow authenticated read from avatars"   (added by 20260820000001)
-- ---------------------------------------------------------------------------
SELECT policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename  = 'objects'
  AND cmd = 'SELECT'
ORDER BY policyname;

-- ---------------------------------------------------------------------------
-- THE FLIP
-- ---------------------------------------------------------------------------
UPDATE storage.buckets
SET public = false
WHERE id IN ('avatars', 'love-notes', 'timeline', 'vault-photos');

-- ---------------------------------------------------------------------------
-- VERIFY — all four rows must show public = false.
-- ---------------------------------------------------------------------------
SELECT id, name, public, file_size_limit
FROM storage.buckets
WHERE id IN ('avatars', 'love-notes', 'timeline', 'vault-photos')
ORDER BY id;

-- ---------------------------------------------------------------------------
-- THEN verify from OUTSIDE the database (this is the actual SEC-1 proof).
-- Pick any real object path and curl its public URL -- it must now fail:
--
--   curl -s -o /dev/null -w '%{http_code}\n' \
--     'https://<project>.supabase.co/storage/v1/object/public/vault-photos/couples/<coupleId>/vault_photos/<id>.jpg'
--
-- Expected: 400 (or 404). Before this migration it returned 200 with the image.
--
-- Then confirm in-app that a signed URL for that same object works for BOTH
-- partners, and that a third, unrelated account cannot sign it.
-- ---------------------------------------------------------------------------
