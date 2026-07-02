-- Migration: Create Avatars Storage Bucket and Policies
-- Created: 2026-07-02

-- 1. Create the avatars storage bucket if it does not exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('avatars', 'avatars', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/gif'])
ON CONFLICT (id) DO NOTHING;

-- 2. Drop existing policies if they exist to avoid collisions
DROP POLICY IF EXISTS "Allow authenticated uploads to avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated updates to avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes from avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read from avatars" ON storage.objects;

-- 3. Create RLS policies for storage objects in avatars bucket
CREATE POLICY "Allow authenticated uploads to avatars" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
  );

CREATE POLICY "Allow authenticated updates to avatars" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars'
  );

CREATE POLICY "Allow authenticated deletes from avatars" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars'
  );

CREATE POLICY "Allow public read from avatars" ON storage.objects
  FOR SELECT TO public
  USING (
    bucket_id = 'avatars'
  );
