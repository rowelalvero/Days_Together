# Persistent Relationship Workspace Design Spec

## 1. Goal & Context
The goal is to redesign the relationship system from a temporary link between two users into a permanent, shared **Relationship Workspace**. Unlinking will no longer delete shared relationship data; it will only remove the user's active association (revoking their workspace access) and clear local caches for privacy. Reconnecting (via Pairing or Recovery) will restore the complete workspace, including all shared features, caches, and realtime listeners.

Supabase is the single source of truth for relationship membership. The database schema keeps the `couples` table name and `couple_id` foreign keys to minimize migration risk, but we expose the concept as `Relationship` and `Relationship Workspace` in the Flutter application.

---

## 2. Database Schema Modifications & Migration

### Schema Additions to `couples` table
We will run a migration to add columns to the `couples` table for workspace lifecycle, partner tracking, pairing, and recovery:
1. `status` (text, default `'waiting'`): Tracks the state of the workspace (`waiting`, `active`, `disconnected`, `archived`).
2. `partner_a_id` (uuid, references `users(id)` ON DELETE SET NULL, nullable): The partner who created the workspace.
3. `partner_b_id` (uuid, references `users(id)` ON DELETE SET NULL, nullable): The partner who joined the workspace.
4. `pairing_code` (character varying(6), unique, nullable): Temporary code used for pairing the second partner.
5. `recovery_lookup_key` (text, unique, nullable): A unique indexed lookup key to quickly locate a candidate relationship without doing database-wide BCrypt operations.
6. `recovery_code_hash` (text, nullable): BCrypt hash of the cryptographically random recovery secret.
7. `updated_at` (timestamp with time zone, default `now()`).

We will create a unique index on `recovery_lookup_key` to ensure lookup speed:
```sql
CREATE UNIQUE INDEX IF NOT EXISTS couples_recovery_lookup_key_idx ON public.couples (recovery_lookup_key);
```

### Clean Up and Migrate Existing Data
We will migrate existing production data safely without data loss:
1. Extract existing relationships from the `users` table:
   * For each unique non-null `couple_id` in `users`, find the users sharing it.
   * Assign the first user as `partner_a_id` and the second user (if any) as `partner_b_id` in the corresponding row in `couples`.
   * Set `status` to `'active'` if there are two partners, and `'waiting'` if there is only one partner.
2. Drop the `partner_id` column from the `users` table to eliminate duplicated state.
3. Drop the `pairing_codes` table since pairing codes will reside directly on `couples`.

### Security & Rate Limiting
To protect against brute-force recovery attempts, we will introduce a table for tracking failed recovery attempts:
```sql
CREATE TABLE public.failed_recovery_attempts (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  attempts integer DEFAULT 0 NOT NULL,
  locked_until timestamp with time zone,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);
```

---

## 3. Supabase RPC Function Definitions
All RPC functions will run inside a single database transaction. If any check fails, a `RAISE EXCEPTION` is called to roll back all changes.

### A. `create_relationship_workspace()`
1. Verifies that the authenticated user (`auth.uid()`) is not already connected to a relationship (`users.couple_id` is NULL). Otherwise, throws `'User is already in a relationship'`.
2. Generates a new `couple_id` (UUID).
3. Generates a short, unique 6-character uppercase `pairing_code`.
4. Generates a 6-character random uppercase alphanumeric `recovery_lookup_key` (e.g. `ABC123`).
5. Generates a secure, cryptographically random 16-character uppercase alphanumeric `recovery_secret` formatted for readability: `RVT7-H9MK-PQ82-JXW5`.
6. Hashes the recovery secret (with hyphens stripped: `RVT7H9MKPQ82JXW5`) using Blowfish/BCrypt: `crypt(stripped_secret, gen_salt('bf', 10))` and stores it in `recovery_code_hash`.
7. Inserts a row in `couples` with `status = 'waiting'`, `partner_a_id = auth.uid()`, `pairing_code`, `recovery_lookup_key`, and `recovery_code_hash`.
8. Sets the calling user's `couple_id = new_id` in `users`.
9. Returns the UUID, the pairing code, and the **plaintext combined recovery code** `[recovery_lookup_key]-[recovery_secret]` (e.g., `ABC123-RVT7-H9MK-PQ82-JXW5`) which will only be displayed once in the UI.

### B. `join_relationship_with_code(p_pairing_code text)`
1. Verifies that the authenticated user (`auth.uid()`) is not already connected to a relationship (`users.couple_id` is NULL). Otherwise, throws `'User is already in a relationship'`.
2. Finds and locks (using `FOR UPDATE`) the candidate `couples` row matching `p_pairing_code` (case-insensitive) where `status = 'waiting'` and `partner_b_id IS NULL`.
3. If no row is locked/found, throws an error `'Invalid or expired pairing code'`.
4. Verifies that the joiner is authenticated and is not the creator (`partner_a_id`).
5. Updates the locked `couples` record:
   * Sets `partner_b_id = auth.uid()`
   * Sets `status = 'active'`
   * Sets `pairing_code = NULL` (invalidates pairing code immediately).
6. Updates the joiner's profile in `users`: `couple_id = couples.id`.
7. Returns the workspace UUID and the creator's ID.

### C. `recover_relationship_with_code(p_recovery_code text)`
1. Verifies that the authenticated user (`auth.uid()`) is not already connected to a relationship (`users.couple_id` is NULL). Otherwise, throws `'User is already in a relationship'`.
2. Check rate limits:
   * Check if the authenticated user (`auth.uid()`) is currently locked out in `failed_recovery_attempts`. If so, throw an error with the cooldown remaining.
3. Parse Recovery Code:
   * Splits `p_recovery_code` on the first hyphen (`-`) into `v_lookup_key` and `v_secret`.
   * Strips all hyphens from the secret portion: `v_secret_clean := replace(v_secret, '-', '')`.
   * If the input is invalid (no hyphen or empty components), increments failed attempts and throws `'Invalid recovery code'`.
4. Search using index:
   * Queries the `couples` table for the row matching `recovery_lookup_key = upper(trim(v_lookup_key))`.
   * If no row is found, increments failed attempts and throws `'Invalid recovery code'`.
5. BCrypt Verification:
   * Verifies the clean secret against the stored hash: `recovery_code_hash = crypt(v_secret_clean, recovery_code_hash)`.
   * If it does not match, increments failed attempts and throws `'Invalid recovery code'`.
6. Validate ownership:
   * Verify that `auth.uid()` matches either `partner_a_id` or `partner_b_id` of the matched workspace.
   * If it does not match, increment failed attempts and throw an error `'Invalid recovery code'`.
7. Successful recovery:
   * Reset the rate limit stats.
   * Reconnect the user: set `users.couple_id = couples.id`.
   * Set `couples.status = 'active'`.
   * Return the workspace UUID.

### D. `regenerate_recovery_code()`
1. Verifies the authenticated user is currently active in a relationship (`users.couple_id` is non-null).
2. Generates a new `recovery_lookup_key` (6-char) and a new hyphen-grouped `recovery_secret` (16-char formatted as `XXXX-XXXX-XXXX-XXXX`).
3. Hashes the stripped secret via BCrypt and updates `recovery_lookup_key` and `recovery_code_hash` on the active relationship.
4. Returns the plaintext combined recovery code `[lookup_key]-[secret]` to display once in the UI.

### E. `disconnect_relationship_workspace()`
1. Finds the caller's active relationship in `couples`.
2. Sets the caller's `users.couple_id = NULL`.
3. Checks if the other partner is also disconnected (i.e. the other partner's `users.couple_id IS NULL` in the `users` table).
   * If both partners are disconnected, sets `couples.status = 'disconnected'`.
   * If the other partner is still connected, `couples.status` remains `'active'`.

---

## 4. Failure Recovery & Transactions
Every RPC function executes within a single database transaction. 
* If any error, ownership violation, or validation check fails, a `RAISE EXCEPTION` is triggered.
* PostgreSQL automatically aborts the active transaction and performs a full rollback.
* No partial states are written: the `users`, `couples`, and feature tables are guaranteed to remain completely unchanged if the transaction fails.

---

## 5. Flutter Provider & State Management Architecture

### Initialization Order
1. Authenticate user.
2. Load relationship status from Supabase (`users.couple_id`).
3. Update `RelationshipProvider` properties (`coupleId`, `partnerId`, `isLinked`, `status`).
4. Set `isInitialized = true` and call `notifyListeners()`.
5. Rebuild proxy providers (automatically triggered by `ChangeNotifierProxyProvider`).
6. Cancel existing realtime subscriptions and restore them for the new relationship ID.
7. Fetch initial data.
8. Rebuild UI with the updated data.

### Subscription Safety
Before creating any new realtime subscription during startup, pairing, or recovery:
```dart
_syncSub?.cancel();
_syncSub = null;
```
This avoids duplicate listeners and memory leaks.

---

## 6. UI Changes & Onboarding

### Refactored `PairingSelectionScreen`
Provides clear explanations for all three options:
* **Create Relationship**: *"Start a new shared relationship workspace."*
* **Join with Pairing Code**: *"Connect to your partner's newly created workspace."*
* **Recover Existing Relationship**: *"Reconnect to a workspace you previously belonged to."*

### Onboarding / Regeneration Recovery Code Dialog
When a recovery code is generated/regenerated:
1. Shows the code clearly (e.g., `ABC123-RVT7-H9MK-PQ82-JXW5`).
2. Provides a **Copy** button.
3. Displays a warning: *"⚠️ This code will never be shown again."*
4. Includes a checkbox: **"I have saved my recovery code."**
5. Disables the **Continue** / **Dismiss** button until the checkbox is checked.
6. Once dismissed, calls `relationshipProvider.clearRecoveryCode()` to wipe the plaintext code from memory immediately.

---

## 7. Implementation Roadmap & Dependency Order

To ensure the refactor is incremental, reviewable, and keeps the project buildable, we will execute in the following sequence:

| Phase | Files Affected | Description | Migration / Compatibility Concerns |
|---|---|---|---|
| **Phase 1: DB Migration** | `supabase/migrations/20260706000000_persistent_relationship_workspace.sql` | Expose status, partner IDs, lookup keys, hashes, and implement secure RPC functions. | Safe SQL block. Relies on `pgcrypto` to hash and verify codes. |
| **Phase 2: Services** | `lib/services/couple_service.dart` | Expose the new RPCs (`join_relationship_with_code`, `recover_relationship_with_code`, `disconnect_relationship_workspace`, `regenerate_recovery_code`). | Kept fully backward compatible. |
| **Phase 3: Core Provider** | `lib/providers/relationship_provider.dart` | Refactor state variables, implement safe streams, handle recovery code memory, and load state only from Supabase profile. | Remove `partner_id` DB read, query `couples` table details instead. |
| **Phase 4: Proxy Providers** | All 11 shared feature providers (Chat, Memories, etc.) | Update `updateRelationship` methods to handle dynamic transitions, cancel existing subscriptions before subscribing, and clear local caches. | Ensure no memory leaks when switching states. |
| **Phase 5: UI Screens** | `PairingSelectionScreen.dart`, `CreateCoupleCodeScreen.dart`, `JoinCoupleCodeScreen.dart`, `RecoverRelationshipScreen.dart` [NEW], `RelationshipProfileScreen.dart` | Add descriptions, copy/confirm dialog, recovery screen, and regenerate recovery code option. | None. |
| **Phase 6: Verification** | Test suites, manual validation | Verify pairing, disconnection, and recovery restoration. | Ensure all shared data is preserved. |
