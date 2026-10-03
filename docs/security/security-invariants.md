# Security invariant register

Each invariant is enforced by the database (or, where it cannot be, by the
client) and pinned by a test. Every invariant that PostgreSQL can enforce has a
pgTAP test under `supabase/tests/`, run with:

```bash
supabase start          # once
supabase db reset       # apply every migration from scratch
supabase test db        # run the pgTAP suite
```

Status reflects the repository after remediation Phase 5 (2026-10-03).
"TODO" means the test exists and runs, marked as a pgTAP TODO: it reports the
known failure without failing the suite, and flips to a passing test the
moment the fix lands.

| ID  | Invariant | Status | Enforced by | Test |
|-----|-----------|--------|-------------|------|
| S01 | Anonymous users cannot execute relationship RPCs; authenticated users can execute only the RPC allowlist. | Enforced | `20261003000100_rpc_privilege_model.sql`, auth guards in `20261003000200` | `001_rpc_privileges.sql` |
| S02 | Users cannot join arbitrary couples by modifying `users.couple_id`. | Enforced | `protect_users_couple_id` trigger (`20260820000000`) | `002_cross_couple_rls.sql`, `006_unlink.sql` |
| S03 | Pairing attempts are rate-limited server-side, failed attempts persist, and a user cannot reset their own counters. | Enforced | `join_relationship_with_code` (`20261003000200`); counters bound to `auth.users` and no client DELETE on `users` (`20261003020000`, re-audit R-01) | `003_pairing.sql` |
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
| S15 | Only the couple's current members can join its presence channel (private Realtime channel). | Enforced. Verified against the real Realtime server: members join and see each other; outsiders are refused, and a public join to the same topic sees nothing. | `20261003030000_private_couple_presence.sql`, `PartnerPresence` joins as private | `supabase/tests/011_realtime_presence.sql`, `test/partner_presence_test.dart`, `test/e2e/realtime_e2e_test.dart` |
| S14 | Storage objects require authenticated couple membership. | Enforced in migrations. The **remote** project must still be verified (see `manual-actions.md`). | `20261003000000_enforce_private_storage_buckets.sql` + couple-path storage policies | `009_storage.sql` |
| S16 | Deleting a couple queues all of its stored photos for removal; deleting a user queues that user's avatars. The queue is service-role only. | Enforced in migrations. The objects are only actually removed once the `storage-cleanup` edge function is deployed and scheduled on the hosted project (see `manual-actions.md`). Verified end to end locally: real Storage API uploads, account deletion, function run, objects gone, unrelated object kept. | `20261003060000_storage_cleanup_queue.sql`, `supabase/functions/storage-cleanup` | `007_account_deletion.sql` |

Not numbered above but also pinned:

- **Account deletion (F-08)**: any user, including a couple's only or last
  remaining member, can delete their account
  (`20261003010100_fix_last_member_account_deletion.sql`,
  `007_account_deletion.sql`). The couple's storage objects are queued for
  removal (S16, Phase 7).
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

Also pinned in Phase 3:

- **Partner key pinning (R-03 / F-14)**: a device trusts the first public key
  it sees for its partner in a couple, and never wraps the photo key for, or
  accepts one from, a *different* key until the user confirms after comparing
  the safety number on the relationship profile screen
  (`test/partner_key_pinning_test.dart`, `test/partner_key_security_card_test.dart`).
  Limitation: trust on first use. A key substituted *before* the first
  exchange is only caught by comparing safety numbers.

Also pinned in Phase 4 (session-change correctness, not access control):

- **No stale writes after an account or couple change (F-15)**: every
  lifecycle controller's load drops its result if the session changed while it
  was in flight (`SupabaseLifecycleNotifier.isStale`). The same applies to the
  notification-preferences load. Covered by `test/lifecycle_staleness_test.dart`,
  including a scan that every lifecycle controller uses the guard.
- **Realtime recovers from `removeAllChannels()` (F-16)**: the shared streams
  end and controllers re-subscribe with backoff, instead of staying silently
  dead until restart (`test/lifecycle_staleness_test.dart`).

Also pinned in Phase 5 (performance; verified against the real Realtime
server in `test/e2e/realtime_e2e_test.dart`):

- **love_notes uses row-level realtime (F-18)**: chat and note-its receive
  individual insert/update/delete changes instead of the whole table on every
  launch, reconnect and message (measured at about 7.7 MB per launch for a couple
  two years in). The snapshot loads only once Postgres confirms the change feed,
  because Realtime drops changes committed before that point.
- **Known residual (Supabase platform behaviour)**: Realtime does not apply RLS
  to DELETE events. Anyone subscribed with a couple's id can learn that a
  `love_notes` row of that couple was deleted, and when: the event carries the
  row's id only, with no content, sender or type. This was the same with the
  earlier `.stream()` implementation. Avoiding it entirely would need a move
  to private broadcast channels fed by database triggers.

Also pinned in Phase 7 (cleanup):

- **Push delivery hygiene (F-20)**: `send-push-notification` sends to all of
  the partner's devices in parallel, reuses one OAuth token per worker, prunes
  only tokens FCM reports as 404 / `UNREGISTERED`, returns counts instead of
  the partner's device tokens (it used to echo them back to the sender), and
  returns a generic error body on failure. The helpers are unit-tested
  (`supabase/functions/send-push-notification/fcm.test.mjs`). The send path
  itself has not been run against real FCM.
- **Release builds need the real signing key (F-23)**: `bundleRelease` /
  `assembleRelease` fail without `android/key.properties`, unless
  `ALLOW_DEBUG_SIGNED_RELEASE=true` is set for a local check.
- **Infinite scroll for the growing lists**: the timeline (10 at a time),
  chat history (newest 100, then 50 older per scroll) and the scrapbook
  history grid (20 at a time) page with keyset cursors (no gaps or repeats on
  tied timestamps), one request in flight at a time, automatic loading paused
  after a failure until the user retries, and a shared loading / error /
  end-of-list footer (`PagingStatus`, `PagedListFooter`). Live updates stay
  row-level. Screens that need data by date or id load it outside the page
  window: the calendar by month, Wrapped by year, a tapped notification by
  memory id (`MemoryRouteScreen`), and chat by referenced note id. Counts come
  from server-side queries. Covered by `test/timeline_paging_test.dart`,
  `test/chat_paging_test.dart`, `test/noteit_paging_test.dart`,
  `test/paging_widgets_test.dart` and, against the real server,
  `test/e2e/realtime_e2e_test.dart`. Not paged on purpose: bucket list, gift
  reminders, time capsules, calendar events (small, hand-curated sets whose
  screens show totals), the note-it canvas, love-tap streaks and topic cards.
- **Legacy objects dropped**: `failed_recovery_attempts` and
  `get_user_couple_id(uuid)` (`20261003050000_drop_legacy_objects.sql`).

## Rules for new client code

- A new `SupabaseLifecycleNotifier` load must capture `sessionGeneration`
  before its first await and return if `isStale(generation)` before writing
  state or cache. `lifecycle_staleness_test.dart` fails otherwise.
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
