-- Migration: Create Storage Buckets and Policies
-- Created: 2026-07-02

-- 1. Create the storage buckets if they do not exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('love-notes', 'love-notes', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/gif']),
  ('timeline', 'timeline', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/gif']),
  ('vault-photos', 'vault-photos', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/gif'])
ON CONFLICT (id) DO NOTHING;

-- 2. Drop existing policies if they exist to avoid collisions
DROP POLICY IF EXISTS "Allow authenticated uploads to love-notes, timeline, vault" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated updates to love-notes, timeline, vault" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes from love-notes, timeline, vault" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read from love-notes, timeline, vault" ON storage.objects;

-- 3. Create RLS policies for storage objects in our buckets
CREATE POLICY "Allow authenticated uploads to love-notes, timeline, vault" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id IN ('love-notes', 'timeline', 'vault-photos')
  );

CREATE POLICY "Allow authenticated updates to love-notes, timeline, vault" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id IN ('love-notes', 'timeline', 'vault-photos')
  );

CREATE POLICY "Allow authenticated deletes from love-notes, timeline, vault" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id IN ('love-notes', 'timeline', 'vault-photos')
  );

CREATE POLICY "Allow public read from love-notes, timeline, vault" ON storage.objects
  FOR SELECT TO public
  USING (
    bucket_id IN ('love-notes', 'timeline', 'vault-photos')
  );
