-- Migration: Add created_at column to public.users table
-- Needed for partner join date display
-- Created: 2026-07-02

-- 1. Add the column (nullable, with default for new rows)
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

-- 2. Backfill existing rows from auth.users
UPDATE public.users u
SET created_at = a.created_at
FROM auth.users a
WHERE u.id = a.id
  AND u.created_at IS NULL;

-- 3. Also add a name column if missing (used by activity triggers)
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS name text;
