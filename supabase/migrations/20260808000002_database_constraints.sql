-- Migration: Database Integrity & Constraints (M-5, M-6, L-2)
-- Created: 2026-08-08

-- ============================================================
-- 1. Couples Status CHECK Constraint (Audit M-6)
-- Clean up any unexpected values first, then add CHECK constraint
-- ============================================================
UPDATE public.couples
SET status = 'waiting'
WHERE status NOT IN ('waiting', 'active', 'disconnected', 'archived') OR status IS NULL;

ALTER TABLE public.couples DROP CONSTRAINT IF EXISTS couples_status_check;
ALTER TABLE public.couples ADD CONSTRAINT couples_status_check
  CHECK (status IN ('waiting', 'active', 'disconnected', 'archived'));

-- ============================================================
-- 2. Calendar Events Type CHECK Constraint & Documentation (Audit M-5)
-- Document integer type meanings:
-- 0: Anniversary, 1: Birthday, 2: Date Night, 3: Holiday, 4: Custom Event
-- ============================================================
ALTER TABLE public.calendar_events DROP CONSTRAINT IF EXISTS calendar_events_type_check;
ALTER TABLE public.calendar_events ADD CONSTRAINT calendar_events_type_check
  CHECK (type >= 0 AND type <= 4);

COMMENT ON COLUMN public.calendar_events.type IS
  '0: Anniversary, 1: Birthday, 2: Date Night, 3: Holiday, 4: Custom Event';

-- ============================================================
-- 3. Users updated_at Automatic Timestamp Trigger (Audit L-2)
-- ============================================================
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_users_updated_at ON public.users;
CREATE TRIGGER set_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
