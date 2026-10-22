-- Migration: Indexes matched to the app's actual ordered queries (audit
--            Phase 5, performance)
-- Created: 2026-10-03
--
-- PROBLEM (measured on the local stack: one couple with 6,000 chat lines,
-- 400 doodles and 300 memories, among 200 other couples)
-- * Chat loads `love_notes WHERE couple_id = ? AND type = 'chat'
--   ORDER BY created_at DESC LIMIT 200` (LoveChatController). With only a
--   couple_id index, Postgres fetched EVERY love_notes row of the couple
--   (doodles included), filtered type in the heap, then sorted -- a cost that
--   grows with the couple's whole history, not with the 200 rows returned.
-- * The timeline loads `timeline_items WHERE couple_id = ? ORDER BY date DESC
--   LIMIT 100` (TimelineController) and got a sequential scan plus a sort.
--
-- NEW STATE
-- * love_notes (couple_id, type, created_at DESC): the chat query becomes a
--   single index range scan that stops after 200 entries -- no sort
--   (EXPLAIN: "Limit -> Index Scan using ..."). It also serves the note-it
--   load (couple_id with type <> 'chat') and every couple_id-only lookup
--   (RLS checks, realtime filters) through its leading column.
-- * timeline_items (couple_id, date DESC): serves the ordered timeline load
--   and every couple_id-only lookup.
--
-- WHY THIS IS SAFE
-- The two single-column couple_id indexes are dropped because each new
-- composite has couple_id as its leading column, so it answers everything
-- they did; keeping both only doubles write cost. No query semantics change.
-- Built non-concurrently: the migration CLI runs each file in a transaction,
-- which CREATE INDEX CONCURRENTLY cannot run in. These tables are small per
-- deployment, so the brief lock is acceptable; on a very large table, build
-- concurrently by hand first and keep these IF NOT EXISTS statements.
--
-- REGRESSION TEST
-- supabase/tests/012_query_indexes.sql (index exists AND the planner uses it
-- for the app's exact query shape).

CREATE INDEX IF NOT EXISTS love_notes_couple_type_created_idx
  ON public.love_notes (couple_id, type, created_at DESC);
DROP INDEX IF EXISTS public.idx_love_notes_couple_id;

CREATE INDEX IF NOT EXISTS timeline_items_couple_date_idx
  ON public.timeline_items (couple_id, date DESC);
DROP INDEX IF EXISTS public.idx_timeline_items_couple_id;
