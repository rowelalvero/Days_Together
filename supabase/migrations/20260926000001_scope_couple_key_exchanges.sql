-- A recipient may retain rows from old relationships after unlinking. Only
-- expose the wrapped key for the relationship they currently belong to.
DROP POLICY IF EXISTS "Enable select for own wrapped key" ON public.couple_key_exchanges;
CREATE POLICY "Enable select for own wrapped key" ON public.couple_key_exchanges
  FOR SELECT TO authenticated
  USING (
    recipient_user_id = auth.uid()
    AND couple_id = (
      SELECT u.couple_id FROM public.users u WHERE u.id = auth.uid()
    )
  );

-- Remove existing stale rows as well as future rows left by unlinking.
DELETE FROM public.couple_key_exchanges cke
WHERE NOT EXISTS (
  SELECT 1 FROM public.users u
  WHERE u.id = cke.recipient_user_id
    AND u.couple_id = cke.couple_id
);

CREATE OR REPLACE FUNCTION public.remove_stale_couple_key_exchanges()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
  IF OLD.couple_id IS DISTINCT FROM NEW.couple_id THEN
    DELETE FROM public.couple_key_exchanges
    WHERE recipient_user_id = NEW.id
      AND couple_id IS DISTINCT FROM NEW.couple_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS remove_stale_couple_key_exchanges_on_unlink ON public.users;
CREATE TRIGGER remove_stale_couple_key_exchanges_on_unlink
  AFTER UPDATE OF couple_id ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.remove_stale_couple_key_exchanges();
