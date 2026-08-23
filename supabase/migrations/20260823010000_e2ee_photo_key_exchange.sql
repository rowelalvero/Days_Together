-- Migration: End-to-end photo encryption -- key exchange schema
-- Created: 2026-08-23
--
-- Adds the schema needed for X25519 ECDH key exchange between the two
-- partners in a couple, so an AES-256 "couple photo key" (used to
-- encrypt/decrypt uploaded photos client-side) can be wrapped for one
-- partner's device and only that device's private key -- which never
-- leaves it -- can unwrap it. This closes the one gap private buckets +
-- signed URLs cannot: `service_role` (the project admin) bypasses RLS
-- entirely, so today it can read every stored photo's plaintext bytes.
-- After this feature ships, it can only read ciphertext.
--
-- See lib/services/key_management_service.dart and
-- lib/services/photo_encryption_service.dart (already shipped, unit-tested,
-- pure-Dart -- no schema dependency) for the crypto this schema supports.
--
-- ROLLBACK
--   DROP FUNCTION IF EXISTS public.store_wrapped_key(uuid, text);
--   DROP TABLE IF EXISTS public.couple_key_exchanges;
--   ALTER TABLE public.users DROP COLUMN IF EXISTS public_key;
--   (Then re-create create_relationship_workspace/join_relationship_with_code/
--   recover_relationship_with_code from their pre-this-migration definitions,
--   i.e. 20260822000000, 20260808000003, 20260808000001 respectively.)


-- =====================================================================
-- 1. users.public_key -- each device's X25519 public key (not secret)
-- =====================================================================
-- Base64-encoded 32 raw bytes. Readable by self and partner via the
-- existing "Enable select for self and partner" policy
-- (20260808000000_security_remediation.sql) -- that policy already grants
-- partner-row SELECT, which is exactly what's needed here: a partner must
-- read the other's public key to wrap a key for them.
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS public_key text;


-- =====================================================================
-- 2. couple_key_exchanges -- one wrapped couple-photo-key per recipient
-- =====================================================================
-- A row per (couple, recipient): the couple photo key, AES-GCM-wrapped
-- under a KEK derived from X25519(sender_private_key, recipient_public_key).
-- Only that one recipient's private key can unwrap it. A dedicated table
-- (rather than couples-table columns) is what lets recovery/re-key simply
-- overwrite this recipient's row, with no schema change needed per
-- replacement.
CREATE TABLE IF NOT EXISTS public.couple_key_exchanges (
  couple_id uuid NOT NULL REFERENCES public.couples(id) ON DELETE CASCADE,
  recipient_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wrapped_key text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (couple_id, recipient_user_id)
);

CREATE INDEX IF NOT EXISTS couple_key_exchanges_recipient_idx
  ON public.couple_key_exchanges (recipient_user_id);

ALTER TABLE public.couple_key_exchanges ENABLE ROW LEVEL SECURITY;

-- Only the recipient may ever read their own wrapped key. No INSERT/UPDATE/
-- DELETE policy is defined at all -- RLS default-denies every write from a
-- plain authenticated client, so all writes must go through
-- store_wrapped_key() below (SECURITY DEFINER, runs as table owner, which
-- bypasses RLS -- the same pattern that already lets
-- create_relationship_workspace() insert into public.couples despite its
-- own "Deny direct insert" policy).
DROP POLICY IF EXISTS "Enable select for own wrapped key" ON public.couple_key_exchanges;
CREATE POLICY "Enable select for own wrapped key" ON public.couple_key_exchanges
  FOR SELECT TO authenticated
  USING (recipient_user_id = auth.uid());

ALTER PUBLICATION supabase_realtime ADD TABLE public.couple_key_exchanges;


-- =====================================================================
-- 3. store_wrapped_key RPC -- the only way to write couple_key_exchanges
-- =====================================================================
-- Validates that the caller and the recipient are both members of the same
-- couple before upserting, so a caller can never plant a wrapped key for
-- someone outside their own relationship.
CREATE OR REPLACE FUNCTION public.store_wrapped_key(
  p_recipient_id uuid,
  p_wrapped_key text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_caller_couple_id uuid;
  v_recipient_couple_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF p_wrapped_key IS NULL OR length(trim(p_wrapped_key)) = 0 THEN
    RAISE EXCEPTION 'wrapped key must not be empty';
  END IF;

  SELECT couple_id INTO v_caller_couple_id FROM public.users WHERE id = auth.uid();
  IF v_caller_couple_id IS NULL THEN
    RAISE EXCEPTION 'Caller is not in a relationship workspace';
  END IF;

  SELECT couple_id INTO v_recipient_couple_id FROM public.users WHERE id = p_recipient_id;
  IF v_recipient_couple_id IS NULL OR v_recipient_couple_id != v_caller_couple_id THEN
    RAISE EXCEPTION 'Recipient is not your partner in this relationship';
  END IF;

  INSERT INTO public.couple_key_exchanges (couple_id, recipient_user_id, wrapped_key, updated_at)
  VALUES (v_caller_couple_id, p_recipient_id, p_wrapped_key, now())
  ON CONFLICT (couple_id, recipient_user_id)
  DO UPDATE SET wrapped_key = EXCLUDED.wrapped_key, updated_at = now();

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.store_wrapped_key(uuid, text) TO authenticated;


-- =====================================================================
-- 4. Pairing RPCs gain a p_public_key param, written atomically alongside
--    the existing couple_id / partner_*_id assignment.
-- =====================================================================
-- Each of these three functions is being given a new parameter, which
-- changes its signature -- CREATE OR REPLACE cannot update a function's
-- parameter list, so the old signature must be dropped first (this is the
-- exact same reason 20260820000000_protect_couple_id.sql had to DROP
-- join_couple_with_code(text) instead of replacing it).
-- p_public_key defaults to NULL so a not-yet-rebuilt client calling without
-- it still works (pairing succeeds; that device's key exchange completes
-- later, whenever it next posts its public key).

-- 4a. create_relationship_workspace() -- exact prior body from
-- 20260822000000_fix_create_relationship_workspace_search_path.sql, plus
-- p_public_key.
DROP FUNCTION IF EXISTS public.create_relationship_workspace();

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
  v_code_exists boolean;
  v_lookup_exists boolean;
  chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  i integer;
BEGIN
  -- Lock caller row to prevent concurrent updates
  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  v_couple_id := gen_random_uuid();

  -- Retry loop to generate unique codes
  LOOP
    v_pairing_code := '';
    FOR i IN 1..6 LOOP
      v_pairing_code := v_pairing_code || substr(chars, floor(random() * 36)::integer + 1, 1);
    END LOOP;

    v_lookup_key := '';
    FOR i IN 1..6 LOOP
      v_lookup_key := v_lookup_key || substr(chars, floor(random() * 36)::integer + 1, 1);
    END LOOP;

    SELECT EXISTS(SELECT 1 FROM public.couples WHERE pairing_code = v_pairing_code) INTO v_code_exists;
    SELECT EXISTS(SELECT 1 FROM public.couples WHERE recovery_lookup_key = v_lookup_key) INTO v_lookup_exists;

    IF NOT v_code_exists AND NOT v_lookup_exists THEN
      EXIT;
    END IF;
  END LOOP;

  -- Generate 16-char secret key grouped with hyphens
  v_secret_clean := '';
  FOR i IN 1..16 LOOP
    v_secret_clean := v_secret_clean || substr(chars, floor(random() * 36)::integer + 1, 1);
  END LOOP;

  v_secret_formatted := substr(v_secret_clean, 1, 4) || '-' ||
                        substr(v_secret_clean, 5, 4) || '-' ||
                        substr(v_secret_clean, 9, 4) || '-' ||
                        substr(v_secret_clean, 13, 4);

  -- Insert couple row
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

-- 4b. join_relationship_with_code(p_pairing_code) -- exact prior body from
-- 20260808000003_pairing_code_rotation.sql, plus p_public_key.
DROP FUNCTION IF EXISTS public.join_relationship_with_code(text);

CREATE OR REPLACE FUNCTION public.join_relationship_with_code(
  p_pairing_code text,
  p_public_key text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_couple_row public.couples%ROWTYPE;
  v_user_couple_id uuid;
BEGIN
  -- Lock caller row to prevent race conditions
  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  -- Find and lock couples row matching code and waiting status
  SELECT * INTO v_couple_row
  FROM public.couples
  WHERE upper(pairing_code) = upper(trim(p_pairing_code))
    AND status = 'waiting'
    AND partner_b_id IS NULL
  FOR UPDATE;

  IF v_couple_row.id IS NULL THEN
    RAISE EXCEPTION 'Invalid connection code. Please check the code and try again.';
  END IF;

  IF v_couple_row.partner_a_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot pair with yourself';
  END IF;

  -- Enforce 20-minute expiration limit
  IF v_couple_row.pairing_code_updated_at IS NOT NULL AND (now() - v_couple_row.pairing_code_updated_at) > interval '20 minutes' THEN
    RAISE EXCEPTION 'This connection code has expired (20 min limit). Please ask your partner for their updated code.';
  END IF;

  -- Update couple record to active, clear pairing_code upon successful pairing
  UPDATE public.couples
  SET
    partner_b_id = auth.uid(),
    status = 'active',
    pairing_code = NULL
  WHERE id = v_couple_row.id;

  -- Update user record: couple_id and public key together
  UPDATE public.users
  SET couple_id = v_couple_row.id, public_key = COALESCE(p_public_key, public_key)
  WHERE id = auth.uid();

  RETURN json_build_object(
    'success', true,
    'couple_id', v_couple_row.id,
    'partner_id', v_couple_row.partner_a_id
  );
END;
$$;

-- 4c. recover_relationship_with_code(p_recovery_code) -- exact prior body
-- from 20260808000001_recovery_hardening.sql, plus p_public_key. A
-- recovering device's fresh keypair needs to be posted the moment it claims
-- a slot -- the surviving partner re-wraps the couple key for it once online
-- (Stage 3 wiring), since recovery is a slot replacement, not identity
-- restoration: it cannot recover the lost private key, only replace it.
DROP FUNCTION IF EXISTS public.recover_relationship_with_code(text);

CREATE OR REPLACE FUNCTION public.recover_relationship_with_code(
  p_recovery_code text,
  p_public_key text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_code_clean text;
  v_first_hyphen_pos integer;
  v_lookup_key text;
  v_secret text;
  v_secret_clean text;
  v_couple_row record;
  v_user_email text;
  v_success boolean := false;
  v_assigned_slot text;
  v_user_attempts record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND couple_id IS NOT NULL) THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  -- Layer 1: Check Per-User Rate Limit (Audit H-5)
  SELECT * INTO v_user_attempts FROM public.user_recovery_attempts WHERE user_id = auth.uid();
  IF v_user_attempts.locked_until IS NOT NULL AND v_user_attempts.locked_until > now() THEN
    RAISE EXCEPTION 'Too many failed recovery attempts from this account. Try again after %',
      to_char(v_user_attempts.locked_until, 'HH24:MI:SS');
  END IF;

  v_code_clean := upper(trim(p_recovery_code));
  v_first_hyphen_pos := position('-' in v_code_clean);

  IF v_first_hyphen_pos > 1 THEN
    v_lookup_key := substr(v_code_clean, 1, v_first_hyphen_pos - 1);
    v_secret := substr(v_code_clean, v_first_hyphen_pos + 1);
    v_secret_clean := replace(v_secret, '-', '');

    SELECT * INTO v_couple_row
    FROM public.couples
    WHERE recovery_lookup_key = v_lookup_key
    FOR UPDATE;

    IF v_couple_row.id IS NOT NULL THEN
      -- Layer 2: Check Per-Couple Rate Limit
      IF v_couple_row.recovery_locked_until IS NOT NULL
         AND v_couple_row.recovery_locked_until > now() THEN
        RAISE EXCEPTION 'Too many failed attempts on this recovery key. Try again after %',
          to_char(v_couple_row.recovery_locked_until, 'HH24:MI:SS');
      END IF;

      -- Check Expiration (90 Days - Audit H-3)
      IF v_couple_row.recovery_code_generated_at IS NOT NULL
         AND v_couple_row.recovery_code_generated_at < (now() - interval '90 days') THEN
        RAISE EXCEPTION 'Recovery code has expired (valid for 90 days). Request a new recovery code.';
      END IF;

      -- Verify Bcrypt Hash
      IF v_couple_row.recovery_code_hash = crypt(v_secret_clean, v_couple_row.recovery_code_hash) THEN
        v_success := true;
        -- Reset per-couple rate limit on success
        UPDATE public.couples
        SET failed_recovery_attempts = 0, recovery_locked_until = NULL
        WHERE id = v_couple_row.id;
      ELSE
        -- Increment per-couple rate limit
        UPDATE public.couples
        SET
          failed_recovery_attempts = COALESCE(v_couple_row.failed_recovery_attempts, 0) + 1,
          recovery_locked_until = CASE
            WHEN COALESCE(v_couple_row.failed_recovery_attempts, 0) + 1 >= 5
            THEN now() + interval '15 minutes'
            ELSE NULL
          END
        WHERE id = v_couple_row.id;
      END IF;
    END IF;
  END IF;

  IF NOT v_success THEN
    -- Increment per-user rate limit on failure (Audit H-5)
    INSERT INTO public.user_recovery_attempts (user_id, failed_attempts, locked_until)
    VALUES (auth.uid(), 1, NULL)
    ON CONFLICT (user_id) DO UPDATE SET
      failed_attempts = public.user_recovery_attempts.failed_attempts + 1,
      locked_until = CASE
        WHEN public.user_recovery_attempts.failed_attempts + 1 >= 5 THEN now() + interval '15 minutes'
        ELSE NULL
      END;

    RAISE EXCEPTION 'Invalid recovery code';
  END IF;

  -- Reset per-user rate limit on success
  UPDATE public.user_recovery_attempts
  SET failed_attempts = 0, locked_until = NULL
  WHERE user_id = auth.uid();

  SELECT email INTO v_user_email FROM auth.users WHERE id = auth.uid();

  -- Deterministic Assignment via Recorded Emails
  IF v_couple_row.partner_a_email = v_user_email THEN
    UPDATE public.couples SET partner_a_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    v_assigned_slot := 'partner_a';
  ELSIF v_couple_row.partner_b_email = v_user_email THEN
    UPDATE public.couples SET partner_b_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    v_assigned_slot := 'partner_b';
  ELSE
    IF v_couple_row.partner_a_id IS NULL THEN
      UPDATE public.couples SET partner_a_id = auth.uid(), partner_a_email = v_user_email, status = 'active' WHERE id = v_couple_row.id;
      v_assigned_slot := 'partner_a';
    ELSIF v_couple_row.partner_b_id IS NULL THEN
      UPDATE public.couples SET partner_b_id = auth.uid(), partner_b_email = v_user_email, status = 'active' WHERE id = v_couple_row.id;
      v_assigned_slot := 'partner_b';
    ELSE
      RAISE EXCEPTION 'No vacant slot available in this relationship workspace';
    END IF;
  END IF;

  -- A recovering device always gets a *fresh* keypair (it lost the old one --
  -- that is the entire premise of recovery), so public_key is overwritten
  -- outright here rather than COALESCE-preserved like the create/join RPCs.
  UPDATE public.users SET couple_id = v_couple_row.id, public_key = p_public_key WHERE id = auth.uid();

  RETURN json_build_object('success', true, 'couple_id', v_couple_row.id, 'slot', v_assigned_slot);
END;
$$;
