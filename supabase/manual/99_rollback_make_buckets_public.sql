-- EMERGENCY ROLLBACK for 02_make_buckets_private.sql.
--
-- ⚠️  RUNNING THIS RE-OPENS SEC-1. Every object in these buckets -- including
-- private Vault photos -- becomes anonymously readable again by anyone with the
-- object URL. Use it only to restore service while diagnosing, then fix forward
-- and re-apply 02 as soon as possible.
--
-- Note this does NOT undo the backfill (01). It does not need to: the
-- signed-URL client reads bare paths and legacy URLs alike, and a public bucket
-- still serves signed URLs correctly. If you must also revert the backfill,
-- restore from the snapshot tables:
--
--   UPDATE public.vault_items    t SET image_url         = b.image_url         FROM public._bk_vault_items    b WHERE t.id = b.id;
--   UPDATE public.timeline_items t SET network_image_url = b.network_image_url FROM public._bk_timeline_items b WHERE t.id = b.id;
--   UPDATE public.love_notes     t SET image_url         = b.image_url         FROM public._bk_love_notes     b WHERE t.id = b.id;
--   UPDATE public.users          t SET avatar_url        = b.avatar_url        FROM public._bk_users          b WHERE t.id = b.id;

UPDATE storage.buckets
SET public = true
WHERE id IN ('avatars', 'love-notes', 'timeline', 'vault-photos');

SELECT id, name, public
FROM storage.buckets
WHERE id IN ('avatars', 'love-notes', 'timeline', 'vault-photos')
ORDER BY id;
