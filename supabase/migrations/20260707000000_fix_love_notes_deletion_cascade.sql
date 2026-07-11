-- Migration: Add ON DELETE CASCADE to love_notes_sender_id_fkey
-- Created: 2026-07-07

ALTER TABLE public.love_notes
DROP CONSTRAINT IF EXISTS love_notes_sender_id_fkey;

ALTER TABLE public.love_notes
ADD CONSTRAINT love_notes_sender_id_fkey
FOREIGN KEY (sender_id)
REFERENCES auth.users(id)
ON DELETE CASCADE;
