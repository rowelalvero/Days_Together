-- Migration: Queue a deleted couple's / deleted user's stored photos for
--            removal (audit F-21)
-- Created: 2026-10-03
--
-- PROBLEM
-- Deleting a couple (its last member deletes their account, or the couple is
-- otherwise removed) cascades every feature row, but the encrypted photos in
-- the avatars / timeline / love-notes buckets stayed behind forever, under
-- couples/<couple_id>/. Likewise a deleted user's avatar stayed in a couple
-- the partner keeps. Postgres cannot remove them: Supabase blocks direct DML
-- on storage.objects (storage.protect_delete), because deleting the row
-- without the backing file orphans the file. Removal has to go through the
-- Storage API.
--
-- PREVIOUS VULNERABLE BEHAVIOR
-- public.storage_cleanup_queue existed (20260707000002) but nothing wrote to
-- it or read it. It also carried the default full table grants to anon and
-- authenticated; only "RLS enabled, no policy" kept clients out.
--
-- NEW INVARIANT (S16)
-- Whenever a couple row is deleted, every object under couples/<id>/ in the
-- three photo buckets is queued for removal; whenever a user row is deleted
-- while in a couple, that user's avatars (couples/<cid>/avatars/<uid>_*) are
-- queued. The queue is service-role only. The storage-cleanup edge function
-- drains it through the Storage API (supabase/functions/storage-cleanup).
--
-- WHY SAFE
-- * Entries are path PREFIXES matched with left(name, length(prefix)) =
--   prefix -- no LIKE, so '_' in "<uid>_" is literal, not a wildcard.
-- * Every couple-owned upload path starts with couples/<couple_id>/ (avatars,
--   timeline, note-its; see couple_session.dart, timeline_controller.dart,
--   noteit_sync_manager.dart); couple ids are uuids, so one couple's prefix
--   can never be a prefix of another's.
-- * A queue entry is removed only by storage_cleanup_settle(), and only once
--   no object under its prefix remains -- a partial or failed drain is
--   retried on the next run.
-- * Nothing here deletes data a remaining partner can still see: couple
--   prefixes are queued only when the couple row itself is gone; the
--   per-user avatar prefix only when that user's row is gone.
--
-- REGRESSION TEST
-- supabase/tests/007_account_deletion.sql (queueing, prefix matching,
-- settle-only-when-empty, service-role-only access).

-- Clients have no business here. RLS already denied them; drop the grants
-- too, so a future permissive policy cannot expose it by accident.
REVOKE ALL ON public.storage_cleanup_queue FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.storage_cleanup_queue TO service_role;

ALTER TABLE public.storage_cleanup_queue
  ALTER COLUMN created_at SET NOT NULL;

-- One entry per (bucket, prefix): repeated deletions collapse.
CREATE UNIQUE INDEX IF NOT EXISTS storage_cleanup_queue_bucket_path_key
  ON public.storage_cleanup_queue (bucket_name, storage_path);

COMMENT ON TABLE public.storage_cleanup_queue IS
  'Storage path prefixes awaiting removal through the Storage API. Written by '
  'triggers on couples/users deletion; drained by the storage-cleanup edge '
  'function. Service-role only.';

-- ---------------------------------------------------------------------------
-- Enqueue triggers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enqueue_couple_storage_cleanup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.storage_cleanup_queue (bucket_name, storage_path)
  SELECT b, 'couples/' || OLD.id || '/'
  FROM unnest(ARRAY['avatars', 'timeline', 'love-notes']) AS b
  ON CONFLICT (bucket_name, storage_path) DO NOTHING;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.enqueue_user_avatar_cleanup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.couple_id IS NOT NULL THEN
    INSERT INTO public.storage_cleanup_queue (bucket_name, storage_path)
    VALUES ('avatars', 'couples/' || OLD.couple_id || '/avatars/' || OLD.id || '_')
    ON CONFLICT (bucket_name, storage_path) DO NOTHING;
  END IF;
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.enqueue_couple_storage_cleanup() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enqueue_user_avatar_cleanup() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS enqueue_couple_storage_cleanup_trg ON public.couples;
CREATE TRIGGER enqueue_couple_storage_cleanup_trg
  AFTER DELETE ON public.couples
  FOR EACH ROW EXECUTE FUNCTION public.enqueue_couple_storage_cleanup();

DROP TRIGGER IF EXISTS enqueue_user_avatar_cleanup_trg ON public.users;
CREATE TRIGGER enqueue_user_avatar_cleanup_trg
  AFTER DELETE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.enqueue_user_avatar_cleanup();

-- ---------------------------------------------------------------------------
-- Drain helpers for the edge function (service_role only)
-- ---------------------------------------------------------------------------

-- The objects still present under queued prefixes. PostgREST does not expose
-- the storage schema, so the edge function asks here, then removes the names
-- through the Storage API.
CREATE OR REPLACE FUNCTION public.storage_cleanup_pending(p_limit int DEFAULT 1000)
RETURNS TABLE (bucket_name text, object_name text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT o.bucket_id, o.name
  FROM public.storage_cleanup_queue q
  JOIN storage.objects o
    ON o.bucket_id = q.bucket_name
   AND left(o.name, length(q.storage_path)) = q.storage_path
  ORDER BY q.created_at, o.name
  LIMIT greatest(1, least(coalesce(p_limit, 1000), 1000));
$$;

-- Drops queue entries whose prefix is now empty; returns how many remain.
CREATE OR REPLACE FUNCTION public.storage_cleanup_settle()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_remaining int;
BEGIN
  DELETE FROM public.storage_cleanup_queue q
  WHERE NOT EXISTS (
    SELECT 1 FROM storage.objects o
    WHERE o.bucket_id = q.bucket_name
      AND left(o.name, length(q.storage_path)) = q.storage_path
  );
  SELECT count(*) INTO v_remaining FROM public.storage_cleanup_queue;
  RETURN v_remaining;
END;
$$;

REVOKE ALL ON FUNCTION public.storage_cleanup_pending(int) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.storage_cleanup_settle() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.storage_cleanup_pending(int) TO service_role;
GRANT EXECUTE ON FUNCTION public.storage_cleanup_settle() TO service_role;
