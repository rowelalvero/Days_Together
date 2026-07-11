-- Migration: Database Indexing Optimizations for Performance & RLS Hardening
-- Created At: 2026-07-11

-- 1. Index users(couple_id)
-- Reason: Heavily queried by RLS checks (e.g. is_member_of_couple) and the users SELECT RLS policy.
-- Prevents full table sequential scans on users when validating couple memberships.
CREATE INDEX IF NOT EXISTS users_couple_id_idx ON public.users (couple_id);


-- 3. Index couples(partner_a_id)
-- Reason: Checked in is_member_of_couple() to verify active couple memberships for auth.uid().
CREATE INDEX IF NOT EXISTS couples_partner_a_id_idx ON public.couples (partner_a_id);

-- 4. Index couples(partner_b_id)
-- Reason: Checked in is_member_of_couple() to verify active couple memberships for auth.uid().
CREATE INDEX IF NOT EXISTS couples_partner_b_id_idx ON public.couples (partner_b_id);

-- 5. Index topic_cards(couple_id)
-- Reason: Speeds up custom topic cards loading, filtering, and shuffling scoped to the relationship workspace.
CREATE INDEX IF NOT EXISTS topic_cards_couple_id_idx ON public.topic_cards (couple_id);

-- 6. Index user_fcm_tokens(user_id)
-- Reason: Speeds up fcm token lookup when sending notifications to a user, and clean up on login/logout.
CREATE INDEX IF NOT EXISTS user_fcm_tokens_user_id_idx ON public.user_fcm_tokens (user_id);

-- 7. Index moods(user_id)
-- Reason: Speeds up daily mood history retrieval and analytics/graphs scoped to a specific user.
CREATE INDEX IF NOT EXISTS moods_user_id_idx ON public.moods (user_id);

-- 8. Index daily_questions(couple_id)
-- Reason: Composite primary key (date, couple_id) starts with date, making searches by couple_id alone inefficient.
CREATE INDEX IF NOT EXISTS daily_questions_couple_id_idx ON public.daily_questions (couple_id);

-- 9. Index love_notes(sender_id)
-- Reason: Speeds up filtering notes by sender, and improves CASCADE delete performance when users are deleted.
CREATE INDEX IF NOT EXISTS love_notes_sender_id_idx ON public.love_notes (sender_id);

-- 10. Index license_details(creator_id)
-- Reason: Speeds up certificate lookup by relationship creator.
CREATE INDEX IF NOT EXISTS license_details_creator_id_idx ON public.license_details (creator_id);


