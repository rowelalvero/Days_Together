-- Migration: Remove the Secret Vault feature's backend
-- Created: 2026-09-11
--
-- The Secret Vault was removed from the application entirely (UI, controller,
-- state, model, routes, bento card, calendar integration, and the AI love
-- letter "save to vault" action). This drops what it owned server-side.
--
-- *** DESTRUCTIVE AND IRREVERSIBLE ***
-- This deletes every row in public.vault_items and every object stored in the
-- vault-photos bucket. Those photos are AES-GCM ciphertext encrypted with the
-- couple's E2EE photo key, so there is no server-side copy to recover from
-- and no way to reconstruct them once deleted. Take a backup first if there
-- is any doubt.
--
-- Deliberately NOT dropped:
--   * public.user_notification_preferences.vault_enabled -- an unused boolean
--     column with a default. Harmless to leave, and keeping it means this
--     migration touches only objects the vault exclusively owned.
--   * The E2EE key material (couple_key_exchanges, users.public_key) and
--     EncryptedStorageService -- shared with avatars, note-its, and timeline
--     photos, all of which still encrypt uploads.

-- ---------------------------------------------------------------------------
-- 1. The vault_items table.
--    Dropping it also removes its primary key, the couple_id foreign key, the
--    idx_vault_items_couple_id index (20260707000002), the "Couple access to
--    vault_items" RLS policy, and its membership in the supabase_realtime
--    publication -- all of which are owned by the table.
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS public.vault_items CASCADE;

-- ---------------------------------------------------------------------------
-- 2. Stored vault photos, then the bucket itself.
--    Objects must go first: storage.buckets has a foreign key from
--    storage.objects, so deleting a non-empty bucket errors out.
-- ---------------------------------------------------------------------------
DELETE FROM storage.objects WHERE bucket_id = 'vault-photos';
DELETE FROM storage.buckets WHERE id = 'vault-photos';

-- ---------------------------------------------------------------------------
-- 3. Re-scope the shared storage policies.
--    The four policies from 20260702000003, hardened in 20260713000001, list
--    their buckets in a `bucket_id IN (...)` clause that still names
--    vault-photos. A policy naming a bucket that no longer exists is dead
--    weight rather than a security hole, but leaving it would let a future
--    re-created 'vault-photos' bucket silently inherit write access.
--
--    Policy names are kept byte-identical to the originals so this stays a
--    redefinition rather than a rename; only the bucket list and the trailing
--    comment change. The couple_id folder check from 20260713000001 (audit
--    issues 7.3/7.4) is preserved exactly.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow authenticated uploads to love-notes, timeline, vault" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated updates to love-notes, timeline, vault" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes from love-notes, timeline, vault" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read from love-notes, timeline, vault" ON storage.objects;

-- love-notes and timeline only, from here on.
CREATE POLICY "Allow authenticated uploads to love-notes, timeline, vault" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id IN ('love-notes', 'timeline')
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );

CREATE POLICY "Allow authenticated updates to love-notes, timeline, vault" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id IN ('love-notes', 'timeline')
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );

CREATE POLICY "Allow authenticated deletes from love-notes, timeline, vault" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id IN ('love-notes', 'timeline')
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );

CREATE POLICY "Allow public read from love-notes, timeline, vault" ON storage.objects
  FOR SELECT TO public
  USING (
    bucket_id IN ('love-notes', 'timeline')
  );
