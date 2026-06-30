-- Migration: Create topic_card_likes table and configure secure RLS policies
-- Created: 2026-06-30

CREATE TABLE IF NOT EXISTS public.topic_card_likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id uuid NOT NULL REFERENCES public.couples(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  card_id text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE (couple_id, user_id, card_id)
);

-- Enable RLS
ALTER TABLE public.topic_card_likes ENABLE ROW LEVEL SECURITY;

-- Policy: Select likes for the couple
CREATE POLICY "Enable select for same couple" ON public.topic_card_likes
  FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT couple_id FROM public.users WHERE id = auth.uid()
    )
  );

-- Policy: Insert own likes
CREATE POLICY "Enable insert for own user" ON public.topic_card_likes
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid() AND
    couple_id IN (
      SELECT couple_id FROM public.users WHERE id = auth.uid()
    )
  );

-- Policy: Delete own likes
CREATE POLICY "Enable delete for own user" ON public.topic_card_likes
  FOR DELETE TO authenticated
  USING (
    user_id = auth.uid()
  );

-- Indexes
CREATE INDEX IF NOT EXISTS topic_card_likes_couple_id_idx ON public.topic_card_likes (couple_id);
CREATE INDEX IF NOT EXISTS topic_card_likes_user_id_idx ON public.topic_card_likes (user_id);
CREATE INDEX IF NOT EXISTS topic_card_likes_card_id_idx ON public.topic_card_likes (card_id);
