-- Migration: Drop Relationship Activities Table and Triggers
-- Created: 2026-07-02

-- 1. Drop triggers on other tables
DROP TRIGGER IF EXISTS on_love_notes_inserted ON public.love_notes;
DROP TRIGGER IF EXISTS on_bucket_list_modified ON public.bucket_list;
DROP TRIGGER IF EXISTS on_calendar_events_modified ON public.calendar_events;
DROP TRIGGER IF EXISTS on_time_capsules_modified ON public.time_capsules;
DROP TRIGGER IF EXISTS on_vault_items_modified ON public.vault_items;
DROP TRIGGER IF EXISTS on_topic_cards_modified ON public.topic_cards;
DROP TRIGGER IF EXISTS on_topic_card_likes_inserted ON public.topic_card_likes;
DROP TRIGGER IF EXISTS on_gift_reminders_modified ON public.gift_reminders;
DROP TRIGGER IF EXISTS on_moods_modified ON public.moods;
DROP TRIGGER IF EXISTS on_timeline_items_modified ON public.timeline_items;

-- 2. Drop trigger functions
DROP FUNCTION IF EXISTS public.log_love_notes_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_bucket_list_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_calendar_events_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_time_capsules_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_vault_items_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_topic_cards_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_topic_card_likes_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_gift_reminders_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_moods_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_timeline_items_activity() CASCADE;

-- 3. Drop the relationship activities table
DROP TABLE IF EXISTS public.relationship_activities CASCADE;
