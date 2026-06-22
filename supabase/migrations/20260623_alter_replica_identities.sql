-- Set REPLICA IDENTITY to FULL for tables that are queried with realtime stream filters.
-- This ensures that DELETE event payloads contain all row columns (such as couple_id),
-- allowing the client-side realtime filters (e.g. .eq('couple_id', ...)) to correctly
-- match and process deletions.

ALTER TABLE public.timeline_items REPLICA IDENTITY FULL;
ALTER TABLE public.bucket_list REPLICA IDENTITY FULL;
ALTER TABLE public.calendar_events REPLICA IDENTITY FULL;
ALTER TABLE public.moods REPLICA IDENTITY FULL;
ALTER TABLE public.gift_reminders REPLICA IDENTITY FULL;
ALTER TABLE public.love_notes REPLICA IDENTITY FULL;
ALTER TABLE public.time_capsules REPLICA IDENTITY FULL;
ALTER TABLE public.topic_cards REPLICA IDENTITY FULL;
ALTER TABLE public.vault_items REPLICA IDENTITY FULL;
