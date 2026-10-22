-- Migration: Couple presence on a private Realtime channel (re-audit R-02 /
--            audit F-13 / invariant S15)
-- Created: 2026-10-03
--
-- PROBLEM
-- PartnerPresence joined a PUBLIC Realtime channel, couple_presence_<coupleId>.
-- Public channels are not authorised at all: anyone with the anon key and a
-- couple id -- sent in every push payload's data, embedded in storage paths,
-- and permanently known to an ex-partner -- could join, watch when the couple
-- is online, and track() a spoofed user_id to fake "partner online".
--
-- NEW INVARIANT
-- The client joins the channel as private (RealtimeChannelConfig(private:
-- true)). Realtime then authorises the join and every presence track by
-- evaluating realtime.messages RLS as the joining user with realtime.topic()
-- set to the channel topic. These policies admit exactly the couple's
-- current members -- the same slot-based membership is_member_of_couple
-- uses -- on that couple's topic only. Leaving the couple (unlink or account
-- deletion) revokes access at once.
--
-- READ covers broadcast AND presence: verified against the real Realtime
-- server (realtime 2.107.5, test/e2e/realtime_e2e_test.dart), joining a
-- private channel at all requires broadcast read -- with presence read alone
-- every join, members included, is refused ("You do not have permissions to
-- read from this Channel topic"). Granting it exposes nothing: WRITE stays
-- presence-only, so no client can send a broadcast on the topic.
--
-- WHY THIS IS SAFE
-- * Additive: no existing policy on realtime.messages; postgres_changes
--   subscriptions (the feature streams) do not go through realtime.messages
--   and are unaffected.
-- * The topic is matched by exact equality against the caller's own
--   couple id, so no other topic shape (bare id, suffixed id, another couple)
--   is admitted.
--
-- NO dashboard change is needed (verified against the real Realtime server,
-- test/e2e/realtime_e2e_test.dart): an outsider joining the same topic as a
-- PUBLIC channel lands in a separate channel and sees none of the couple's
-- private presence. Do NOT disable "Allow public access" for this: the
-- feature streams (.stream()) join public channels.
--
-- REGRESSION TEST
-- supabase/tests/011_realtime_presence.sql

CREATE OR REPLACE FUNCTION public.is_couple_presence_topic(p_topic text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    JOIN public.couples c ON c.id = u.couple_id
    WHERE u.id = auth.uid()
      AND (c.partner_a_id = auth.uid() OR c.partner_b_id = auth.uid())
      AND c.status <> 'archived'
      AND p_topic = 'couple_presence_' || c.id::text
  );
$$;

-- RLS predicate, evaluated as the joining user (see 20261003000100's model):
-- authenticated only, never anon.
REVOKE ALL ON FUNCTION public.is_couple_presence_topic(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_couple_presence_topic(text) TO authenticated, service_role;

DROP POLICY IF EXISTS "Couple members receive their presence" ON realtime.messages;
CREATE POLICY "Couple members receive their presence" ON realtime.messages
  FOR SELECT TO authenticated
  USING (
    realtime.messages.extension IN ('broadcast', 'presence')
    AND public.is_couple_presence_topic(realtime.topic())
  );

DROP POLICY IF EXISTS "Couple members track their presence" ON realtime.messages;
CREATE POLICY "Couple members track their presence" ON realtime.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    realtime.messages.extension = 'presence'
    AND public.is_couple_presence_topic(realtime.topic())
  );
