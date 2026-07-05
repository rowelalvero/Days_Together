-- Migration: Create Love Taps table and add current_activity to users
-- Created: 2026-07-05

-- 1. Add current_activity column to public.users table if it doesn't exist
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS current_activity text;

-- 2. Create love_taps table
CREATE TABLE IF NOT EXISTS public.love_taps (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    couple_id uuid NOT NULL REFERENCES public.couples(id) ON DELETE CASCADE,
    date date NOT NULL,
    partner1_tapped boolean DEFAULT false NOT NULL,
    partner2_tapped boolean DEFAULT false NOT NULL,
    partner1_timestamp timestamptz,
    partner2_timestamp timestamptz,
    completed_at timestamptz,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    UNIQUE (couple_id, date)
);

-- 3. Enable Row Level Security
ALTER TABLE public.love_taps ENABLE ROW LEVEL SECURITY;

-- 4. Policies for RLS
DROP POLICY IF EXISTS "Enable select for same couple" ON public.love_taps;
CREATE POLICY "Enable select for same couple" ON public.love_taps
  FOR SELECT TO authenticated
  USING (couple_id IN (SELECT couple_id FROM public.users WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Enable insert for same couple" ON public.love_taps;
CREATE POLICY "Enable insert for same couple" ON public.love_taps
  FOR INSERT TO authenticated
  WITH CHECK (couple_id IN (SELECT couple_id FROM public.users WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Enable update for same couple" ON public.love_taps;
CREATE POLICY "Enable update for same couple" ON public.love_taps
  FOR UPDATE TO authenticated
  USING (couple_id IN (SELECT couple_id FROM public.users WHERE id = auth.uid()))
  WITH CHECK (couple_id IN (SELECT couple_id FROM public.users WHERE id = auth.uid()));

-- 5. Create performance index
CREATE INDEX IF NOT EXISTS love_taps_couple_id_date_idx ON public.love_taps (couple_id, date);

-- 6. Add to realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.love_taps;
