-- Migration: Harden pairing (audit F-03, F-17, F-04 guards / invariants
--            S01, S03, S04, S05)
-- Created: 2026-10-03
--
-- PROBLEM
-- 1. join_relationship_with_code had no attempt limit. 20260707000001 added
--    one (failed_pairing_attempts), 20260808000003 rewrote the function
--    without it, and every later rewrite copied that body. Its counter write
--    was also followed by RAISE EXCEPTION, which rolls the write back, so
--    even the original limiter never persisted a failure.
-- 2. Codes were 6 characters (36^6 ~ 2.2e9) drawn from random(), which is
--    not a CSPRNG. A hit hands an attacker a stranger's waiting workspace --
--    which may already hold data -- and the creator's device then wraps the
--    couple photo key for whoever occupies the partner slot.
-- 3. create_relationship_workspace and join_relationship_with_code lost
--    their auth.uid() IS NULL guard in 20260808000003.
-- 4. failed_pairing_attempts carried a FOR ALL "own row" policy, so a user
--    could reset or delete their own counter directly via PostgREST.
--
-- PREVIOUS BEHAVIOUR
-- Unlimited, unthrottled 6-char guesses, failures raised exceptions
-- (raw Postgres text surfaced in the app), anon/identity-less calls
-- proceeded with auth.uid() = NULL.
--
-- NEW INVARIANTS
-- S01 join/create refuse auth.uid() IS NULL (in addition to the EXECUTE
--     privilege model of 20261003000100).
-- S03 Every failed join is persisted before the function returns: failures
--     RETURN a structured result instead of RAISE-ing, so the counter
--     commits. 5 failures lock the account out of joining for 15 minutes.
--     A global circuit breaker additionally throttles accounts that are part
--     of a system-wide failure storm (many-account brute force) while still
--     evaluating a user's first attempt.
-- S04 Pairing codes are 8 characters (36^8 ~ 2.8e12) from gen_random_bytes
--     with rejection sampling (no modulo bias). Recovery lookup keys and
--     secrets minted by create_relationship_workspace use the same source.
-- S05 A successful join clears the pairing code; the slot claim is a
--     conditional UPDATE (partner_b_id IS NULL AND status = 'waiting'), so of
--     two concurrent joins exactly one can succeed and the loser gets a
--     structured INVALID_CODE.
--
-- STABLE ERROR CODES (join_relationship_with_code)
--   {"success": false, "error_code": <code>, "error": <message>[, "retry_after": <ts>]}
--   INVALID_SESSION  no authenticated user / no profile row
--   ALREADY_PAIRED   caller already belongs to a couple
--   INVALID_CODE     unknown, consumed, malformed, or lost-the-race code
--   CODE_EXPIRED     code older than 20 minutes
--   RATE_LIMITED     per-user lockout or global storm; retry_after set
-- "error" keeps a human-readable message so clients that predate
-- error_code still show something sensible.
--
-- WHY THIS IS SAFE
-- * Signatures and return types are unchanged; CREATE OR REPLACE keeps the
--   EXECUTE grants from 20261003000100. Each body is the previous live
--   definition (create/join: 20260823010000, rotate: 20260823000000) plus the
--   changes listed above -- public_key handling, FOR UPDATE locking, the
--   20-minute validity window and the response fields are all preserved.
-- * couples.pairing_code widens from varchar(6) to varchar(8); existing
--   6-char codes stay valid until they expire or rotate (<= 20 minutes), and
--   the join accepts 6-8 characters during that window.
-- * Old clients: a structured failure means their joinWithCode throws
--   Exception(result['error']) -- a readable message, not a crash.
--
-- REGRESSION TESTS
-- supabase/tests/003_pairing.sql, 004_pairing_race.sql (genuine two-session
-- race), 001_rpc_privileges.sql (identity-less refusal).

-- =====================================================================
-- 1. Secure code generator (internal; not an RPC)
-- =====================================================================
CREATE OR REPLACE FUNCTION public.generate_secure_code(p_length integer)
RETURNS text
LANGUAGE plpgsql
VOLATILE
SET search_path = pg_catalog, extensions, pg_temp
AS $$
DECLARE
  v_alphabet CONSTANT text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  v_out text := '';
  v_bytes bytea;
  v_byte integer;
  i integer;
BEGIN
  IF p_length IS NULL OR p_length < 1 OR p_length > 64 THEN
    RAISE EXCEPTION 'generate_secure_code: length must be between 1 and 64';
  END IF;

  WHILE length(v_out) < p_length LOOP
    v_bytes := extensions.gen_random_bytes(p_length * 2);
    FOR i IN 0 .. length(v_bytes) - 1 LOOP
      v_byte := get_byte(v_bytes, i);
      -- 252 = 7 * 36, the largest multiple of the alphabet size <= 256.
      -- Bytes 252..255 are rejected so every symbol is exactly equally likely.
      IF v_byte < 252 THEN
        v_out := v_out || substr(v_alphabet, (v_byte % 36) + 1, 1);
        EXIT WHEN length(v_out) = p_length;
      END IF;
    END LOOP;
  END LOOP;

  RETURN v_out;
END;
$$;

REVOKE ALL ON FUNCTION public.generate_secure_code(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.generate_secure_code(integer) TO service_role;

-- =====================================================================
-- 2. Attempt tracking
-- =====================================================================
-- Per-user counter: existing table, now server-only.
DROP POLICY IF EXISTS "Enable select/update for own pairing attempts" ON public.failed_pairing_attempts;
REVOKE ALL ON TABLE public.failed_pairing_attempts FROM anon, authenticated;

-- Global failure log for the circuit breaker. No policies + no grants:
-- readable and writable only by SECURITY DEFINER code and service_role.
CREATE TABLE IF NOT EXISTS public.pairing_attempt_failures (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  attempted_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS pairing_attempt_failures_attempted_at_idx
  ON public.pairing_attempt_failures (attempted_at);
CREATE INDEX IF NOT EXISTS pairing_attempt_failures_user_idx
  ON public.pairing_attempt_failures (user_id, attempted_at);
ALTER TABLE public.pairing_attempt_failures ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.pairing_attempt_failures FROM anon, authenticated;

-- 8-character codes.
ALTER TABLE public.couples ALTER COLUMN pairing_code TYPE varchar(8);

-- =====================================================================
-- 3. create_relationship_workspace -- previous live body (20260823010000)
--    + auth guard, missing-profile guard, secure codes, 8-char pairing code.
-- =====================================================================
CREATE OR REPLACE FUNCTION public.create_relationship_workspace(p_public_key text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_couple_id uuid;
  v_pairing_code text;
  v_lookup_key text;
  v_secret_formatted text;
  v_secret_clean text;
  v_user_couple_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- Lock caller row to prevent concurrent updates
  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User profile unavailable';
  END IF;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  v_couple_id := gen_random_uuid();

  -- Retry loop to generate unique codes
  LOOP
    v_pairing_code := public.generate_secure_code(8);
    v_lookup_key := public.generate_secure_code(6);
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.couples WHERE pairing_code = v_pairing_code)
          AND NOT EXISTS (SELECT 1 FROM public.couples WHERE recovery_lookup_key = v_lookup_key);
  END LOOP;

  -- 16-char secret key grouped with hyphens
  v_secret_clean := public.generate_secure_code(16);
  v_secret_formatted := substr(v_secret_clean, 1, 4) || '-' ||
                        substr(v_secret_clean, 5, 4) || '-' ||
                        substr(v_secret_clean, 9, 4) || '-' ||
                        substr(v_secret_clean, 13, 4);

  INSERT INTO public.couples (
    id, status, partner_a_id, pairing_code, pairing_code_updated_at, recovery_lookup_key, recovery_code_hash
  )
  VALUES (
    v_couple_id,
    'waiting',
    auth.uid(),
    v_pairing_code,
    now(),
    v_lookup_key,
    crypt(v_secret_clean, gen_salt('bf', 10))
  );

  -- Update user couple_id and public key together
  UPDATE public.users SET couple_id = v_couple_id, public_key = COALESCE(p_public_key, public_key) WHERE id = auth.uid();

  RETURN json_build_object(
    'success', true,
    'couple_id', v_couple_id,
    'pairing_code', v_pairing_code,
    'recovery_code', v_lookup_key || '-' || v_secret_formatted,
    'expires_in_seconds', 1200
  );
END;
$$;

-- =====================================================================
-- 4. get_or_rotate_pairing_code -- previous live body (20260823000000)
--    with the code drawn from generate_secure_code(8).
-- =====================================================================
CREATE OR REPLACE FUNCTION public.get_or_rotate_pairing_code(p_force_rotate boolean DEFAULT false)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_couple_id uuid;
  v_current_code text;
  v_updated_at timestamptz;
  v_status text;
  v_new_code text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT id, status, pairing_code, pairing_code_updated_at
  INTO v_couple_id, v_status, v_current_code, v_updated_at
  FROM public.couples
  WHERE id = (SELECT couple_id FROM public.users WHERE id = auth.uid())
     OR partner_a_id = auth.uid()
     OR partner_b_id = auth.uid()
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF v_couple_id IS NULL THEN
    RAISE EXCEPTION 'User is not in a relationship workspace';
  END IF;

  IF v_status != 'waiting' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Relationship is already active'
    );
  END IF;

  -- Rotate code if missing, older than 20 mins (1200s), or explicitly requested
  IF p_force_rotate OR v_current_code IS NULL OR v_updated_at IS NULL OR (now() - v_updated_at) > interval '20 minutes' THEN
    LOOP
      v_new_code := public.generate_secure_code(8);
      EXIT WHEN NOT EXISTS (SELECT 1 FROM public.couples WHERE pairing_code = v_new_code);
    END LOOP;

    UPDATE public.couples
    SET pairing_code = v_new_code,
        pairing_code_updated_at = now()
    WHERE id = v_couple_id;

    v_current_code := v_new_code;
    v_updated_at := now();
  END IF;

  RETURN json_build_object(
    'success', true,
    'couple_id', v_couple_id,
    'pairing_code', v_current_code,
    'expires_in_seconds', GREATEST(0, extract(epoch from (v_updated_at + interval '20 minutes' - now()))::integer)
  );
END;
$$;

-- =====================================================================
-- 5. join_relationship_with_code -- rate-limited, structured results.
-- =====================================================================
CREATE OR REPLACE FUNCTION public.join_relationship_with_code(
  p_pairing_code text,
  p_public_key text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  -- Policy knobs.
  c_max_failures CONSTANT integer := 5;
  c_lockout CONSTANT interval := interval '15 minutes';
  c_counter_decay CONSTANT interval := interval '1 hour';
  c_code_ttl CONSTANT interval := interval '20 minutes';
  c_storm_window CONSTANT interval := interval '5 minutes';
  c_storm_threshold CONSTANT integer := 500;

  v_uid uuid := auth.uid();
  v_user_couple_id uuid;
  v_attempts public.failed_pairing_attempts%ROWTYPE;
  v_code text;
  v_couple public.couples%ROWTYPE;
  v_reason text;
  v_failures integer;
  v_locked_until timestamptz;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'error_code', 'INVALID_SESSION',
      'error', 'Please sign in again.');
  END IF;

  -- Lock the caller's row: serialises this account's attempts, so the
  -- read-modify-write of its counter below cannot race with itself.
  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = v_uid FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error_code', 'INVALID_SESSION',
      'error', 'Please sign in again.');
  END IF;
  IF v_user_couple_id IS NOT NULL THEN
    RETURN json_build_object('success', false, 'error_code', 'ALREADY_PAIRED',
      'error', 'You are already in a relationship.');
  END IF;

  -- Per-user lockout.
  SELECT * INTO v_attempts FROM public.failed_pairing_attempts WHERE user_id = v_uid;
  IF v_attempts.locked_until > now() THEN
    RETURN json_build_object('success', false, 'error_code', 'RATE_LIMITED',
      'error', 'Too many attempts. Please try again later.',
      'retry_after', v_attempts.locked_until);
  END IF;

  -- Global circuit breaker: during a system-wide failure storm, accounts
  -- that are themselves failing are throttled; a first attempt still runs.
  IF EXISTS (SELECT 1 FROM public.pairing_attempt_failures
             WHERE user_id = v_uid AND attempted_at > now() - c_storm_window)
     AND (SELECT count(*) FROM public.pairing_attempt_failures
          WHERE attempted_at > now() - c_storm_window) >= c_storm_threshold THEN
    RETURN json_build_object('success', false, 'error_code', 'RATE_LIMITED',
      'error', 'Too many attempts. Please try again later.',
      'retry_after', now() + c_storm_window);
  END IF;

  v_code := upper(regexp_replace(coalesce(p_pairing_code, ''), '\s', '', 'g'));

  IF v_code !~ '^[A-Z0-9]{6,8}$' THEN
    v_reason := 'INVALID_CODE';
  ELSE
    SELECT * INTO v_couple FROM public.couples WHERE pairing_code = v_code FOR UPDATE;

    IF NOT FOUND OR v_couple.status <> 'waiting' OR v_couple.partner_b_id IS NOT NULL THEN
      v_reason := 'INVALID_CODE';
    ELSIF v_couple.partner_a_id = v_uid THEN
      RETURN json_build_object('success', false, 'error_code', 'ALREADY_PAIRED',
        'error', 'You are already in a relationship.');
    ELSIF v_couple.pairing_code_updated_at IS NULL
          OR now() - v_couple.pairing_code_updated_at > c_code_ttl THEN
      v_reason := 'CODE_EXPIRED';
    ELSE
      -- Conditional claim: a concurrent join that won the slot first leaves
      -- this matching nothing, rather than being overwritten.
      UPDATE public.couples
      SET partner_b_id = v_uid, status = 'active', pairing_code = NULL
      WHERE id = v_couple.id AND partner_b_id IS NULL AND status = 'waiting';

      IF FOUND THEN
        UPDATE public.users
        SET couple_id = v_couple.id, public_key = COALESCE(p_public_key, public_key)
        WHERE id = v_uid;

        UPDATE public.failed_pairing_attempts
        SET attempts = 0, locked_until = NULL, updated_at = now()
        WHERE user_id = v_uid;

        RETURN json_build_object(
          'success', true,
          'couple_id', v_couple.id,
          'partner_id', v_couple.partner_a_id
        );
      END IF;
      v_reason := 'INVALID_CODE';
    END IF;
  END IF;

  -- Failure: persist the attempt, then RETURN (never RAISE -- that would
  -- roll the counter back).
  v_failures := CASE
    WHEN v_attempts.user_id IS NULL THEN 1
    WHEN v_attempts.locked_until IS NOT NULL AND v_attempts.locked_until <= now() THEN 1
    WHEN v_attempts.updated_at < now() - c_counter_decay THEN 1
    ELSE v_attempts.attempts + 1
  END;
  v_locked_until := CASE WHEN v_failures >= c_max_failures THEN now() + c_lockout END;

  INSERT INTO public.failed_pairing_attempts (user_id, attempts, locked_until, updated_at)
  VALUES (v_uid, v_failures, v_locked_until, now())
  ON CONFLICT (user_id) DO UPDATE
  SET attempts = EXCLUDED.attempts, locked_until = EXCLUDED.locked_until, updated_at = EXCLUDED.updated_at;

  INSERT INTO public.pairing_attempt_failures (user_id) VALUES (v_uid);
  DELETE FROM public.pairing_attempt_failures WHERE attempted_at < now() - interval '1 hour';

  RETURN json_build_object(
    'success', false,
    'error_code', v_reason,
    'error', CASE v_reason
      WHEN 'CODE_EXPIRED' THEN 'This connection code has expired (20 min limit). Please ask your partner for their updated code.'
      ELSE 'Invalid connection code. Please check the code and try again.'
    END
  );
END;
$$;
