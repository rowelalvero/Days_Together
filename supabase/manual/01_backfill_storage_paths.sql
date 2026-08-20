-- STEP 4 of supabase/manual/README.md — backfill stored public URLs to bare paths.
--
-- DO NOT RUN until the signed-URL client build has shipped and been adopted.
-- Clients older than that build read these columns verbatim as URLs and will
-- show broken images everywhere once this runs.
--
-- Converts e.g.
--   https://abc.supabase.co/storage/v1/object/public/vault-photos/couples/<id>/vault_photos/<x>.jpg?t=1
-- into
--   couples/<id>/vault_photos/<x>.jpg
--
-- Idempotent: the WHERE clauses only match rows that still look like storage
-- URLs, so re-running is a no-op.

BEGIN;

-- ---------------------------------------------------------------------------
-- Snapshots. Keep these until step 5 is verified, then drop them.
-- Rollback is: UPDATE <table> t SET <col> = b.<col> FROM _bk_<table> b WHERE t.id = b.id;
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public._bk_vault_items    AS SELECT id, image_url          FROM public.vault_items;
CREATE TABLE IF NOT EXISTS public._bk_timeline_items AS SELECT id, network_image_url  FROM public.timeline_items;
CREATE TABLE IF NOT EXISTS public._bk_love_notes     AS SELECT id, image_url          FROM public.love_notes;
CREATE TABLE IF NOT EXISTS public._bk_users          AS SELECT id, avatar_url         FROM public.users;

-- ---------------------------------------------------------------------------
-- Backfill. One statement per column; the bucket name is baked into each regex
-- so a URL belonging to a different bucket is never rewritten into the wrong one.
-- split_part(..., '?', 1) strips the legacy `?t=` cache-buster.
-- ---------------------------------------------------------------------------
UPDATE public.vault_items
SET image_url = regexp_replace(
      split_part(image_url, '?', 1),
      '^https?://[^/]+/storage/v1/object/(public|sign|authenticated)/vault-photos/', '')
WHERE image_url LIKE 'http%/storage/v1/object/%/vault-photos/%';

UPDATE public.timeline_items
SET network_image_url = regexp_replace(
      split_part(network_image_url, '?', 1),
      '^https?://[^/]+/storage/v1/object/(public|sign|authenticated)/timeline/', '')
WHERE network_image_url LIKE 'http%/storage/v1/object/%/timeline/%';

UPDATE public.love_notes
SET image_url = regexp_replace(
      split_part(image_url, '?', 1),
      '^https?://[^/]+/storage/v1/object/(public|sign|authenticated)/love-notes/', '')
WHERE image_url LIKE 'http%/storage/v1/object/%/love-notes/%';

-- users.avatar_url: the WHERE clause is load-bearing. Some rows hold Google
-- OAuth avatar URLs (lh3.googleusercontent.com) that are NOT storage objects
-- and must be left completely untouched -- they are passed through as-is by the
-- client. Matching on the /storage/v1/object/ marker excludes them.
UPDATE public.users
SET avatar_url = regexp_replace(
      split_part(avatar_url, '?', 1),
      '^https?://[^/]+/storage/v1/object/(public|sign|authenticated)/avatars/', '')
WHERE avatar_url LIKE 'http%/storage/v1/object/%/avatars/%';

COMMIT;

-- ---------------------------------------------------------------------------
-- VERIFY. Every count below must be 0 (no storage URLs left behind).
-- ---------------------------------------------------------------------------
SELECT 'vault_items'    AS t, count(*) AS remaining_urls FROM public.vault_items    WHERE image_url         LIKE 'http%/storage/v1/object/%'
UNION ALL
SELECT 'timeline_items',      count(*)                   FROM public.timeline_items WHERE network_image_url LIKE 'http%/storage/v1/object/%'
UNION ALL
SELECT 'love_notes',          count(*)                   FROM public.love_notes     WHERE image_url         LIKE 'http%/storage/v1/object/%'
UNION ALL
SELECT 'users',               count(*)                   FROM public.users          WHERE avatar_url        LIKE 'http%/storage/v1/object/%';

-- Sanity check: external (Google OAuth) avatars must have survived untouched.
-- Expect these rows to still start with http and NOT contain /storage/v1/.
SELECT id, avatar_url
FROM public.users
WHERE avatar_url LIKE 'http%'
LIMIT 20;
