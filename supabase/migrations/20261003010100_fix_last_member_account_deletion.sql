-- Migration: Fix account deletion for a couple's last member (audit F-08)
-- Created: 2026-10-03
--
-- PROBLEM (reproduced by supabase/tests/007_account_deletion.sql)
-- delete_current_user() deletes auth.users; that cascades to public.users,
-- whose BEFORE DELETE trigger handle_user_deletion_cleanup() deleted the
-- couple when no other member remained. couples -> users.couple_id is
-- ON DELETE SET NULL, so that DELETE rewrote the very users row still being
-- deleted -- and the rewritten row's FK to the already-deleted auth.users
-- failed:
--   ERROR: insert or update on table "users" violates foreign key
--          constraint "users_id_fkey"
-- The whole deletion rolled back. Every unpaired creator, and every partner
-- left alone after an unlink or a partner's deletion, could not delete their
-- account.
--
-- PREVIOUS BEHAVIOUR
-- Paired deletion worked; solo / last-member deletion always failed.
--
-- NEW INVARIANT
-- Any user can delete their account. When they were the couple's last
-- member, the couple -- and, by its ON DELETE CASCADE foreign keys, all of
-- its feature data -- is removed once their row is gone.
--
-- WHY THIS IS THE SMALLEST CORRECT FIX
-- Only the "delete the empty couple" step moves, from the BEFORE trigger to a
-- new AFTER DELETE trigger, where the deleted row no longer exists for the
-- cascade to touch. Everything the BEFORE trigger did with the row still in
-- place -- finding the partner by slot, setting partner_deleted_notice,
-- vacating the slot, invalidating the recovery code -- is unchanged (body is
-- the previous live definition, 20260808000001, minus that final step), so
-- the already-passing paired-deletion behaviour is preserved.
--
-- Storage objects are NOT removed (a Storage API operation, not SQL) -- audit
-- F-21, tracked as a TODO in 007_account_deletion.sql.
--
-- REGRESSION TEST
-- supabase/tests/007_account_deletion.sql (paired, solo, last remaining
-- partner).

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
    -- Look up partner from couples table
    SELECT
      CASE WHEN partner_a_id = OLD.id THEN partner_b_id ELSE partner_a_id END
    INTO v_partner_id
    FROM public.couples
    WHERE id = v_couple_id;

    -- Notify the remaining partner
    IF v_partner_id IS NOT NULL THEN
      UPDATE public.users
      SET partner_deleted_notice = TRUE
      WHERE id = v_partner_id;
    END IF;

    -- Clear the deleted user's slot, email, and invalidate old recovery key
    UPDATE public.couples
    SET
      partner_a_id          = CASE WHEN partner_a_id = OLD.id THEN NULL ELSE partner_a_id END,
      partner_b_id          = CASE WHEN partner_b_id = OLD.id THEN NULL ELSE partner_b_id END,
      partner_a_email       = CASE WHEN partner_a_id = OLD.id THEN NULL ELSE partner_a_email END,
      partner_b_email       = CASE WHEN partner_b_id = OLD.id THEN NULL ELSE partner_b_email END,
      recovery_lookup_key   = NULL,
      recovery_code_hash    = NULL,
      recovery_code_generated_at = NULL
    WHERE id = v_couple_id;

    -- The empty-couple cleanup now runs AFTER the row is gone
    -- (delete_empty_couple_after_user_delete), where it cannot collide with
    -- this row through users.couple_id's ON DELETE SET NULL.
  END IF;

  RETURN OLD;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_empty_couple_after_user_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.couple_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.users WHERE couple_id = OLD.couple_id
  ) THEN
    DELETE FROM public.couples WHERE id = OLD.couple_id;
  END IF;
  RETURN NULL;
END;
$$;

-- Trigger function only: never an RPC (see 20261003000100's privilege model).
REVOKE ALL ON FUNCTION public.delete_empty_couple_after_user_delete() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_empty_couple_after_user_delete() TO service_role;

DROP TRIGGER IF EXISTS delete_empty_couple_after_user_delete_trg ON public.users;
CREATE TRIGGER delete_empty_couple_after_user_delete_trg
  AFTER DELETE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.delete_empty_couple_after_user_delete();
