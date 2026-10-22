-- Migration: Enforce private storage buckets (audit F-02 / invariant S14)
-- Created: 2026-10-03
--
-- PROBLEM
-- All four buckets were created public = true (20260702000003/4). Supabase
-- serves public buckets at /storage/v1/object/public/{bucket}/{path}, a route
-- that does NOT consult storage.objects RLS -- so the couple-scoped read
-- policies (20260712000001, 20260820000001, 20260911020000) were only a real
-- boundary for signed URLs. Anyone holding or guessing an object path (paths
-- embed the couple id, which is also sent in every FCM data payload) could
-- fetch any couple's objects anonymously. New uploads are AES-GCM ciphertext,
-- but photos uploaded before E2EE shipped are plaintext.
--
-- PREVIOUS BEHAVIOUR
-- Flipping the buckets private lived only in supabase/manual/
-- 02_make_buckets_private.sql, an undocumented-in-history manual step: nothing
-- recorded whether production ran it, and a fresh environment (or `supabase
-- db reset`) always came up public.
--
-- NEW INVARIANT
-- Every Days Together bucket is private; objects are reachable only through
-- RLS-checked paths (authenticated reads and createSignedUrl, both of which
-- require couple membership via storage.foldername(name)[2]).
--
-- WHY THIS IS SAFE
-- * The client no longer builds public URLs anywhere: StorageUrlService
--   resolves every stored ref -- bare path OR legacy public URL -- to a path
--   and mints a signed URL (lib/core/storage/storage_url_service.dart,
--   pathFrom/resolve). So legacy rows still holding full public URLs keep
--   rendering; the manual backfill step (01_backfill_storage_paths.sql) is a
--   tidy-up, not a prerequisite.
-- * The pre-flight below aborts the migration (and, since the CLI runs each
--   migration in a transaction, leaves the buckets untouched) if the
--   authenticated read policies that signing depends on are missing --
--   flipping without them would black out every image.
-- * No object is deleted or rewritten. `vault-photos` is included in case the
--   out-of-band bucket removal (20260911010000) has not happened yet; if the
--   bucket is gone the UPDATE simply matches nothing.
-- * Idempotent: a project where the manual step already ran is unaffected.
--
-- ROLLOUT NOTE
-- Clients older than the signed-URL build (pre-20260820) render no images
-- after this. See supabase/manual/README.md step 3.
--
-- REGRESSION TEST
-- supabase/tests/009_storage.sql ("no Days Together bucket is public", plus
-- object-level cross-couple read/write/unlink checks).

DO $$
DECLARE
  v_missing text[];
BEGIN
  SELECT array_agg(required)
  INTO v_missing
  FROM unnest(ARRAY[
    'Allow authenticated read from love-notes, timeline, vault',
    'Allow authenticated read from avatars'
  ]) AS required
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND cmd = 'SELECT' AND policyname = required
  );

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'Refusing to make buckets private: missing storage read policies %', v_missing;
  END IF;
END
$$;

UPDATE storage.buckets
SET public = false
WHERE id IN ('avatars', 'love-notes', 'timeline', 'vault-photos')
  AND public;
