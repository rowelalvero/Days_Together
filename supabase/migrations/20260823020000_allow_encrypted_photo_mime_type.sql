-- Migration: Allow application/octet-stream uploads to photo buckets
-- Created: 2026-08-23
--
-- E2EE photo encryption (20260823010000_e2ee_photo_key_exchange.sql +
-- EncryptedStorageService) uploads AES-GCM ciphertext via `uploadBinary`
-- with `contentType: 'application/octet-stream'`, since the object is no
-- longer a valid image and declaring it as one (image/jpeg) would be
-- misleading metadata. All four photo buckets were created
-- (20260702000003_create_storage_buckets.sql,
-- 20260702000004_create_avatars_bucket.sql) with `allowed_mime_types`
-- restricted to `image/jpeg`/`image/png`/`image/gif` only, so every
-- encrypted upload was being rejected server-side with
-- `StorageException(... mime type application/octet-stream is not
-- supported, statusCode: 415)` -- caught by the mandatory two-device manual
-- test.
--
-- Existing legacy (pre-encryption) objects keep their original image
-- content-type; this only widens what's *allowed* going forward.
--
-- ROLLBACK
--   UPDATE storage.buckets
--   SET allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif']
--   WHERE id IN ('love-notes', 'timeline', 'vault-photos', 'avatars');

UPDATE storage.buckets
SET allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'application/octet-stream']
WHERE id IN ('love-notes', 'timeline', 'vault-photos', 'avatars');
