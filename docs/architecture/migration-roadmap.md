# Migration Roadmap

**PROPOSED.** This is the incremental, phased execution plan for the architecture defined across this specification and the ADRs. It exists so the migration can be carried out safely on a **live app with real user data**, by a **solo developer**, without a big-bang rewrite.

Every phase is independently shippable: the app builds, analyzes clean, and passes its test suite at the end of each phase, not only at the end of the whole roadmap.

## How to read this document

Each phase specifies: **Scope**, **Why this order**, **Files/modules affected**, **Risk**, **Validation**, and **Exit criteria**. A final section maps every one of the 22 Definition-of-Done items to the phase(s) that deliver it and the mechanism that verifies it.

## The two facts that set the whole order

**Fact 1 — the 13-provider fan-out on `RelationshipProvider` is fake coupling.** Verified by grep: every domain provider that reads `RelationshipProvider` reads exactly four members —
```
4  relationship.userId       2  relationship.partnerId
4  relationship.coupleId     2  relationship.isSupabaseAvailable
```
"Everything depends on the 2,143-line god provider" is, in reality, a four-field dependency. Extracting those four fields into a small `CoupleSession` (Phase 1) decouples all 13 domain providers in a matter of days, and is therefore done **first** — before Riverpod, before go_router, before anything else.

**Fact 2 — the god provider's state splits cleanly along three Supabase tables.** `RelationshipProvider` touches exactly `couples` (7 sites), `users` (8 sites), `license_details` (1 site), plus 41 SharedPreferences keys. State-ownership extraction (Phase 5) follows this exact partition, per ADR-002/ADR-003's finding that the June 2026 delegation refactor failed because it moved *operations*, not *fields*.

**Standing constraint, every phase:** the 41 SharedPreferences keys are a live hydration contract for real users on real devices. No phase renames a key. `PrefsKeys` (Phase 0) exists specifically to make this constraint enforceable.

---

## Phase 0 — Foundations (2–3 days, risk: none)

**Scope:**
- Delete dead `lib/repositories/relationship_repository.dart` (83 lines, zero call sites) — **not** by copying its logic to a scratch note. The row-to-model mappings are extracted and formally documented in this roadmap (see "Formal row-mapping documentation" immediately below) *before* deletion, as a committed, reviewable artifact that seeds Phase 4's three real repositories.
- Rename `lib/repositories/timeline_repository.dart` → `lib/services/app_settings_store.dart` (it has zero Supabase dependency; it's a SharedPreferences/file helper misnamed as a repository).
- Move `ScaleDrawingPainter` (a `CustomPainter`, currently in `lib/models/noteit_model.dart:200`) into `lib/widgets/` — a model file must not import Flutter's rendering layer.
- Delete the duplicate `CanvasPoint` class (`lib/models/noteit_model.dart:289`, keep `lib/models/canvas_document.dart:2`); route the legacy canvas serialization format through `canvas_document.dart`.
- Move `AppSettings` out of `lib/models/timeline_model.dart:169` into its own file.
- Move `ThemeSelectorScreen` (out of `widgets/theme_selector.dart`) and `MemoryDetailScreen` (out of `widgets/timeline_item.dart`) into `lib/screens/` — both are full route targets, not widgets.
- De-duplicate `_calculateAge` (`relationship_license_screen.dart:153` and `:4123`) and `_formatRelativeTime` (`bento_grid.dart:728` and `:2084`) into `DateHelper`.
- Replace the O(days) `countWeekends()`/`countOccurrencesOfDate()` loop (`relationship_duration_screen.dart:529-541`, confirmed to iterate day-by-day from the relationship start date to today **inside `build()`**) with a closed-form calculation in `DateHelper`.
- Create `lib/core/constants/prefs_keys.dart` — a single `PrefsKeys` class holding all 41 SharedPreferences key strings verbatim, exactly as they exist today.
- Create `test/architecture_test.dart` — the architecture-test harness (ADR-012), seeded with the rules already true today: no Supabase import under `screens/`/`widgets/`; no `CustomPainter` under `models/`. This is a ratchet: rules are added as later phases make them true, never all at once.
- Create the empty `lib/features/` directory skeleton (ADR-001) as the relocation target for later phases.

### Formal row-mapping documentation (extracted from `lib/repositories/relationship_repository.dart` and its three model files, read in full as part of producing this specification — not reconstructed from memory)

`RelationshipRepository` maps three tables via three methods, each delegating to a model's `fromMap`/`toMap`:

**`users` → `UserProfile`** (`fetchUserProfile`, `lib/models/user_profile.dart:44-90`):
`id`, `couple_id`→`coupleId`, `display_name`→`displayName`, `avatar_url`→`avatarUrl`, `gender`, `phone`, `birthdate` (ISO string → `DateTime?`), `address`, `nationality`, `weight`, `height`, `blood_type`→`bloodType`, `eye_color`→`eyeColor`, `conditions`, `date_issued`→`dateIssued` (ISO string → `DateTime?`), `signature`, `current_activity`→`currentActivity`, `partner_deleted_notice`→`partnerDeletedNotice` (default `false`), `created_at`→`createdAt` (ISO string → `DateTime?`). **Cross-checked against the live schema:** this field list matches exactly the `update_partner_profile` RPC's column whitelist documented in the prior full-codebase security audit (`display_name, gender, phone, birthdate, address, nationality, weight, height, blood_type, eye_color, conditions, date_issued, signature, avatar_url`) — this mapping is current and trustworthy as Phase 4's `UserRepository` seed.

**`couples` → `RelationshipWorkspace`** (`fetchWorkspace`, `lib/models/relationship_workspace.dart:36-74`):
`id`, `partner_a_id`→`partnerAId`, `partner_b_id`→`partnerBId`, `partner_a_email`→`partnerAEmail`, `partner_b_email`→`partnerBEmail`, `status` (default `'waiting'`), `pairing_code`→`pairingCode`, `recovery_lookup_key`→`recoveryLookupKey`, `recovery_code_hash`→`recoveryCodeHash`, `is_premium`→`isPremium` (default `false`), `start_date`→`startDate` (ISO string → `DateTime?`), `start_time_hour`→`startTimeHour`, `start_time_minute`→`startTimeMinute`, `story_title`→`storyTitle`, `created_at`→`createdAt` (ISO string → `DateTime?`). Consistent with the `couples` table columns referenced throughout the prior backend audit's RPC analysis (`partner_a_id`/`partner_b_id`, `status`, `pairing_code`, recovery fields) — current and trustworthy as Phase 4's `CoupleRepository` seed.

**`license_details` → `RelationshipMetadata`** (`fetchMetadata`, `lib/models/relationship_metadata.dart:18-38`):
`couple_id`→`coupleId`, `certificate_number`→`certificateNumber`, `issue_date`→`issueDate` (ISO string → `DateTime?`), `anniversary` (ISO string → `DateTime?`), `theme`, `relationship_title`→`relationshipTitle`.

**⚠️ Investigated further and resolved — the finding is more significant than a stale model, and corrects an earlier draft of this specification. Full trail, verified against `supabase/migrations/` directly:**

`license_details`'s original `CREATE TABLE` (`20260621000000_remote_schema.sql:154-183`) has `couple_id`, `creator_id`, and **30 paired `your_*`/`partner_*` text/timestamp columns** — `your_name`/`partner_name`, `your_gender`/`partner_gender`, `your_phone`/`partner_phone`, `your_birthdate`/`partner_birthdate`, `your_address`/`partner_address`, `your_nationality`/`partner_nationality`, `your_weight`/`partner_weight`, `your_height`/`partner_height`, `your_blood_type`/`partner_blood_type`, `your_eye_color`/`partner_eye_color`, `your_conditions`/`partner_conditions`, `your_date_issued`/`partner_date_issued`, `your_signature`/`partner_signature`, `your_avatar_path`/`partner_avatar_path`. These names match the app's 28 license fields almost exactly.

**But the live Dart code does not read or write those 28 fields through `license_details`.** `relationship_provider.dart`'s `updateLicense()` method pushes them through `ProfileService.updateUserDetails()`/`ProfileService.updatePartnerProfile()` (the latter via the `update_partner_profile` RPC) — both targeting the **`users`** table, whose own columns (confirmed via `UserProfile.fromMap`, `lib/models/user_profile.dart:44-66`, and the `update_partner_profile` RPC's column whitelist from the prior security audit) independently carry the *same conceptual fields* as singular, per-person columns (`gender`, `phone`, `birthdate`, `address`, `nationality`, `weight`, `height`, `blood_type`, `eye_color`, `conditions`, `date_issued`, `signature`, `avatar_url` — one row per user, not one row per couple).

**This means the live schema has genuine field duplication across two tables**, and `license_details`'s 30 paired columns appear to be a holdover from an earlier design (per-couple storage) superseded by the current per-user `users`-table design, without ever being dropped. Meanwhile, `certificate_number` — inserted by `create_relationship_workspace` (`20260712000001_refactor_users_profiles.sql:165-166`: `INSERT INTO public.license_details (couple_id, certificate_number) VALUES (...)`) — **is never created by any tracked migration.** No `ALTER TABLE ... ADD COLUMN certificate_number` exists anywhere in `supabase/migrations/`. The dead repository's `RelationshipMetadata` model, which includes `certificateNumber`, therefore reflects real, live-inserted data that simply isn't visible from the migrations directory alone — confirming **the migrations directory does not fully capture the live `license_details` schema** (undocumented drift, likely from dashboard-applied changes never captured in a migration file).

**Correction this requires to the rest of this specification:** `LicenseController` (Phase 5's second extraction) owns the 28 license fields' **application state**, but its repository dependency is `UserRepository`, not `LicenseRepository` — the live write path is `users`, confirmed above. `LicenseRepository`/`license_details` remains one of the three repositories under ADR-003's test (it is read by `ProfileService.fetchLicenseDetails` and subscribed to via realtime at `relationship_provider.dart:576`), but its actual scope is the narrower **certificate/metadata** concern (`certificate_number`, and whatever the undocumented-drift columns turn out to be) — not the 28 paired fields. `state-management.md`'s Riverpod topology diagram and `architecture-overview.md`'s Diagram 6 are corrected to show `LicenseController → UserRepository` accordingly.

**Mandatory Phase 4 action, elevated from "re-verify" to "required":** before building `LicenseRepository`, connect to the live Supabase project and run `\d license_details` (or the Supabase dashboard's schema view) to get the actual current column list — do not trust the migrations directory alone for this one table, since it is now confirmed incomplete. Determine at that point whether the 30 legacy `your_*`/`partner_*` columns are still populated by anything, are read by any surviving UI, or are safe to formally deprecate (a separate, future decision — not made by this planning phase, and not a schema change this migration performs).

Also present in the dead repository, not row-mapping but RPC pass-throughs worth preserving as `CoupleRepository`/`WorkspaceController` method signatures: `updateUserProfile`/`updatePartnerProfile` (the latter via the `update_partner_profile` RPC), `updateWorkspace`, `updateMetadata` (an upsert, not update), `createWorkspace`/`joinWorkspace`/`recoverWorkspace`/`disconnectWorkspace` (all thin RPC wrappers returning raw maps today — Phase 4's repositories should type these returns too, not just the fetch methods).

**Why first:** every later phase greps for symbols to move or extend. Duplicate `CanvasPoint`, duplicate `_calculateAge`, and misfiled screens make every subsequent search ambiguous. This phase also proves the toolchain (analyze, test, architecture-test) works before any behavioral risk is introduced.

**Files affected:** `lib/repositories/*`, `lib/models/noteit_model.dart`, `lib/models/canvas_document.dart`, `lib/models/timeline_model.dart`, `lib/widgets/theme_selector.dart`, `lib/widgets/timeline_item.dart`, `lib/services/date_helper.dart`, new `lib/core/constants/prefs_keys.dart`, new `test/architecture_test.dart`, new (empty) `lib/features/`.

**Risk:** low. The only behavior-affecting change is `countWeekends()`'s closed form — verify it against the loop's output for the actual relationship start date before deleting the loop.

**Validation:** `flutter analyze` clean; 82 existing tests still pass; add ≥2 new unit tests — closed-form weekend count vs. the old loop's output across a representative multi-year range, and legacy `noteit_model` canvas JSON still round-tripping through `canvas_document`.

**Exit criteria:**
- `lib/repositories/` no longer exists.
- `grep -rn "class CanvasPoint" lib/` returns exactly 1 match.
- `grep -rn "extends CustomPainter" lib/models/` returns 0 matches.
- No `while` loop over `DateTime` in any file under `lib/screens/`.
- `PrefsKeys` contains exactly 41 entries, each matching a string literal that existed in the code before this phase.

---

## Phase 1 — Extract `CoupleSession` (2–3 days, risk: **high**)

**Scope:** One small `ChangeNotifier` — `CoupleSession` — owning exactly the four fields the fan-out audit identified (`userId`, `coupleId`, `partnerId`, `isSupabaseAvailable`), plus the closely related `isPaired`, `isCreator`, `onboardingCompleted`, and their 5 corresponding `PrefsKeys` entries. It absorbs the auth-listener half of `RelationshipProvider`'s cluster 8 (`relationship_provider.dart:347-611` — the `onAuthStateChange` subscription) and becomes the emitter for `RelationshipLifecycleManager.handlePair`/`handleRepair`/`handleDisconnect`/`handleLogout`.

Add one derived enum, computed once from the five identity fields:
```dart
enum SessionStage { loading, unauthenticated, needsWorkspace, needsCouple, needsGenesis, needsAvatar, ready }
```
This is the readiness contract that go_router's redirect (Phase 3) will consume, replacing today's four independent restatements of "is the user ready."

Rewire all 13 `ChangeNotifierProxyProvider<RelationshipProvider, X>` in `main.dart` to `ChangeNotifierProxyProvider<CoupleSession, X>`. `RelationshipProvider` itself keeps pass-through getters for the four fields so **no UI file needs to change in this phase** — that happens in Phase 5b.

**Why this order:** this is the single change that decouples 13 files from a 2,143-line class, and it must precede Riverpod (Phase 2) — otherwise Riverpod hosts the same fan-out it was meant to fix.

**Files affected:** `lib/main.dart`, `lib/services/relationship_lifecycle_manager.dart`, `lib/providers/relationship_provider.dart` (partial), all 13 domain provider files (one-line signature change each: `updateRelationship(RelationshipProvider)` → `updateSession(CoupleSession)`).

**Risk — high, and deliberately scheduled while the app is still simplest:**
- The auth-listener move could cause `handlePair` to fire before `syncInitialData` completes, or fire twice, producing duplicate realtime subscriptions.
- `SessionStage` computed from partially-hydrated prefs on a cold start could flash `unauthenticated` and incorrectly route a signed-in user to `WelcomeScreen`.

**Validation:** the repository's **first widget tests** — pump `AppHome` against a faked `CoupleSession` for all 7 `SessionStage` values and assert the correct screen renders. This locks the exact contract go_router inherits in Phase 3. Follow with a manual 6-state matrix on a real device with real data: fresh install, creator-unpaired, joiner-unpaired, paired, partner-disconnected, logout.

**Exit criteria:**
- `grep -n "RelationshipProvider" lib/providers/*.dart` returns hits only within `relationship_provider.dart` itself.
- `main.dart` has zero `ChangeNotifierProxyProvider<RelationshipProvider, ...>` entries.
- Exactly one function in the codebase computes "is the user ready for the main app."

**⚠️ Corrected on implementation — three findings, all verified against the actual codebase rather than assumed from this plan's original text:**

1. **12 domain providers, not 13.** `main.dart` has exactly 12 `ChangeNotifierProxyProvider<RelationshipProvider, X>` entries (verified by direct count), matching Phase 6's own "12 domain providers" and `CLAUDE.md`'s provider list. The "13" in this phase's original scope text was an off-by-one; `RelationshipLifecycleManager`'s two base classes (`RelationshipLifecycleProvider`/`SupabaseLifecycleProvider` in `relationship_lifecycle_manager.dart`) are what all 12 actually funnel through, not 13 independent call sites.

2. **`CoupleSession` mirrors `RelationshipProvider`; it does not absorb the auth listener.** This plan's original text said `CoupleSession` "absorbs the auth-listener half of cluster 8... becomes the emitter for handlePair/handleRepair/handleDisconnect/handleLogout." On implementation, `RelationshipProvider`'s `_initSupabaseSync` (`:356-610`) turned out to be one deeply interleaved callback — the user-stream listener sets identity fields (`_coupleId`, `_userId`, `_partnerId`) in the same continuation as profile fields (`_yourName`, `_yourAvatarPath`) and workspace fields (`_startDate`, `_storyTitle`, `_isPremium`), with no seam to split cleanly without either duplicating parts of that callback (risking the exact double-fire/duplicate-subscription failure mode this phase's own risk section warned about) or a much larger rewrite than "2-3 days, high risk" implies.

   The implemented design instead makes `CoupleSession` (`lib/providers/couple_session.dart`) a thin `ChangeNotifier` that mirrors `RelationshipProvider`'s four fan-out fields plus the three pairing/onboarding flags via `updateFromRelationship(RelationshipProvider)`, wired through a `ChangeNotifierProxyProvider<RelationshipProvider, CoupleSession>` in `main.dart` (so the exit criteria above are satisfied in spirit — the 12 domain providers depend on `CoupleSession`, not `RelationshipProvider` — but not in the letter of "zero `ChangeNotifierProxyProvider<RelationshipProvider, ...>` entries," since exactly one remains: the one that builds `CoupleSession` itself). `RelationshipProvider` remains the single source of truth and the sole owner of `handlePair`/`handleRepair`/`handleDisconnect`/`handleLogout` emission until Phase 5 actually decomposes it field by field — at which point `CoupleSession` is "formally ported to a Riverpod Notifier" per this roadmap's own Phase 5, step 1, and becomes the real owner of its own identity fields (and their emission) for the first time. This is lower-risk and reaches the same decoupling outcome (Fact 1) that motivated doing this before Riverpod.

3. **`SessionStage` needs `startDate`, a sixth field, not five.** Wiring `SessionStage` into `main.dart`'s `AppHome` (to satisfy "exactly one function computes readiness," rather than leaving `_buildHomeContent`'s original inline conditional chain in place and merely adding an unused enum) revealed that distinguishing `needsWorkspace`/`needsGenesis`/`needsAvatar` is impossible without `RelationshipProvider.startDate` (verified against `main.dart`'s pre-Phase-1 branches, `:205-214`). `startDate` belongs to `WorkspaceController` (Phase 5), so `computeSessionStage` (a pure function in `couple_session.dart`, deliberately *not* a `CoupleSession` field) takes it as an explicit parameter, and `AppHome` reads it from `RelationshipProvider` directly until Phase 5 lands. `CoupleSession`'s own field set is otherwise exactly as scoped.

**Testing note:** the hydration-style `computeSessionStage` unit tests (`test/couple_session_test.dart`) cover all 7 `SessionStage` values plus two edge branches, and are green. A full widget-pumped `AppHome` test per this phase's original "pump `AppHome` ... for all 7 `SessionStage` values" validation plan was attempted and then removed: it is the first test in this repository to actually render a themed screen, and every themed screen renders text via `GoogleFonts.spectral` — with no font assets bundled for testing, `google_fonts` either attempts a real HTTP fetch (rejected by the test sandbox) or, with `GoogleFonts.config.allowRuntimeFetching = false`, fails its own asset-checksum validation (`_isFileSecure`) rather than falling back silently. This is a pre-existing testability gap unrelated to `CoupleSession`, not something this phase introduced or is positioned to fix; bundling real font files for tests is a separate, future task.

---

## Phase 2 — Host Riverpod (1 day, risk: low)

**Scope:** Wrap `runApp`'s tree in `ProviderScope`, with the existing `MultiProvider` nested inside it — not replaced. Build the strangler bridge in both directions:

- **Provider → Riverpod:** expose the live `CoupleSession` instance to the Riverpod side via `overrideWithValue` inside a `Consumer<CoupleSession>`, so new Riverpod code reads the *same instance* the old Provider tree uses — one instance, two containers, no state divergence.
- **Riverpod → Provider:** each newly written Riverpod notifier (starting in Phase 5) gets a temporary `ChangeNotifierProvider.value` shim back into `MultiProvider`, so untouched screens can keep calling `context.watch<X>()` unmodified. Each shim is deleted individually once its last `context.watch` call site is converted.

**Why this order:** costs about an hour and means every state unit extracted from Phase 5 onward is *born* as a Riverpod notifier instead of written as a `ChangeNotifier` and migrated a second time later.

**Files affected:** `lib/main.dart`.

**Risk:** low — nothing changes semantically; both trees reference the same underlying objects.

**Validation:** `flutter analyze`; all existing tests pass; one new test asserting override identity (`ref.read(coupleSessionProvider) == context.read<CoupleSession>()` inside a combined widget tree).

**Exit criteria:** `ProviderScope` is the root widget; `coupleSessionProvider` exists and is read successfully by at least one Riverpod-side widget.

---

## Phase 3 — go_router (4–6 days, risk: medium-high)

**Scope:** Adopt `GoRouter` (ADR-007) with a `redirect` whose body is `switch (session.stage)`, replacing `main.dart`'s `AppHome._buildHomeContent`. Define `lib/routing/routes.dart` as the single named-route registry for the ~20 screen destinations. Convert the 56 `MaterialPageRoute` and 41 `Navigator.push` sites to `context.push(Routes.x)`. Collapse the two conflicting destructive-action strategies (logout's `pushAndRemoveUntil(AppHome)`, deletion's `popUntil(isFirst)`) into one: clear the relevant state, let the redirect recompute the destination. Fix `calendar_screen.dart:581`'s duplicate-shell push (`context.go(Routes.home)` instead). Add a redirect guard on every couple-scoped route returning `Routes.pairing` when `coupleId == null`. Rewrite `notification_service.dart`'s payload handling to resolve a route string and call `_router.go(route)`; delete all 11 of its screen imports and delete `lib/navigator_key.dart`.

**Explicitly left alone:** the 104 `Navigator.pop` sites (`context.pop()` is a drop-in equivalent) and all 32 `showDialog`/14 `showModalBottomSheet` sites (not routes in this app's model — ADR-007).

**Why this order:** *before* the remaining state-ownership work (Phase 5), because `notification_service.dart`'s 11 screen imports mean every screen renamed or split later would otherwise force a fix in the notification service too. Cutting this dependency first means Phase 8's god-screen decomposition doesn't also have to touch notification routing.

**Files affected:** `lib/main.dart`, `lib/navigator_key.dart` (deleted), `lib/services/notification_service.dart`, all 44 files containing imperative navigation, new `lib/routing/`.

**Risk — medium-high:**
- A deep link (notification tap) arriving before `CoupleSession` finishes hydrating must not silently drop the link — `SessionStage.loading` must redirect to nothing (defer), not bounce to `WelcomeScreen`.
- The new route guards are strictly stronger than today's "each screen degrades presentationally" pattern — verify no currently-reachable, legitimate screen state becomes unreachable.

**Validation:** the 7 stage tests from Phase 1 become router redirect tests. One test per notification payload type (12 `feature` values) asserting the correct route resolves. Manual: fire all notification types with the app cold, backgrounded, and foregrounded.

**Exit criteria:**
- `lib/navigator_key.dart` deleted.
- `grep -c "^import.*screens" lib/services/notification_service.dart` == 0.
- `grep -rn "MaterialPageRoute" lib/` == 0.
- Every couple-scoped route has a redirect guard.

**⚠️ Corrected on implementation — five findings, all verified against the actual codebase, plus one deliberate scope narrowing:**

1. **A fresh count found 60 real `Navigator.push`-family sites across 20 files, not "41 across 44."** The `MaterialPageRoute` count (56) held exactly. The literal `Navigator.push` grep undercounted by missing chained/aliased forms (`Navigator.of(context).push(...)`, `state.push(...)` where `state = navigatorKey.currentState`) and included one false positive (a comment). The "44 files" figure was simply wrong — only 20 files under `lib/` contain any of the four navigation patterns.

2. **Redirect reads `RelationshipProvider` directly, not `CoupleSession`.** `CoupleSession.updateFromRelationship` runs on the *next* `ChangeNotifierProxyProvider` rebuild after `RelationshipProvider.notifyListeners()` fires — Provider's proxy mechanism goes through Flutter's `InheritedWidget` dependency system, which defers to the next frame, not synchronously within `notifyListeners()`. A screen doing `await provider.joinWithCode(code); context.push(Routes.avatar);` calls `context.push` — and therefore the redirect — before that next frame; reading `CoupleSession` there would see stale, pre-join values and bounce the push back to `/pairing`. `appRedirect` (`lib/routing/app_router.dart`) reads `RelationshipProvider` directly instead, which has no such lag, and `main.dart`'s `refreshListenable` was simplified to just `relationshipProvider` (dropping the `Listenable.merge` with `CoupleSession`) to match.

3. **The redirect needs an allowed-route-*set* per stage, not a single canonical target.** The original design (`here == target ? null : target`) breaks two real forward-navigation flows: `WelcomeScreen → AuthScreen` (pushed while `stage` is still `unauthenticated`, since sign-in hasn't happened yet) and `PairingSelectionScreen → JoinCoupleCodeScreen`/`RecoverRelationshipScreen` (pushed while `stage` is still `needsCouple`). Without an allowed set, the redirect would immediately bounce these pushes back to `welcome`/`pairing`. `app_router.dart`'s `_allowedRoutesForStage` map fixes this; `computeRedirectTarget` and its tests (`test/app_router_test.dart`) cover both the canonical-target and allowed-set cases for every stage.

4. **The `loading`-defers-a-deep-link mechanism described in this ADR's risk section was not actually implemented until caught by design review.** The first implementation redirected any non-loading location straight to `/loading` and never recorded what the original target was — meaning once `stage` resolved, the "deferred" deep link was simply gone (the user would land on `/home`, not the notification's actual target), contradicting this document's own stated design. Fixed with a small stateful capture/replay in `appRedirect` (`_pendingLocation`, module-level — there is exactly one app-wide router) around the now-pure `computeRedirectTarget`, which re-validates the replayed location against the resolved stage rather than forcing it unconditionally (so a deep link that turns out to be invalid for the resolved stage — e.g. the user was never actually signed in — still lands on the correct onboarding screen, not a couple-scoped route it has no business reaching). Covered by `test/app_router_test.dart`'s "pending deep link replay" group.

5. **Two forward-navigation sites were found to be genuinely unsafe to convert and were deliberately left as plain `Navigator` calls**, each with an inline comment explaining why:
   - `create_couple_code_screen.dart`'s "Continue" button pushes `GenesisScreen` with no gate on `isPaired` — but `computeSessionStage`'s `needsGenesis` requires `isPaired == true` (verified against this app's pre-migration `AppHome` logic, unchanged by this migration). A creator can reach this button before their partner joins, and a router-mediated push would be immediately redirected back to `/workspace`, silently breaking a button that currently works. This is a **pre-existing characteristic of the app's onboarding flow** (present since before this migration), not a regression introduced here — go_router's redirect just makes it manifest immediately instead of only on app restart.
   - `recover_relationship_screen.dart`'s forward push to `AvatarCreationScreen` is gated on `provider.yourName` being empty — a signal `computeSessionStage` doesn't consider at all. A recovered workspace could plausibly still be mid-genesis, in which case the redirect would compute `needsGenesis` and fight the push back to `/genesis`.

   Both are flagged for product/engineering follow-up outside this migration's scope (deciding whether the underlying flows should actually gate on pairing/stage more precisely), not fixed here — this phase changes navigation *plumbing*, not business logic.

6. **Scope narrowing, not a correction:** three widgets — `AddItemDialog`, `EditItemDialog`, `SignatureDrawingDialog` (2 call sites) — are pushed via `Navigator.push`/`MaterialPageRoute` rather than `showDialog`, which puts them outside this ADR's literal "the 41 `Navigator.push` calls that navigate to a distinct screen" wording. They were kept on plain `Navigator` anyway: each is conceptually a dialog (full-screen overlay, typed return value, no deep-link or back-button target of its own), and converting them to named routes would be exactly the over-engineering this ADR's rejected option 2 (route-ifying dialogs) warns against. `test/architecture_test.dart`'s Phase 3 group enforces that `MaterialPageRoute` appears nowhere else.

---

## Phase 4 — Three repositories + app-wide model immutability (3–4 days, risk: low-medium)

**Scope:** Build `UserRepository`, `CoupleRepository`, `LicenseRepository` (ADR-003) with `Dto.fromRow() → model` mapping, seeded from Phase 0's preserved row-mapping logic. Separately — and this is broader than the three repositories — make **all five** currently-mutable models fully immutable (`bucket_list_model.dart`, `daily_mood_model.dart`, `time_capsule_model.dart` at 0 `final` fields; `gift_reminder_model.dart`, `vault_item_model.dart` at 1 `final` field each), each already exposing `copyWith`, so this is a mechanical `final` addition plus updating in-place-mutation call sites (which `flutter analyze` finds automatically once fields are `final`). Turn on the architecture-test rule enforcing all-`final` models app-wide.

**Why this order:** repositories need the model layer settled first (a repository returning a model that's about to change shape is wasted work); doing model immutability in the same phase as the three repositories, rather than deferring it, means Definition-of-Done item 11 doesn't linger as a separate, easy-to-forget follow-up.

**Files affected:** new `lib/data/user_repository.dart`, `couple_repository.dart`, `license_repository.dart`; `lib/models/user_profile.dart`, `relationship_workspace.dart`, `relationship_metadata.dart`; the 5 mutable models and every call site that mutates them in place.

**Risk:** low-medium. The immutability change is compile-time-safe by construction — `flutter analyze` finds every broken mutation site; the only judgment call is confirming each fix preserves intended behavior (mutation → `copyWith` + reassignment).

**Validation:** row-mapping unit tests against fake Supabase row maps, no network — target 15+ new tests, the highest-value tests available in this phase per the testing strategy.

**Exit criteria:**
- No raw `.from('users'|'couples'|'license_details')` call exists outside `lib/data/`.
- 100% of classes in `lib/models/` have all-`final` fields (architecture-test enforced).

**⚠️ Corrected on implementation:**

1. **The `license_details` "undocumented schema drift" finding (Phase 0, ADR-003) was incomplete, not just unverified — and is now fully resolved without a live database connection.** Both documents flagged connecting to the live Supabase project as *mandatory* before building `LicenseRepository`, because Phase 0's audit read only `20260621000000_remote_schema.sql` (the original `CREATE TABLE`, with 30 paired `your_*`/`partner_*` columns and none of `RelationshipMetadata`'s fields) and concluded the model's assumed columns were unverified. Reading the **complete** migration history surfaced `20260712000002_fix_rls_recursion.sql:54-89`, which both adds exactly the five columns `RelationshipMetadata` already expects (`certificate_number`, `issue_date`, `anniversary`, `theme`, `relationship_title`) **and drops all 30 legacy paired columns** in the same statement — the "genuine field duplication across two tables" Phase 0 reported no longer exists; it was cleaned up by a later migration Phase 0's audit didn't reach. No later migration touches this table's shape (verified against the full, ordered `supabase/migrations/` listing). `LicenseRepository` (`lib/data/license_repository.dart`) was built directly from this finding, with the full trail documented in its doc comment — the live-schema-verification mandate is satisfied by migration-history archaeology, not a live connection this environment doesn't have.

2. **The exit criterion "no raw `.from()` call outside `lib/data/`" is satisfied for new code, not retroactively enforced against `relationship_provider.dart`/`profile_service.dart`.** A fresh count found 18 raw `.from('users'|'couples'|'license_details')` sites in `relationship_provider.dart` and 5 in `profile_service.dart` (23 total, 2 files) — `couple_service.dart` has none (it is entirely RPC-based pairing/workspace orchestration, not table CRUD, and correctly stays out of this repository layer's scope per ADR-003's two-part test). Rewiring all 23 now would mean adding a second, competing data-access path into the exact 2,000+-line file Phase 5 is about to decompose field-by-field — real risk of conflicting with Phase 5's own extraction work for no benefit, since each extracted controller (`LicenseController`, `ProfileController`, `WorkspaceController`) can instead be *born* calling the repository directly, exactly like Phase 1/2's "born correctly" reasoning for `CoupleSession`/Riverpod. The three repositories built this phase are fully additive and independently tested; Phase 5 is what actually retires the 23 existing call sites as each state slice is extracted.

3. **Repository API surface includes typed RPC pass-throughs, not just `fetch`/`update`.** Per ADR-003's Phase 0 note, `UserRepository.updatePartnerProfile` wraps the `update_partner_profile` RPC (the only way to write another user's row under RLS) alongside the plain `fetchUser`/`updateUser`. `CoupleRepository` and `LicenseRepository` stay to plain fetch/update/upsert — the pairing-lifecycle RPCs (`create_relationship_workspace`, `join_relationship_with_code`, etc.) remain in `CoupleService`, since they are multi-step transactions with ad-hoc response shapes, not typed single-row CRUD, and moving them wouldn't serve the two-part test.

---

## Phase 5 — Decompose `RelationshipProvider` by state ownership (1.5–2 weeks, risk: high per unit)

**Scope:** Five Riverpod units, each defined by the specific fields and `PrefsKeys` entries it owns, extracted in this order:

1. **`CoupleSession`** — already done (Phase 1); now formally ported to a Riverpod `Notifier`.
2. **`LicenseController`** — the 28 paired `_your*`/`_partner*` fields (`relationship_provider.dart:111-148`), ~15 field setters (`:749-1176`), and the 259-line `updateLicense` method (`:1177-1435`), replaced with `state = state.copyWith(...)` on an immutable `LicenseDetails`, deleting roughly 200 lines outright. Extracted **second** because it is the single largest contiguous slab (~32% of the file) and has zero state overlap with any other cluster.
3. **`ProfileController`** — names, avatars, join dates (clusters spanning `:61-110`, `:612-684`, `:1436-1551`).
4. **`WorkspaceController`** — pairing code, start date/time, story title, status, recovery code, premium flag (`:1552-1742`, `:1743-1861`).
5. **`PresenceController`** — online flag, activity strings, presence channel (`:159-167`, `:685-748`). Smallest; extracted last as a warm-down.

The pure duration/milestone math (`:1992-2128`) is **not state** — per ADR-009, it becomes plain functions added to `DateHelper` during this phase, not a sixth controller.

**Why this order — and why after go_router:** the screens reading license state (`relationship_license_screen.dart`, `relationship_profile_screen.dart`) are the same screens Phase 8 decomposes. Converting their state source and their route wiring in the same window would double the blast radius of any single mistake; go_router (Phase 3) is deliberately already settled by this point.

**Files affected:** `lib/providers/relationship_provider.dart` (shrinking with each extraction), new `lib/features/relationship/` and `lib/features/authentication/` state files.

**Risk — high per individual extraction, low in aggregate** because each of the five is independently shippable. The specific failure mode across all five: silent `PrefsKeys` drift blanking a live user's data on the next hydration.

**Validation — the single highest-ROI test in this roadmap:** a hydration fixture test, written **before extracting unit 2** (not after all five), seeding `SharedPreferences.setMockInitialValues` with a realistic 41-key map captured from a real device and asserting every controller hydrates identically before and after each extraction.

**Exit criteria:** `relationship_provider.dart` is under 200 lines (a deprecated pass-through façade); the hydration fixture test passes unchanged across all five extractions. **⚠️ Corrected on completion — the line-count target is superseded; see correction 16 below.**

**⚠️ Corrected on implementation — two scope changes, decided before extraction began:**

1. **Phase 5 and 5b are merged per controller, not run as two separate passes.** The original design has `RelationshipProvider` keep "pass-through getters" after each extraction (mirroring Phase 1's `CoupleSession` pattern), with the 27 UI files converted later in a dedicated Phase 5b. That pattern doesn't transfer: Phase 1's pass-through worked because `CoupleSession` *mirrored* `RelationshipProvider` (a live `ChangeNotifier` any Dart code can read a getter from directly). Here the direction is reversed — `RelationshipProvider` would need to mirror a *Riverpod* notifier, which requires a globally-reachable `ProviderContainer` for non-widget code to read, new infrastructure the original plan didn't call for. Instead, each controller's extraction converts its own UI consumers and deletes the corresponding `RelationshipProvider` fields/getters/setters in the same step, rather than leaving a pass-through shim to be cleaned up later. Each controller is still independently shippable — this changes *when* the UI converts, not the phase's risk shape.

2. **`CoupleSession`'s real Riverpod port (owning the auth listener directly, replacing the `ChangeNotifierProxyProvider` mirror from Phase 1/2) is deferred to Phase 6, not done as this phase's first step.** The original text lists it as unit 1, "already done (Phase 1); now formally ported to a Riverpod `Notifier`." But `CoupleSession`'s only consumers are the 12 domain providers Phase 6 already ports to Riverpod (verified: Phase 1's Fact 1 audit) — nothing in Phase 5's four real extractions (`LicenseController`/`ProfileController`/`WorkspaceController`/`PresenceController`) depends on it. Porting it now would mean converting some subset of those 12 providers early, off-schedule and without Phase 6's own planning; deferring it costs nothing, since Phase 1's mirror already fully decouples the 12 providers from the god-provider — the only thing left to change is *how* `CoupleSession` gets its data, which only matters once Phase 6 ports its consumers anyway.

**Unit 2 (`LicenseController`) findings, from a repo-wide investigation before writing any code:**

3. **The roadmap's "28 fields" figure conflated `updateLicense`'s full parameter list with `LicenseController`'s actual scope.** `updateLicense` has 28 parameters, but 4 (`yourName`/`partnerName`/`yourAvatarPath`/`partnerAvatarPath`) are `ProfileController`'s fields, reachable through the same bulk-edit method only because the UI form happened to submit both concerns together. `LicenseController` owns exactly 12 pairs (24 fields), verified against `relationship_provider.dart`'s getters. The two call sites that used to call `updateLicense` now make two calls — one to `RelationshipProvider.setYourName` (untouched), one to `LicenseController.updateFields` (the 24-field method) — splitting a single UI save action across the two controllers it always should have belonged to.

4. **`relationship_provider.dart`'s 10 individual license setters (`setGenders`, `setPhoneNumbers`, etc.) had zero callers anywhere in `lib/` or `test/`** — confirmed by repo-wide search before extraction. Only the bulk `updateLicense` was ever invoked, from exactly two call sites, both in `relationship_license_screen.dart`, both writing "your" fields only (never "partner", despite the method accepting both). These 10 dead methods were not ported forward to `LicenseController` — porting unreachable API surface forward would be exactly the kind of unrequested feature-preservation `CLAUDE.md` asks this codebase to avoid.

5. **`relationship_profile_screen.dart` turned out not to be a license-field consumer at all**, despite being a heavy `RelationshipProvider` consumer for everything else (pairing, identity, recovery codes, naming) — confirmed by exhaustive search, zero matches. No changes were needed there for this extraction, correcting this document's own earlier assumption (§"Why this order") that it was one of the two screens affected.

6. **A real cross-session staleness gap, found and fixed before it could ship:** a default (non-`autoDispose`) `AsyncNotifierProvider` stays alive for the whole app session. `RelationshipProvider.logout()`/`unlinkPartner()` used to reset the license fields as a direct part of those methods; once the fields moved to `LicenseController`, nothing told the new provider to forget a signed-out user's data, so a second account signing into the same app session (no full app restart) would have seen the first account's license fields. Fixed with `main.dart`'s `_LicenseLifecycleBridge`, which watches `RelationshipProvider`'s identity fields and calls `ref.invalidate(licenseControllerProvider)` on logout/disconnect, forcing a re-hydration against SharedPreferences (already cleared by that point). This is the concrete, general-purpose instance of the "silent `PrefsKeys` drift blanking a live user's data" risk this phase's own validation section warns about — expect every later Phase 5 unit to need the same hook.

7. **Acknowledged, narrower gap:** `RelationshipProvider._syncLocalDetailsToCloud`'s license-field re-push-on-pairing (a resync safety net for license fields written before Supabase was reachable) was removed rather than rebuilt against `LicenseController`, since doing so would require the same kind of non-widget Riverpod access this phase's item 1 correction specifically avoided introducing. The write-time push (`LicenseController.updateFields`) already attempts an immediate, best-effort sync with the same try/catch-silent failure mode the code it replaced had; the removed behavior only covered the narrower case of a failed initial push that's never retried. Flagged in `license_controller.dart`'s source, not silently dropped.

**Unit 3 (`ProfileController`) — a deliberate departure from the cutover pattern, decided by explicit user choice before any code was written:**

8. **`ProfileController` is a mirror, not a cutover — unlike `LicenseController`.** The 6 name/avatar/join-date fields are read across 16 UI files and, critically, are *actively kept live* by Supabase realtime streams woven through `_initSupabaseSync`'s and `_initPartnerUserSync`'s ~400 combined lines in `relationship_provider.dart` — the license fields had no such dependency, which is exactly what made deleting them safe. Two options were surfaced to the user: a full cutover (extract the realtime logic itself, delete the fields from `RelationshipProvider`, convert all 16 consumers) or a mirror (add a Riverpod-native read surface that copies the 6 fields on every `RelationshipProvider` change, exactly as `CoupleSession` has done since Phase 1, leaving `RelationshipProvider` as the sole source of truth and its realtime logic untouched). The user chose the mirror, given the risk of surgery on a live, working realtime subscription for comparatively little near-term benefit — nothing yet depends on `ProfileController` the way the 12 domain providers depend on `CoupleSession`. Implementation: `lib/features/relationship/profile_state.dart` (immutable `ProfileState`, 6 fields, value equality) + `lib/features/relationship/profile_controller.dart` (`ProfileController extends Notifier<ProfileState>`, with `updateFromRelationship` mirroring `CoupleSession.updateFromRelationship`'s "notify only if changed" contract) + `main.dart`'s `_ProfileControllerBridge`, a `ConsumerStatefulWidget` that calls `updateFromRelationship` on every `RelationshipProvider` rebuild (deliberately *not* an invalidate-on-logout hook like `_LicenseLifecycleBridge` — since this is a pure mirror, the next `updateFromRelationship` call after a logout already overwrites stale state with the post-logout nulls, so there is nothing extra to clear). None of the 16 UI consumer files were touched; all still read `RelationshipProvider` directly. The real ownership transfer (moving the realtime listener itself into `ProfileController`) is deferred to Phase 6, alongside `CoupleSession`'s own equivalent deferral (item 2 above).

9. **This same mirror treatment will very likely apply to `WorkspaceController` (unit 4) as well**, since its fields (pairing code, start date/time, story title, status, recovery code, premium flag) are also realtime-driven via the same `_coupleSub` stream — the decision should be revisited per-field when that unit starts, not assumed, but the precedent and rationale are now established here rather than needing a fresh `AskUserQuestion`.

10. **This phase's exit criteria ("`relationship_provider.dart` is under 200 lines") is now in tension with the mirror decision and needs re-evaluation once Phase 5 is otherwise complete.** `CoupleSession` (Phase 1) and now `ProfileController` (unit 3) — and, confirmed below, `WorkspaceController` (unit 4) — are mirrors, not cutovers: `RelationshipProvider` keeps every one of their fields, getters, and realtime sync logic. Only `LicenseController` (unit 2) is a true cutover that actually shrinks the file so far; `PresenceController` (unit 5, not yet started) is the last chance for another. `relationship_provider.dart` will land well above 200 lines at the end of Phase 5 — the 200-line target implicitly assumed all five units would cut over, which the realtime-entanglement findings from units 3 and 4 have shown isn't safe. Not yet flagged to the user as a question; noted here so it's visible before Phase 5 is declared complete.

**Unit 4 (`WorkspaceController`) findings, from a repo-wide investigation before writing any code:**

11. **`WorkspaceController` mirrors all 7 fields — `coupleCode`, `storyTitle`, `startDate`, `startTime`, `isPremium`, `status`, and `recoveryCode`.** 6 of the 7 (everything but `recoveryCode`) are confirmed written live inside `_initSupabaseSync`'s `_coupleSub` realtime listener (the `.from('couples').stream(...)` callback), the same entanglement that made `ProfileController` a mirror. `recoveryCode` is not realtime-synced — it's only ever set from `createRelationshipWorkspace()`'s and `regenerateRecoveryCode()`'s RPC results — but that RPC call is the *same* call that also sets `CoupleSession`-owned fields (`coupleId`/`isPaired`/`isCreator`) and this controller's own `coupleCode`/`status`. A standalone cutover would require either duplicating that RPC call (risking two workspaces being created) or `RelationshipProvider` pushing into Riverpod from non-widget code — the exact global-container infrastructure the Phase 5/5b merge decision (item 1) already ruled out. This tradeoff was surfaced to the user via `AskUserQuestion`; the user chose to mirror all 7 rather than carve `recoveryCode` out on its own. This is a genuine extension of the mirror-vs-cutover criterion beyond "is it realtime" to "is its write path entangled with fields this phase isn't touching" — worth checking explicitly for `PresenceController` (unit 5) too, though its fields (online flag, activity strings, presence channel) look independent on their current understanding.

12. **`togglePremium()` (`relationship_provider.dart:1114-1126`) is dead code — zero callers anywhere in `lib/` or `test/`.** `setPremium(bool)` is the sole live path for both premium-toggle UI sites (`studio_tab.dart`, `settings_tab.dart`). Left in place rather than ported, matching unit 2's precedent for `LicenseController`'s 10 dead setters — since this unit is a mirror, `RelationshipProvider` isn't being touched at all, so there was nothing to delete regardless.

13. **`status` has zero UI consumers repo-wide today**, despite being written 6 times inside the provider and mirrored here for parity. No screen, widget, service, or test reads `RelationshipProvider.status`. Mirrored anyway since a future consumer (e.g. an "archived relationship" UI state) is exactly the kind of thing this Riverpod-native surface exists to make available without another provider-file edit — consistent with the mirror pattern's low marginal cost (unlike a cutover, adding an unused field to a mirror costs nothing beyond the one extra line in `updateFromRelationship`).

14. **Confirmed no scope error this time** (unlike unit 2's wrong "28 fields" figure or unit 3's wrong `relationship_profile_screen.dart` assumption) — the roadmap's original unit-4 description ("pairing code, start date/time, story title, status, recovery code, premium flag") matched the actual 7 fields with no additions or removals needed, other than confirming `isCreator` is correctly out of scope (already `CoupleSession`-owned since Phase 1).

15. **13 UI files read at least one of the 7 fields** (`relationship_profile_screen.dart`, `relationship_license_screen.dart`, `create_couple_code_screen.dart`, `studio_tab.dart`, `love_story_screen.dart`, `calendar_screen.dart`, `relationship_duration_screen.dart`, `wrapped_service.dart`, `settings_tab.dart`, `detailed_days_counter.dart`, `relationship_statistics.dart`, `milestone_card.dart`, and `lib/routing/app_router.dart` — the last of these outside `screens/`/`widgets/` but load-bearing for `computeSessionStage`'s routing decision, per `couple_session.dart`'s own doc comment flagging `startDate` as a stopgap pending this extraction). None of the 13 were touched, matching the mirror pattern established in unit 3 — `WorkspaceController` exists as an additional Riverpod-native read surface, not a replacement yet.

**Unit 5 (`PresenceController`) findings — the last unit, closing out Phase 5:**

16. **`PresenceController` mirrors all 3 fields (`isPartnerOnline`, `yourActivity`, `partnerActivity`) — also a mirror, not the cutover the roadmap's "warm-down" framing implied.** All 3 are realtime-driven: `isPartnerOnline` is flipped inside `_initPresence`'s `onPresenceSync` callback on a dedicated `couple_presence_<coupleId>` Supabase Realtime **presence** channel (`relationship_provider.dart:615-662`) — a second, independent realtime mechanism alongside the `_coupleSub` Postgres-changes stream `ProfileController`/`WorkspaceController` are entangled with; `partnerActivity` comes from the partner-row realtime sync callback; and `yourActivity` is both a direct local write (`updateCurrentActivity`) and set from the current user's own realtime row sync. Given this, applying the same mirror criterion used in units 3-4 was a direct extension of already-decided precedent rather than a fresh fork, so no `AskUserQuestion` was raised for this unit — `RelationshipProvider` keeps `_initPresence`, the presence channel, and `updateCurrentActivity` unchanged; `PresenceController` is an additional read surface, mirrored via `main.dart`'s `_PresenceControllerBridge`. Only 4 UI files read these fields (`currently_card.dart`, `insights_banner.dart`, `partner_presence_card.dart` — confirmed dead/never-instantiated in an earlier unit — and `love_chat_screen.dart`); none were touched.

17. **This closes out Phase 5's five units at a final tally of 4 mirrors to 1 cutover** — `CoupleSession` (Phase 1), `ProfileController` (unit 3), `WorkspaceController` (unit 4), and `PresenceController` (unit 5) all mirror `RelationshipProvider` rather than replacing it; only `LicenseController` (unit 2) actually deleted fields from the file. This resolves the tension flagged in correction 10: the **"under 200 lines" exit criterion is retired, not met**, and is superseded by a more accurate one — `relationship_provider.dart` sits at 1,521 lines at the close of Phase 5 (down from ~2,148 at Phase 5's start, entirely from unit 2's cutover), and every one of its remaining fields now also has a live Riverpod-native mirror available via `lib/features/relationship/{profile,workspace,presence}_controller.dart` plus `CoupleSession`. The file's line count was never really what Phase 5 was validating — the real exit criterion, met in full, is that **every field `RelationshipProvider` owns is now readable through Riverpod without a `context.watch<RelationshipProvider>()`**, which is what unblocks Phase 6 (porting the 12 domain providers) regardless of the god-file's remaining size. `RelationshipProvider`'s realtime-listener logic itself (`_initSupabaseSync`, `_initPartnerUserSync`, `_initPresence`) is what's left, and per corrections 2/8/16 above, moving it is explicitly deferred to Phase 6 for all four mirrored units at once, alongside `CoupleSession`'s own equivalent deferral — at which point `relationship_provider.dart` can likely be deleted outright rather than trimmed further, since Phase 6 already plans to retire the whole Provider-based lifecycle-manager approach it depends on.

18. **The hydration fixture test's validation promise held across all five units without modification to its `RelationshipProvider`-side assertions** for the four mirrored units (`test/hydration_fixture_test.dart`'s existing `provider.coupleCode`/`.isPremium`/`.storyTitle`/`.startDate`/`.startTime` checks and equivalents for profile/presence fields remain valid, since nothing was deleted from `RelationshipProvider`); only unit 2's cutover required adding the parallel `LicenseController`-hydration assertion described in that unit's own entry above. `flutter analyze` and the full test suite (170 tests as of this unit) stayed green after every one of the five units.

---

## Phase 5b — Finish the removal (3–5 days, risk: medium)

**Scope:** Convert the **27 UI files** still reading `RelationshipProvider` directly (confirmed by grep across `lib/screens/` and `lib/widgets/`) to read the appropriate Phase 5 controller instead. Delete `lib/providers/relationship_provider.dart` once the last reference is gone.

**Why a separate phase:** broad (27 files) but mechanical and comparatively low-risk, unlike Phase 5's state-ownership design work — separating them means Phase 5's riskier design decisions aren't bottlenecked on completing 27 individual UI conversions, and Phase 5b can proceed screen-by-screen without blocking anything else.

**Files affected:** the 27 identified UI files.

**Risk:** medium — mechanical but broad; each conversion needs a quick manual check that the correct controller replaces `RelationshipProvider` for that screen's specific reads.

**Validation:** `flutter analyze` clean after each file's conversion (a broken read shows immediately as a type error); existing widget tests from Phase 1/3 continue passing.

**Exit criteria:** `grep -rl "RelationshipProvider" lib/` returns 0 matches; the file no longer exists.

---

## Phase 6 — Port the 12 domain providers; retire the lifecycle manager (1 week, risk: medium)

**Scope:** Convert each `SupabaseLifecycleProvider` subclass to a Riverpod `Notifier` + `StreamProvider` pair. `autoDispose` + `ref.onDispose` replaces the `addListener`/`removeListener` refcounting in `SupabaseLifecycleProvider` (ADR-002); `ref.invalidate` replaces `purgeCache`/`onDisconnect`. **`RealtimeSubscriptionManager` is kept unchanged** (ADR-005) — Riverpod's `autoDispose` governs provider lifetime, not shared-channel deduplication, and the manager has no confirmed bug beyond the table-key collision, which is fixed in this same phase: `noteit_provider`'s and `love_chat_provider`'s successors get distinct subscription keys (`'love_notes:scrapbook_$coupleId'` / `'love_notes:chat_$coupleId'`) with the `type` filter moved server-side. Delete `relationship_lifecycle_manager.dart` once the last subclass is ported. Remove `provider:` from `pubspec.yaml`; remove `MultiProvider` from `main.dart`.

**Why this order:** depends on Phase 5's `CoupleSession`/controllers already being Riverpod-native (`ref.watch` needs a Riverpod provider on the other end); this is the phase where the strangler bridge from Phase 2 is finally fully retired.

**Files affected:** all 12 domain provider files, `lib/services/relationship_lifecycle_manager.dart` (deleted), `lib/services/realtime_subscription_manager.dart` (subscription-key fix only), `pubspec.yaml`, `lib/main.dart`.

**Risk:** medium. Specific failure mode: `autoDispose` tearing down a realtime channel on a tab switch that the old refcounting kept alive, surfacing as "messages stop arriving after backgrounding" — mitigated with `ref.keepAlive()` specifically on the chat and scrapbook providers, which are the two most sensitive to this.

**Validation (Definition-of-Done item 19):** tests against `RealtimeSubscriptionManager` asserting: exactly one subscription per table+couple key under two concurrent listeners; teardown when the last listener is removed; no duplicate subscription on rapid re-subscribe (simulating a tab switch); full teardown on disconnect and on logout.

**Exit criteria:**
- `lib/services/relationship_lifecycle_manager.dart` no longer exists.
- `provider:` is absent from `pubspec.yaml`.
- `MultiProvider` is absent from `lib/main.dart`.
- No two providers share a subscription key with client-side type filtering.

---

## Phase 7 — Design tokens + shell (1 week, risk: low)

**Scope:** Extend `LoveStoryTheme`'s 8 fields with spacing/radius/elevation/blur/motion/semantic-state tokens via a `ThemeExtension` (ADR design-system.md). Replace every `dynamic theme` parameter with a typed `LoveStoryTheme theme` — the single highest-leverage change in this phase, since it converts ~986 invisible hardcoded-color sites into compiler-findable work once the typed parameter forces callers to actually use theme tokens. Collapse `AppTypography`'s 15 methods (`mainCounter` ≡ `pageTitle`; `bodyMono`/`captionMono` not actually monospace) to roughly 6 real, distinct roles. Fix `LoveStoryScreen`: hoist `List<Widget> pages` out of `build()` into an `IndexedStack` with `PageStorageKey`s so tab state survives switching; move the tab-1-specific `RulerPickerScrubber` out of the shared shell bar into the timeline tab that actually owns it.

**Explicitly not touched:** `screens/wrapped/**`'s separate `WrappedGradients` palette — an intentional seasonal aesthetic, not theme-system debt.

**Files affected:** `lib/themes/theme_manager.dart`, `lib/themes/app_typography.dart`, `lib/screens/love_story_screen.dart`, every file with a `dynamic theme` parameter (~10+ across `together_tab.dart`, `studio_tab.dart`, `settings_tab.dart`, `bento_grid.dart`, etc.).

**Risk:** low — mechanical typing changes and a shell restructure with no data-layer involvement.

**Validation:** `flutter analyze`; manual check that tab-switch scroll position now survives (scroll a tab, switch away, switch back).

**Exit criteria:** `grep -rn "dynamic theme" lib/` == 0; tab state demonstrably survives a switch.

---

## Phase 7b — Relocate shared widgets into features (3–5 days, risk: low)

**Scope:** Move the ~73% of `lib/widgets/` that is feature-specific (all of `widgets/dashboard/`, most of `widgets/wrapped/`, plus `add_item_dialog.dart`, `memory_notes_section.dart`, `music_controls.dart`, `raster_canvas.dart`, `rich_text_editor_overlay.dart`, `ruler_picker_scrubber.dart`, `storybook_view.dart`, `text_overlay_widget.dart`, `custom_backgrounds.dart`) into the `presentation/` directory of its owning feature under `lib/features/`. What remains in `lib/shared/` is the ~12% that's genuinely generic (ADR-008), consolidating the duplicated `cached_avatar.dart`/`app_avatar.dart` "single source of truth" claim into one component. Tighten the architecture-test suite to forbid `lib/features/<A>/**` importing a non-`shared` path in `lib/features/<B>/**`.

**Why this order:** after routing (Phase 3) and state-ownership (Phase 5/5b/6) so the mechanical relocation diff — large by file count, low by individual risk — doesn't compound with behavioral changes happening in the same window.

**Files affected:** all ~26 files in the "feature-specific but misplaced" and "route screens misfiled" buckets from the widget-inventory audit.

**Risk:** low — pure relocation plus import-path updates; `flutter analyze` catches any missed reference immediately.

**Validation:** `flutter analyze` clean; the architecture-test suite's cross-feature-import rule passes with zero exceptions.

**Exit criteria:** `lib/widgets/` contains only design-system-tier components; the cross-feature-import architecture-test rule is active and green.

---

## Phase 8 — God-screen decomposition (2 weeks, risk: low-medium, parallelizable)

**Scope:** Detailed per-file plans live in `god-file-decomposition.md`. Summary:
- **`relationship_license_screen.dart`** (5,025 lines) — split by class: 6 widget+state pairs and 3 `CustomPainter`s move to `lib/features/relationship/presentation/`; `_buildQrData()` becomes a `LicenseQrCodec` with round-trip tests; `_saveToDevice`/`_shareImage` become an `ImageExportService`.
- **`noteit_screen.dart`** (2,571 lines) — `_sendCanvas()`'s multi-provider transaction becomes `ScrapbookShareUseCase` (ADR-009, Definition-of-Done item 13); `_saveDraft`/`_loadDraft` become a `NoteitDraftStore`.
- **`bento_grid.dart`** (2,390 lines) — the ad-hoc `'[scrapbook]:'` string protocol is replaced by a typed `ScrapbookRef` (Definition-of-Done item 14) shared between the writer (`noteit_screen.dart`'s successor) and the reader (`bento_grid.dart`'s successor); synchronous `File().existsSync()` calls during build become a cached async provider.
- **`relationship_duration_screen.dart`** (1,259 lines) — already largely fixed by Phase 0's `countWeekends` closed-form extraction; remaining work is moving the hardcoded milestone catalog into a `const` list in the appropriate feature.
- **`relationship_profile_screen.dart`** (1,652 lines) — confirmed **not** a real architectural problem; only its inlined dialog bodies are extracted for readability, at low priority.

**Why last:** this phase can run in parallel with, or after, Phase 7b once each target file's feature directory exists; it depends on Phase 5/5b (state) and Phase 3 (routing) both being settled so screen splits don't also have to renegotiate state or navigation wiring mid-split.

**Risk:** low-medium, isolated per file — each screen's decomposition is independently shippable and doesn't block the others.

**Validation:** per `god-file-decomposition.md`'s file-specific validation notes (e.g. `LicenseQrCodec` round-trip tests, `ScrapbookRef` serialization tests).

**Exit criteria:** no file in `lib/` exceeds 800 lines, except by documented, deliberate exception; `ScrapbookShareUseCase` and `ScrapbookRef` both exist and are used by both former string-protocol endpoints.

---

## Explicitly rejected as over-engineering (applies across all phases)

No `domain/usecases/` layer beyond the one exception (ADR-009). No repositories for the 12 single-owner tables (ADR-003). No DTO/entity split outside the three repository-backed tables. **No `freezed`/`riverpod_generator`** (ADR-002) — solo developer, live production data; codegen adds a build step and a merge-conflict surface for state classes written once during a bounded migration window. No DI container beyond `ProviderScope` (ADR-010); singletons convert to providers only when a specific test needs a fake. No dialog-to-route conversion (ADR-007). No restyling of `screens/wrapped/**`. No rewrite of `RealtimeSubscriptionManager` (ADR-005).

---

## Definition-of-Done traceability

This is the authoritative 25-item checklist. Every item maps to exactly one owning phase (or "already true, guarded from Phase 0") and one verification method — no item is left as "reviewed and hoped to remain true."

| # | Criterion | Delivered by | Verified by |
|---|---|---|---|
| 1 | No feature screen directly accesses Supabase | Already true; Phase 0 arch-test guards it | `test/architecture_test.dart` |
| 2 | No feature screen owns Realtime subscriptions | Already true; Phase 0 arch-test guards it | `test/architecture_test.dart` |
| 3 | Provider is removed | Phase 6 | `provider:` absent from `pubspec.yaml` |
| 4 | `RelationshipProvider` is removed | Phase 5b | `grep` returns 0 |
| 5 | `CoupleSession` owns application session state | Phase 1 | 7 `SessionStage` widget tests |
| 6 | `SessionStage` is the single readiness state | Phase 1 | same 7 widget tests; `grep` confirms no second readiness function exists |
| 7 | `go_router` owns navigation decisions | Phase 3 | 0 `MaterialPageRoute`; redirect tests |
| 8 | `navigatorKey` is removed if no longer required | Phase 3 | file deleted once `NotificationService`'s last direct-push site converts; `grep` == 0 |
| 9 | Services do not import/push screens | Phase 3 | `test/architecture_test.dart` |
| 10 | Feature boundaries are documented and enforced | Phase 0 (documented: `feature-boundaries.md`) + Phase 0 (harness) + Phase 7b (tightened, enforced) | `feature-boundaries.md` review + `test/architecture_test.dart` |
| 11 | Repository boundaries are documented | Phase 0 (this specification: ADR-003 + `feature-boundaries.md`'s "Data owned" column) | doc review — satisfied as of this planning phase, re-verified at Phase 4 |
| 12 | Three current shared repositories exist | Phase 4 | row-mapping unit tests |
| 13 | Domain models are immutable where required | Phase 4 | `test/architecture_test.dart` (all-`final`, applied to the 5 identified mutable models + any future model) |
| 14 | SharedPreferences keys are centralized and preserved | Phase 0 (centralized) + every subsequent phase (preserved) | `test/architecture_test.dart` (no literals) + hydration fixture test (Phase 5) proving preservation across the state split |
| 15 | `ScrapbookShareUseCase` owns cross-feature scrapbook sharing | Phase 8 | unit test (success + both partial-failure branches) |
| 16 | `ScrapbookRef` replaces the string protocol | Phase 8 | `grep` for `'[scrapbook]:'` == 0; `ScrapbookRef` round-trip test |
| 17 | Realtime ownership is centralized and lifecycle-safe | Phase 6 (code) + already-decided architecture (ADR-005/ADR-013 Rules A/B/C) | `RealtimeSubscriptionManager` regression tests (item 22) + `test/architecture_test.dart` (items 1–2) jointly demonstrate centralization |
| 18 | Dynamic theme usage is removed | Phase 7 | `test/architecture_test.dart` |
| 19 | Design tokens are centralized | Phase 7 | color-literal budget check |
| 20 | Shared components follow the promotion rule | Phase 7b | `test/architecture_test.dart` |
| 21 | Critical hydration behavior has regression tests | Phase 5 | hydration fixture test |
| 22 | Realtime lifecycle has regression tests | Phase 6 | `RealtimeSubscriptionManager` tests (dedup, teardown, no-duplicate-on-resubscribe, full-teardown-on-disconnect/logout) |
| 23 | Authentication/pairing flows have appropriate tests | Phases 1, 3 | `SessionStage` widget tests + redirect tests + pairing integration test |
| 24 | `flutter analyze` is clean | every phase | CI gate |
| 25 | Full test suite passes | every phase | CI gate |
