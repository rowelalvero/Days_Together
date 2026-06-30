-- Migration: Implement Safe, Atomic Account Deletion & Relationship Cleanup
-- Created: 2026-06-30

-- 1. ADD NOTICE COLUMN FOR REMAINING PARTNER
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS partner_deleted_notice boolean DEFAULT false;

-- 2. CREATE USER DELETION TRIGGER CLEANUP FUNCTION
CREATE OR REPLACE FUNCTION public.handle_user_deletion_cleanup()
RETURNS TRIGGER AS $$
DECLARE
  v_partner_id uuid;
  v_couple_id uuid;
BEGIN
  -- Capture the partner_id and couple_id of the user being deleted
  v_partner_id := OLD.partner_id;
  v_couple_id := OLD.couple_id;

  -- A. Clean up remaining partner (if any)
  IF v_partner_id IS NOT NULL THEN
    UPDATE public.users
    SET 
      partner_id = NULL,
      couple_id = NULL,
      partner_deleted_notice = TRUE
    WHERE id = v_partner_id;
  END IF;

  -- B. Clean up the couple record and cascade delete shared resources
  IF v_couple_id IS NOT NULL THEN
    -- Only delete the couple if no other active user is associated with it
    IF NOT EXISTS (
      SELECT 1 FROM public.users 
      WHERE couple_id = v_couple_id AND id != OLD.id
    ) THEN
      DELETE FROM public.couples WHERE id = v_couple_id;
    END IF;
  END IF;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger on public.users
DROP TRIGGER IF EXISTS user_deletion_cleanup_trg ON public.users;
CREATE TRIGGER user_deletion_cleanup_trg
  BEFORE DELETE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_user_deletion_cleanup();

-- 3. CREATE SECURE RPC TO DELETE AUTH USER
CREATE OR REPLACE FUNCTION public.delete_current_user()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- Deleting from auth.users will cascade to public.users and trigger cleanup
  DELETE FROM auth.users WHERE id = v_user_id;

  RETURN json_build_object('success', true);
END;
$$;
