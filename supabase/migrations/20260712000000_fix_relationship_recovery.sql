CREATE OR REPLACE FUNCTION public.handle_user_deletion_cleanup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id uuid;
  v_couple_id uuid;
BEGIN
  v_couple_id := OLD.couple_id;

  IF v_couple_id IS NOT NULL THEN
    -- Look up partner from couples table since partner_id is dropped
    SELECT 
      CASE WHEN partner_a_id = OLD.id THEN partner_b_id ELSE partner_a_id END
    INTO v_partner_id
    FROM public.couples
    WHERE id = v_couple_id;

    -- Notify the remaining partner, keeping couple_id intact to preserve the workspace
    IF v_partner_id IS NOT NULL THEN
      UPDATE public.users
      SET partner_deleted_notice = TRUE
      WHERE id = v_partner_id;
    END IF;

    -- Clean up couples row only if no users remain in it
    IF NOT EXISTS (
      SELECT 1 FROM public.users
      WHERE couple_id = v_couple_id AND id != OLD.id
    ) THEN
      DELETE FROM public.couples WHERE id = v_couple_id;
    END IF;
  END IF;

  RETURN OLD;
END;
$$;
