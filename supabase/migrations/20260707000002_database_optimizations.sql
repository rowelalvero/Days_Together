-- Migration: Database Optimizations - Performance Indexes & Integrity Constraints
-- Created: 2026-07-07

-- 1. ADD PERFORMANCE INDEXES FOR SHARED FEATURES
-- These indexes prevent full table scans when querying relationship data.
CREATE INDEX IF NOT EXISTS idx_timeline_items_couple_id ON public.timeline_items (couple_id);
CREATE INDEX IF NOT EXISTS idx_love_notes_couple_id ON public.love_notes (couple_id);
CREATE INDEX IF NOT EXISTS idx_bucket_list_couple_id ON public.bucket_list (couple_id);
CREATE INDEX IF NOT EXISTS idx_moods_couple_id ON public.moods (couple_id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_couple_id ON public.calendar_events (couple_id);
CREATE INDEX IF NOT EXISTS idx_vault_items_couple_id ON public.vault_items (couple_id);
CREATE INDEX IF NOT EXISTS idx_gift_reminders_couple_id ON public.gift_reminders (couple_id);
CREATE INDEX IF NOT EXISTS idx_time_capsules_couple_id ON public.time_capsules (couple_id);

-- 2. ENFORCE UNIQUENESS ON WORKSPACE IDENTIFIERS
-- This adds a second layer of protection alongside the application logic.
ALTER TABLE public.couples DROP CONSTRAINT IF EXISTS couples_pairing_code_unique;
ALTER TABLE public.couples ADD CONSTRAINT couples_pairing_code_unique UNIQUE (pairing_code);

ALTER TABLE public.couples DROP CONSTRAINT IF EXISTS couples_recovery_lookup_key_unique;
ALTER TABLE public.couples ADD CONSTRAINT couples_recovery_lookup_key_unique UNIQUE (recovery_lookup_key);

-- 3. STORAGE CLEANUP TRACKING (Optional/Future Proofing)
-- Create a table to track files that need to be deleted from storage.
-- This allows moving cleanup logic to the server via webhooks or edge functions.
CREATE TABLE IF NOT EXISTS public.storage_cleanup_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_name text NOT NULL,
  storage_path text NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.storage_cleanup_queue ENABLE ROW LEVEL SECURITY;
-- No public policies needed as this is system-managed.
