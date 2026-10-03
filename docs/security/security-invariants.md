# Security invariant register

Each invariant is enforced by the database (or, where it cannot be, by the
client) and pinned by a test. Every invariant that PostgreSQL can enforce has a
pgTAP test under `supabase/tests/`, run with:

```bash
supabase start          # once
supabase db reset       # apply every migration from scratch
supabase test db        # run the pgTAP suite
```

Status reflects the repository after remediation Phase 2 (2026-10-03).
"TODO" means the test exists and runs, marked as a pgTAP TODO: it reports the
known failure without failing the suite, and flips to a passing test the
moment the fix lands.

| ID  | Invariant | Status | Enforced by | Test |
|-----|-----------|--------|-------------|------|
| S01 | Anonymous users cannot execute relationship RPCs; authenticated users can execute only the RPC allowlist. | Enforced | `20261003000100_rpc_privilege_model.sql`, auth guards in `20261003000200` | `001_rpc_privileges.sql` |
| S02 | Users cannot join arbitrary couples by modifying `users.couple_id`. | Enforced | `protect_users_couple_id` trigger (`20260820000000`) | `002_cross_couple_rls.sql`, `006_unlink.sql` |
| S03 | Pairing attempts are rate-limited server-side, and failed attempts persist. | Enforced | `join_relationship_with_code` (`20261003000200`) | `003_pairing.sql` |
| S04 | Pairing and recovery codes use cryptographically secure randomness. | Enforced (no `public` function uses `random()`) | `generate_secure_code` (`20261003000200`), `20261003010200` | `003_pairing.sql`, `005_recovery.sql` |
| S05 | Successful pairing invalidates the pairing credential; concurrent joins cannot both win. | Enforced | conditional slot claim in `join_relationship_with_code` | `003_pairing.sql`, `004_pairing_race.sql` |
| S06 | Unlink invalidates previous recovery authority; re-entry needs a code the remaining partner regenerates afterwards. | Enforced | `20261003010000_unlink_invalidates_recovery.sql` | `006_unlink.sql` |
| S07 | Recovery codes expire from their latest generation time; regeneration clears the lockout and kills the old code. | Enforced | `20261003010200_regenerate_recovery_code_validity.sql` | `005_recovery.sql` |
| S08 | Users cannot modify relationship security fields directly (clients may update only `story_title`, `start_date`, `start_time_hour`, `start_time_minute`). | Enforced | column grants, `20261003010300_couples_mutation_boundary.sql` | `010_couples_mutation.sql` |
| S09 | Users cannot delete a couple directly. | Enforced | `20261003010300` | `010_couples_mutation.sql` |
| S10 | Users cannot mutate another user's FCM token. | Enforced | `20261003000300_fcm_token_ownership.sql` | `008_fcm_tokens.sql` |
| S11 | Local account data cannot cross authenticated identities. | Enforced (client) | `SessionDataWiper` on logout, auth session gone, account switch, deletion; couple scope on unlink | `test/account_isolation_test.dart`, `test/session_data_wiper_test.dart` |
| S12 | Logout unregisters the device's FCM token before losing authorization; the next account always re-registers. | Enforced. Residual: on a server-side revocation (no JWT left) the token stays with the old account until the next sign-in takes it over. | `CoupleSession.logout`, per-user sync state in `NotificationService` | `test/account_isolation_test.dart`, `supabase/tests/008_fcm_tokens.sql` |
| S13 | Cross-couple feature data remains inaccessible through RLS. | Enforced | `is_member_of_couple` policies | `002_cross_couple_rls.sql` |
| S14 | Storage objects require authenticated couple membership. | Enforced in migrations. The **remote** project must still be verified (see `manual-actions.md`). | `20261003000000_enforce_private_storage_buckets.sql` + couple-path storage policies | `009_storage.sql` |

Not numbered above but also pinned:

- **Account deletion (F-08)**: any user, including a couple's only or last
  remaining member, can delete their account
  (`20261003010100_fix_last_member_account_deletion.sql`,
  `007_account_deletion.sql`). The couple's storage objects are not removed
  yet: Phase 7, F-21, a TODO in the same file.
- **Email-independent slots (F-24)**: a valid recovery code only ever claims
  an empty slot; couples store no email addresses
  (`20261003010400_remove_email_slot_assignment.sql`, `005_recovery.sql`).

Also pinned in Phase 2:

- **Partner notifications use one pathway (F-19)**: only `NotificationService`
  calls the `send-push-notification` edge function, so the partner's
  per-feature preferences and tap routing always apply. Chat pushes carry no
  message text (`test/architecture_test.dart`).
- **No Android backup or device transfer of app data (F-22)**
  (`test/android_backup_test.dart`).

## Rules for new client code

- New SharedPreferences data is wiped on every identity exit by default
  (`SessionDataWiper` keeps an allowlist). Add a key to
  `SessionDataWiper.deviceScopedKeys` only if it is genuinely device chrome.
  Add couple-scoped stores to `coupleScopedKeys` or `coupleScopedPrefixes` so
  that unlink removes them. A new `ScopedJsonCache` that misses a prefix fails
  `session_data_wiper_test.dart`.

## Rules for new migrations

- A new `SECURITY DEFINER` function must `REVOKE ALL ... FROM PUBLIC, anon,
  authenticated` and grant `authenticated` explicitly only if it is a client
  RPC. `001_rpc_privileges.sql` enumerates `pg_proc` and fails otherwise.
- A function that records a failed attempt must **return** a failure result,
  never `RAISE` after the write (that rolls the write back).
- When `CREATE OR REPLACE` rewrites a function, diff the result against the
  previous *live* definition (the latest migration that defined it). Three
  past regressions came from copying an older body.
