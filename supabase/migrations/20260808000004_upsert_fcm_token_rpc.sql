-- Migration: Add SECURITY DEFINER RPC and flexible RLS policy for FCM Token Upsert
-- Fixes RLS USING expression violation (code 42501) when device token is reassigned to a new user

CREATE OR REPLACE FUNCTION public.upsert_user_fcm_token(
  p_token text,
  p_device_type text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Delete any existing record for this token (e.g. from previous user on same device)
  DELETE FROM public.user_fcm_tokens WHERE token = p_token;

  -- Insert token for currently authenticated user
  INSERT INTO public.user_fcm_tokens (user_id, token, device_type, updated_at)
  VALUES (auth.uid(), p_token, p_device_type, NOW());
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_user_fcm_token(text, text) TO authenticated;

-- Drop restrictive update policy and replace with policy allowing authenticated users to update token assignment
DROP POLICY IF EXISTS "Users can update their own FCM tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Users can update FCM tokens" ON public.user_fcm_tokens;
CREATE POLICY "Users can update FCM tokens" ON public.user_fcm_tokens
  FOR UPDATE
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.uid() = user_id);
