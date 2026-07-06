# Persistent Relationship Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the relationship system into a Persistent Relationship Workspace where unlinking revokes access and clears local caches, but preserves all shared data, and recovery allows reconnecting using a formatted, secure recovery code.

**Architecture:** Database RLS and tables remain using `couple_id`/`couples` for Option 2, but adding status, partner, and hashed recovery lookup columns. RPC functions handle pairing, recovery, and unlinking atomically within transactions with rate-limiting and Blowfish/BCrypt hashing. Providers observe relationship ID transitions and resubscribe dynamically.

**Tech Stack:** Dart, Flutter, Supabase (PostgreSQL, PL/pgSQL, pgcrypto).

## Global Constraints
* Supabase is the single source of truth for relationship membership; do not cache active relationship ID in SharedPreferences.
* All RPCs run as single database transactions.
* Recovery codes must be hashed in the database using Blowfish/BCrypt and verified using an indexed lookup key.
* Realtime stream subscriptions must be cancelled before resubscribing.
* Clear plaintext recovery code from memory immediately after display.

---

### Task 1: Supabase Database Migration

**Files:**
- Create: `supabase/migrations/20260706000000_persistent_relationship_workspace.sql`

**Interfaces:**
- Produces: Database columns (`status`, `partner_a_id`, `partner_b_id`, `pairing_code`, `recovery_lookup_key`, `recovery_code_hash`), table `failed_recovery_attempts`, and RPC functions (`create_relationship_workspace`, `join_relationship_with_code`, `recover_relationship_with_code`, `regenerate_recovery_code`, `disconnect_relationship_workspace`).

- [ ] **Step 1: Write the migration script**
  Create `supabase/migrations/20260706000000_persistent_relationship_workspace.sql` with:
  ```sql
  -- Enable pgcrypto if not already enabled
  CREATE EXTENSION IF NOT EXISTS pgcrypto;

  -- 1. Create failed_recovery_attempts table for rate limiting
  CREATE TABLE IF NOT EXISTS public.failed_recovery_attempts (
    user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    attempts integer DEFAULT 0 NOT NULL,
    locked_until timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
  );

  -- Enable RLS on rate limit table
  ALTER TABLE public.failed_recovery_attempts ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "Enable select/update for system/authenticated users" ON public.failed_recovery_attempts FOR ALL USING (auth.uid() = user_id);

  -- 2. Alter couples table to support workspace state
  ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS status text DEFAULT 'waiting' NOT NULL;
  ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS partner_a_id uuid REFERENCES public.users(id) ON DELETE SET NULL;
  ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS partner_b_id uuid REFERENCES public.users(id) ON DELETE SET NULL;
  ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS pairing_code character varying(6) UNIQUE;
  ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS recovery_lookup_key text UNIQUE;
  ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS recovery_code_hash text;
  ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();

  CREATE UNIQUE INDEX IF NOT EXISTS couples_recovery_lookup_key_idx ON public.couples (recovery_lookup_key);

  -- 3. Populate existing couples from users table
  DO $$
  DECLARE
    r record;
    v_partner_a uuid;
    v_partner_b uuid;
  BEGIN
    FOR r IN SELECT DISTINCT couple_id FROM public.users WHERE couple_id IS NOT NULL LOOP
      SELECT id INTO v_partner_a FROM public.users WHERE couple_id = r.couple_id ORDER BY id ASC LIMIT 1;
      SELECT id INTO v_partner_b FROM public.users WHERE couple_id = r.couple_id ORDER BY id ASC LIMIT 1 OFFSET 1;

      UPDATE public.couples
      SET 
        partner_a_id = v_partner_a,
        partner_b_id = v_partner_b,
        status = CASE WHEN v_partner_b IS NOT NULL THEN 'active' ELSE 'waiting' END,
        updated_at = now()
      WHERE id = r.couple_id;
    END LOOP;
  END;
  $$;

  -- 4. Clean up users table
  ALTER TABLE public.users DROP COLUMN IF EXISTS partner_id;

  -- 5. Drop pairing_codes table
  DROP TABLE IF EXISTS public.pairing_codes CASCADE;

  -- 6. Redefine is_member_of_couple to verify workspace and active status
  CREATE OR REPLACE FUNCTION public.is_member_of_couple(couple_id uuid)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $$
  BEGIN
    RETURN EXISTS (
      SELECT 1 FROM public.users u
      JOIN public.couples c ON c.id = u.couple_id
      WHERE u.id = auth.uid()
        AND u.couple_id = is_member_of_couple.couple_id
        AND (c.partner_a_id = auth.uid() OR c.partner_b_id = auth.uid())
        AND c.status != 'archived'
    );
  END;
  $$;

  -- 7. Define create_relationship_workspace RPC
  CREATE OR REPLACE FUNCTION public.create_relationship_workspace()
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $$
  DECLARE
    v_couple_id uuid;
    v_pairing_code text;
    v_lookup_key text;
    v_secret text;
    v_secret_formatted text;
    v_secret_clean text;
    v_user_couple_id uuid;
    v_code_exists boolean;
    v_lookup_exists boolean;
    chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    i integer;
  BEGIN
    -- Lock caller row to prevent race conditions
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

    -- Insert couple row with Blowfish hash of the clean secret
    INSERT INTO public.couples (id, status, partner_a_id, pairing_code, recovery_lookup_key, recovery_code_hash, updated_at)
    VALUES (
      v_couple_id,
      'waiting',
      auth.uid(),
      v_pairing_code,
      v_lookup_key,
      crypt(v_secret_clean, gen_salt('bf', 10)),
      now()
    );

    -- Update user couple_id
    UPDATE public.users SET couple_id = v_couple_id WHERE id = auth.uid();

    RETURN json_build_object(
      'success', true,
      'couple_id', v_couple_id,
      'pairing_code', v_pairing_code,
      'recovery_code', v_lookup_key || '-' || v_secret_formatted
    );
  END;
  $$;

  -- 8. Define join_relationship_with_code RPC
  CREATE OR REPLACE FUNCTION public.join_relationship_with_code(p_pairing_code text)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $$
  DECLARE
    v_couple_row public.couples%ROWTYPE;
    v_user_couple_id uuid;
  BEGIN
    -- Lock caller row to prevent concurrent joins
    SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
    IF v_user_couple_id IS NOT NULL THEN
      RAISE EXCEPTION 'User is already in a relationship';
    END IF;

    -- Find and lock couples row
    SELECT * INTO v_couple_row
    FROM public.couples
    WHERE upper(pairing_code) = upper(trim(p_pairing_code))
      AND status = 'waiting'
      AND partner_b_id IS NULL
    FOR UPDATE;

    IF v_couple_row.id IS NULL THEN
      RAISE EXCEPTION 'Invalid or expired pairing code';
    END IF;

    IF v_couple_row.partner_a_id = auth.uid() THEN
      RAISE EXCEPTION 'Cannot pair with yourself';
    END IF;

    -- Update couple record
    UPDATE public.couples
    SET 
      partner_b_id = auth.uid(),
      status = 'active',
      pairing_code = NULL,
      updated_at = now()
    WHERE id = v_couple_row.id;

    -- Update user record
    UPDATE public.users
    SET couple_id = v_couple_row.id
    WHERE id = auth.uid();

    RETURN json_build_object(
      'success', true,
      'couple_id', v_couple_row.id,
      'partner_id', v_couple_row.partner_a_id
    );
  END;
  $$;

  -- 9. Define recover_relationship_with_code RPC
  CREATE OR REPLACE FUNCTION public.recover_relationship_with_code(p_recovery_code text)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $$
  DECLARE
    v_lookup_key text;
    v_secret text;
    v_secret_clean text;
    v_couple_id uuid;
    v_couple_row record;
    v_attempts integer;
    v_locked_until timestamp with time zone;
    v_user_couple_id uuid;
  BEGIN
    -- Lock user row
    SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
    IF v_user_couple_id IS NOT NULL THEN
      RAISE EXCEPTION 'User is already in a relationship';
    END IF;

    -- Check rate limiting
    SELECT attempts, locked_until INTO v_attempts, v_locked_until
    FROM public.failed_recovery_attempts
    WHERE user_id = auth.uid();

    IF v_locked_until IS NOT NULL AND v_locked_until > now() THEN
      RAISE EXCEPTION 'Too many failed attempts. Try again after %', v_locked_until;
    END IF;

    -- Parse lookup key and secret
    IF position('-' in p_recovery_code) = 0 THEN
      GOTO failed_attempt;
    END IF;

    v_lookup_key := upper(trim(split_part(p_recovery_code, '-', 1)));
    v_secret := split_part(p_recovery_code, '-', 2);
    -- Rejoin remaining parts in case secret has hyphens
    v_secret := v_secret || CASE WHEN position('-' in substr(p_recovery_code, position('-' in p_recovery_code) + 1)) > 0 THEN '-' || split_part(p_recovery_code, '-', 3) || '-' || split_part(p_recovery_code, '-', 4) || '-' || split_part(p_recovery_code, '-', 5) ELSE '' END;
    v_secret_clean := replace(v_secret, '-', '');

    -- Query couples using index on lookup key and lock it
    SELECT * INTO v_couple_row
    FROM public.couples
    WHERE recovery_lookup_key = v_lookup_key
    FOR UPDATE;

    IF v_couple_row.id IS NULL THEN
      GOTO failed_attempt;
    END IF;

    -- Verify BCrypt hash
    IF v_couple_row.recovery_code_hash != crypt(v_secret_clean, v_couple_row.recovery_code_hash) THEN
      GOTO failed_attempt;
    END IF;

    -- Validate ownership
    IF v_couple_row.partner_a_id != auth.uid() AND v_couple_row.partner_b_id != auth.uid() THEN
      GOTO failed_attempt;
    END IF;

    -- Success: Reset attempts, connect user, update workspace status
    INSERT INTO public.failed_recovery_attempts (user_id, attempts, locked_until)
    VALUES (auth.uid(), 0, NULL)
    ON CONFLICT (user_id) DO UPDATE SET attempts = 0, locked_until = NULL;

    UPDATE public.users SET couple_id = v_couple_row.id WHERE id = auth.uid();
    UPDATE public.couples SET status = 'active', updated_at = now() WHERE id = v_couple_row.id;

    RETURN json_build_object(
      'success', true,
      'couple_id', v_couple_row.id
    );

  <<failed_attempt>>
  BEGIN
    INSERT INTO public.failed_recovery_attempts (user_id, attempts, locked_until)
    VALUES (auth.uid(), 1, NULL)
    ON CONFLICT (user_id) DO UPDATE SET
      attempts = failed_recovery_attempts.attempts + 1,
      locked_until = CASE WHEN failed_recovery_attempts.attempts + 1 >= 5 THEN now() + interval '15 minutes' ELSE NULL END,
      updated_at = now();
      
    RAISE EXCEPTION 'Invalid recovery code';
  END;
  END;
  $$;

  -- 10. Define regenerate_recovery_code RPC
  CREATE OR REPLACE FUNCTION public.regenerate_recovery_code()
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $$
  DECLARE
    v_couple_id uuid;
    v_lookup_key text;
    v_secret_clean text;
    v_secret_formatted text;
    v_lookup_exists boolean;
    chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    i integer;
  BEGIN
    -- Lock user row
    SELECT couple_id INTO v_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
    IF v_couple_id IS NULL THEN
      RAISE EXCEPTION 'Not in a relationship';
    END IF;

    -- Lock couples row
    IF NOT EXISTS (
      SELECT 1 FROM public.couples WHERE id = v_couple_id AND (partner_a_id = auth.uid() OR partner_b_id = auth.uid()) FOR UPDATE
    ) THEN
      RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- Generate lookup key in retry loop
    LOOP
      v_lookup_key := '';
      FOR i IN 1..6 LOOP
        v_lookup_key := v_lookup_key || substr(chars, floor(random() * 36)::integer + 1, 1);
      END LOOP;

      SELECT EXISTS (SELECT 1 FROM public.couples WHERE recovery_lookup_key = v_lookup_key) INTO v_lookup_exists;
      IF NOT v_lookup_exists THEN
        EXIT;
      END IF;
    END LOOP;

    -- Generate 16-char secret key
    v_secret_clean := '';
    FOR i IN 1..16 LOOP
      v_secret_clean := v_secret_clean || substr(chars, floor(random() * 36)::integer + 1, 1);
    END LOOP;

    v_secret_formatted := substr(v_secret_clean, 1, 4) || '-' ||
                          substr(v_secret_clean, 5, 4) || '-' ||
                          substr(v_secret_clean, 9, 4) || '-' ||
                          substr(v_secret_clean, 13, 4);

    UPDATE public.couples
    SET 
      recovery_lookup_key = v_lookup_key,
      recovery_code_hash = crypt(v_secret_clean, gen_salt('bf', 10)),
      updated_at = now()
    WHERE id = v_couple_id;

    RETURN json_build_object(
      'success', true,
      'recovery_code', v_lookup_key || '-' || v_secret_formatted
    );
  END;
  $$;

  -- 11. Define disconnect_relationship_workspace RPC
  CREATE OR REPLACE FUNCTION public.disconnect_relationship_workspace()
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $$
  DECLARE
    v_couple_id uuid;
    v_other_connected boolean;
  BEGIN
    -- Lock caller user row
    SELECT couple_id INTO v_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
    IF v_couple_id IS NULL THEN
      RETURN json_build_object('success', false, 'error', 'Not in a relationship');
    END IF;

    -- Lock couple row
    PERFORM 1 FROM public.couples WHERE id = v_couple_id FOR UPDATE;

    -- Update user to null
    UPDATE public.users SET couple_id = NULL WHERE id = auth.uid();

    -- Check if other partner is still connected
    SELECT EXISTS (
      SELECT 1 FROM public.users 
      WHERE couple_id = v_couple_id AND id != auth.uid()
    ) INTO v_other_connected;

    IF NOT v_other_connected THEN
      UPDATE public.couples SET status = 'disconnected', updated_at = now() WHERE id = v_couple_id;
    ELSE
      UPDATE public.couples SET updated_at = now() WHERE id = v_couple_id;
    END IF;

    RETURN json_build_object('success', true);
  END;
  $$;
  ```

- [ ] **Step 2: Apply migration to Supabase**
  *Applying this migration script will create the database tables, adjust users columns, set up indexes, populate existing entries, and deploy the secure transaction-safe RPCs.*

- [ ] **Step 3: Commit**
  Run:
  ```powershell
  git add supabase/migrations/20260706000000_persistent_relationship_workspace.sql
  git commit -m "feat: add schema and secure RPCs for relationship workspace refactor"
  ```

---

### Task 2: Update Dart CoupleService

**Files:**
- Modify: `lib/services/couple_service.dart`

**Interfaces:**
- Consumes: Supabase database RPC signatures.
- Produces: `createRelationshipWorkspace()`, `joinWithCode()`, `recoverWithCode()`, `disconnectRelationshipWorkspace()`, `regenerateRecoveryCode()`.

- [ ] **Step 1: Implement the RPC mapping methods in CoupleService**
  Replace contents of `lib/services/couple_service.dart`:
  ```dart
  import 'package:supabase_flutter/supabase_flutter.dart';

  /// A service to encapsulate all relationship pairing, unlinking, and recovery transactions.
  class CoupleService {
    CoupleService._();

    /// The singleton instance of the CoupleService.
    static final CoupleService instance = CoupleService._();

    /// Creates a new relationship workspace.
    /// Returns a map containing 'couple_id', 'pairing_code', and 'recovery_code'.
    Future<Map<String, dynamic>> createRelationshipWorkspace() async {
      final response = await Supabase.instance.client.rpc(
        'create_relationship_workspace',
      );
      return Map<String, dynamic>.from(response);
    }

    /// Attempts to join a workspace using a 6-digit invitation code via Database RPC.
    Future<Map<String, dynamic>> joinWithCode(String code) async {
      final response = await Supabase.instance.client.rpc(
        'join_relationship_with_code',
        params: {'p_pairing_code': code},
      );
      return Map<String, dynamic>.from(response);
    }

    /// Reconnects a user to a workspace using a recovery code.
    Future<Map<String, dynamic>> recoverWithCode(String code) async {
      final response = await Supabase.instance.client.rpc(
        'recover_relationship_with_code',
        params: {'p_recovery_code': code},
      );
      return Map<String, dynamic>.from(response);
    }

    /// Regenerates a new recovery code for the workspace.
    Future<Map<String, dynamic>> regenerateRecoveryCode() async {
      final response = await Supabase.instance.client.rpc(
        'regenerate_recovery_code',
      );
      return Map<String, dynamic>.from(response);
    }

    /// Unlinks the current user, clearing workspace links in the database.
    Future<void> disconnectRelationshipWorkspace() async {
      await Supabase.instance.client.rpc(
        'disconnect_relationship_workspace',
      );
    }
  }
  ```

- [ ] **Step 2: Commit**
  Run:
  ```powershell
  git add lib/services/couple_service.dart
  git commit -m "feat: implement RPC wrappers in CoupleService"
  ```

---

### Task 3: Refactor RelationshipProvider

**Files:**
- Modify: `lib/providers/relationship_provider.dart`

**Interfaces:**
- Consumes: `CoupleService` wrappers.
- Produces: Updated state getters (`relationshipId`, `isLinked`, `partnerId`, `recoveryCode`). Exposes action methods: `createRelationshipWorkspace()`, `joinCouple(String code)`, `recoverRelationship(String code)`, `unlinkPartner()`, `regenerateRecoveryCode()`, `clearRecoveryCode()`.

- [ ] **Step 1: Update fields, stream, and startup flow**
  Modify properties and methods in `lib/providers/relationship_provider.dart` to load profile, unsubscribe cleanly, and avoid SharedPreferences storage for relationship membership.
  Specifically, inside `_initSupabaseSync()`, query the `users` table, and then query the `couples` table dynamically for `status`, `partner_a_id`, `partner_b_id`, and `pairing_code`.
  We must define helper getters:
  ```dart
  String? get relationshipId => _coupleId;
  String? get recoveryCode => _recoveryCode;
  RelationshipStatus get status => _status;
  
  // Clean up existing streams and subscriptions before creating new ones
  void _cancelActiveSubscriptions() {
    _supabaseSub?.cancel();
    _licenseSub?.cancel();
    _partnerUserSub?.cancel();
    _supabaseSub = null;
    _licenseSub = null;
    _partnerUserSub = null;
  }
  ```

- [ ] **Step 2: Implement create, join, recover, and disconnect methods**
  Inside `RelationshipProvider`:
  ```dart
  Future<void> createRelationshipWorkspace() async {
    _isGeneratingCode = true;
    notifyListeners();
    try {
      final result = await CoupleService.instance.createRelationshipWorkspace();
      _coupleId = result['couple_id'] as String;
      _coupleCode = result['pairing_code'] as String;
      _recoveryCode = result['recovery_code'] as String;
      _status = RelationshipStatus.waiting;
      _isPaired = false;
      notifyListeners();
    } finally {
      _isGeneratingCode = false;
      notifyListeners();
    }
  }

  Future<void> joinCouple(String code) async {
    _isJoining = true;
    notifyListeners();
    try {
      final result = await CoupleService.instance.joinWithCode(code);
      _coupleId = result['couple_id'] as String;
      _partnerId = result['partner_id'] as String;
      _isPaired = true;
      _status = RelationshipStatus.active;
      notifyListeners();
    } finally {
      _isJoining = false;
      notifyListeners();
    }
  }

  Future<void> recoverRelationship(String code) async {
    _isJoining = true;
    notifyListeners();
    try {
      final result = await CoupleService.instance.recoverWithCode(code);
      _coupleId = result['couple_id'] as String;
      // Initialize Sync stream to fetch status & partner IDs
      _initSupabaseSync();
    } finally {
      _isJoining = false;
      notifyListeners();
    }
  }

  Future<void> regenerateRecoveryCode() async {
    final result = await CoupleService.instance.regenerateRecoveryCode();
    _recoveryCode = result['recovery_code'] as String;
    notifyListeners();
  }

  void clearRecoveryCode() {
    _recoveryCode = null;
    notifyListeners();
  }

  Future<void> unlinkPartner() async {
    if (_isUnlinking) return;
    _isUnlinking = true;
    notifyListeners();
    try {
      await CoupleService.instance.disconnectRelationshipWorkspace();
      _cancelActiveSubscriptions();
      _coupleId = null;
      _partnerId = null;
      _isPaired = false;
      _status = RelationshipStatus.disconnected;
      
      // Clear local memory UI caches for privacy
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('partner_name');
      await prefs.remove('partner_avatar_path');
    } finally {
      _isUnlinking = false;
      notifyListeners();
    }
  }
  ```

- [ ] **Step 3: Commit**
  Run:
  ```powershell
  git add lib/providers/relationship_provider.dart
  git commit -m "feat: refactor RelationshipProvider with workspace support"
  ```

---

### Task 4: Refactor Proxy Providers

**Files:**
- Modify: `lib/providers/love_chat_provider.dart`, `lib/providers/bucket_list_provider.dart`, `lib/providers/timeline_provider.dart`, `lib/providers/daily_mood_provider.dart`, `lib/providers/calendar_provider.dart`, `lib/providers/gift_reminder_provider.dart`, `lib/providers/vault_provider.dart`, `lib/providers/topic_cards_provider.dart`, `lib/providers/noteit_provider.dart`, `lib/providers/currently_provider.dart`, `lib/providers/notification_preferences_provider.dart`

**Interfaces:**
- Consumes: `RelationshipProvider` updates.

- [ ] **Step 1: Refactor updateRelationship in all feature providers**
  Ensure that every provider cancels its stream subscription and resubscribes cleanly on *any* change to `relationship.relationshipId` (whether null-to-id, id-to-null, or id-to-new-id):
  Example for `BucketListProvider` (do similarly for others):
  ```dart
  void updateRelationship(RelationshipProvider relationship) {
    final bool credentialsChanged = _coupleId != relationship.relationshipId || _userId != relationship.userId;
    final bool shouldSubscribe = _syncSub == null && relationship.relationshipId != null && relationship.userId != null && relationship.isFirebaseAvailable;

    if (credentialsChanged || shouldSubscribe) {
      _coupleId = relationship.relationshipId;
      _userId = relationship.userId;

      _syncSub?.cancel();
      _syncSub = null;

      if (_coupleId != null && _userId != null && relationship.isFirebaseAvailable) {
        _initSupabaseSync();
        _fetchInitialData();
      } else {
        _clearLocalCache();
      }
    }
  }
  ```

- [ ] **Step 2: Commit**
  Run:
  ```powershell
  git add lib/providers/*.dart
  git commit -m "feat: refactor proxy providers to dynamically resubscribe on relationship changes"
  ```

---

### Task 5: Refactor Onboarding & Settings UI

**Files:**
- Create: `lib/screens/onboarding/recover_relationship_screen.dart`
- Modify: `lib/screens/onboarding/pairing_selection_screen.dart`, `lib/screens/onboarding/create_couple_code_screen.dart`, `lib/screens/settings/relationship_profile_screen.dart`

- [ ] **Step 1: Create RecoverRelationshipScreen**
  Create a new screen with a TextField to enter the formatted recovery code, showing errors/rate-limiting lockout state.
- [ ] **Step 2: Refactor PairingSelectionScreen**
  Update the cards to show descriptions:
  - Create: *"Start a new shared relationship workspace."*
  - Join: *"Connect to your partner's newly created workspace."*
  - Recover: *"Reconnect to a workspace you previously belonged to."* (navigates to `RecoverRelationshipScreen`).
- [ ] **Step 3: Update CreateCoupleCodeScreen and Settings Dialogs**
  Add the copy-and-confirm checkbox verification dialog for recovery codes so they cannot be dismissed until confirmed.
- [ ] **Step 4: Commit**
  Run:
  ```powershell
  git add lib/screens/onboarding/*.dart lib/screens/settings/*.dart
  git commit -m "feat: update onboarding UI screens and recovery code confirmation flow"
  ```
