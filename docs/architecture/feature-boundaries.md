# Feature Boundaries

**PROPOSED.** The `lib/features/` partition (ADR-001), derived from the app's actual screens and Supabase tables rather than assumed a priori. For each feature: what it owns, what must not live inside it, its dependencies on other features, and which Supabase table(s) it is the sole or primary reader/writer of.

**A note on naming against a generic feature template.** A generic feature list often names `profile` and `doodle_notes` as top-level features. In Days Together specifically: `profile` is not a separate top-level feature — profile fields are owned by `ProfileController` *inside* `relationship` (see ADR-002/ADR-001's rationale: profile and license data are both the couple's shared identity data, split from `authentication`'s session identity by state ownership, not by screen). `doodle_notes` and `scrapbook` are the same feature under two names in this codebase — `noteit_screen.dart` is both; this document uses `scrapbook` throughout and notes the alias here rather than duplicating the feature under two names.

**Cross-feature rule (enforced by the architecture test, ADR-001/ADR-008):** a feature may depend on `core/` and `shared/` freely. A feature may depend on another feature **only** through that feature's public state (a Riverpod provider intentionally exported), never through a private/internal file path. `dashboard` and `wrapped` are the two features expected to have broad fan-out (they legitimately read from most others) — that breadth is a fact about what a dashboard/year-in-review aggregator is, not a violation, provided each dependency goes through a public provider.

**No circular dependencies.** Feature dependencies must form a directed acyclic graph. The specific cycle to guard against, because two of its four edges already exist in some form today: `timeline → scrapbook → chat → relationship → timeline`. Concretely forbidden: `relationship` (the base every other feature already depends on) must never depend back on `timeline`, `scrapbook`, or `chat`; and `scrapbook`'s dependency on `chat` (via `ScrapbookShareUseCase`, the one sanctioned cross-feature link, see ADR-009/ADR-013) must remain one-directional — `chat` must never import anything from `scrapbook`. The architecture test (`testing-strategy.md`) checks this by asserting the feature import graph is acyclic, not merely by checking pairwise rules, so a longer cycle through several features would also be caught.

## Feature dependency matrix

| Feature | Owns (state) | May depend on | Must NOT depend on | Data owned (tables) | Shared services consumed |
|---|---|---|---|---|---|
| `authentication` | `CoupleSession`, `SessionStage` | `core` | every other feature | — (Supabase Auth, not a table) | `core/storage` (none directly) |
| `relationship` | `WorkspaceController`, `LicenseController`, `ProfileController` | `authentication`, `core` | `timeline`, `scrapbook`, `chat`, and all other feature-data domains | `users`, `couples`, `license_details` | `core/storage` |
| `timeline` | timeline items | `relationship`, `core` | `scrapbook`, `chat` | `timeline_items` | `core/storage` |
| `scrapbook` | canvas drafts, `ScrapbookShareUseCase` | `relationship`, `chat` (via `ScrapbookShareUseCase` only), `core` | `timeline` | `love_notes` (scrapbook rows) | `core/storage` |
| `chat` | chat messages | `relationship`, `core` | `scrapbook`, `timeline` | `love_notes` (chat rows) | — |
| `bucket_list` | bucket items | `relationship`, `core` | all other feature-data domains | `bucket_list` | — |
| `calendar` | events | `relationship`, `core` | all other feature-data domains | `calendar_events` | — |
| `gift_reminders` | reminders | `relationship`, `core` | all other feature-data domains | `gift_reminders` | — |
| `topic_cards` | deck, likes | `relationship`, `core` | all other feature-data domains | `topic_cards`, `topic_card_likes` | — |
| `mood` | mood entries, prompts | `relationship`, `core` | all other feature-data domains | `moods`, `daily_questions` | — |
| `currently` | love-tap status | `relationship`, `core` | all other feature-data domains | `love_taps` | — |
| `love_studio` | (reads `WorkspaceController.isPremium`) | `relationship`, `core` | all other feature-data domains | `time_capsules` | `AIService` |
| `wrapped` | (read-only aggregation) | `timeline`, `bucket_list`, `mood`, `currently`, `relationship`, `core` (public providers only) | writes to any other feature's data | — | — |
| `dashboard` | (read-only summaries) | broadly, by design (public providers only) — `relationship`, `timeline`, `bucket_list`, `mood`, `currently`, `scrapbook`, `chat`, `core` | writes to any other feature's data | — | — |
| `settings` | (no domain state of its own) | `authentication`, `relationship`, `core` | feature-data domains beyond triggering their logout/deletion effects | `user_notification_preferences` | — |

**How `dashboard`/`wrapped` read from many features without violating the acyclic rule:** both depend *outward* only, and only on each dependency's public provider (e.g. `dashboard` reads `timeline`'s exported `timelineItemsProvider`, never an internal file). Neither `timeline`, `bucket_list`, `mood`, etc. import anything from `dashboard` or `wrapped` in return — the fan-in is real but strictly one-directional, which is what keeps it a legitimate breadth-of-composition fact rather than a cycle.

**How `scrapbook` and `chat` communicate without direct feature coupling:** this is the one sanctioned cross-feature write path in the app, and it does not use a direct import of `chat`'s internals from `scrapbook` (or vice versa). `ScrapbookShareUseCase` (owned by `scrapbook`, per ADR-009) takes `chat`'s **public** `ChatController` as a constructor dependency — `scrapbook` depends on `chat`'s public contract, never the reverse, and the two features exchange data through the typed `ScrapbookRef` (ADR-013), never a string convention. This is the pattern to follow for any future cross-feature write: one direction of dependency, through a public provider, mediated by a typed reference — not a bidirectional import, and not a shared mutable table accessed by both sides' private code.

---

### `authentication`
**Owns:** `CoupleSession` (identity: `userId`, `isSupabaseAvailable`, auth state), sign-up/sign-in/Google-sign-in flows, session-derived `SessionStage`, the `WelcomeScreen`/`auth_screen.dart` UI.
**Must not contain:** couple/pairing state (that's `relationship`), any license or profile field.
**Depends on:** `core` only.
**Table(s):** none directly — `auth.users` via Supabase Auth SDK, not a queried table.

### `relationship`
**Owns:** pairing (create/join/recover/disconnect), the couple workspace (`WorkspaceController`), profile fields (`ProfileController`), license fields (`LicenseController`), the license screen and its cards/painters/export tooling (post-decomposition, `god-file-decomposition.md` §1), the relationship-duration/milestone screen and its stats.
**Must not contain:** identity/session fields owned by `authentication`; any other feature's data.
**Depends on:** `authentication` (reads `CoupleSession.coupleId`/`partnerId` via its public provider).
**Table(s):** `users`, `couples`, `license_details` — the three repository-backed tables (ADR-003).

### `timeline`
**Owns:** timeline items CRUD, the storybook reading mode, memory detail screen, the `add_item_dialog` creation flow, the timeline-scrubber UI.
**Must not contain:** scrapbook/chat logic.
**Depends on:** `relationship` (couple scoping via `CoupleSession`), `core/storage` (image upload via `StorageUrlService`).
**Table(s):** `timeline_items`. Storage bucket: `timeline`.

### `vault`
**Owns:** vault items CRUD, PIN lock state and auto-lock lifecycle, the decoy-mode screen.
**Must not contain:** any non-vault feature's data.
**Depends on:** `relationship`, `core/storage`.
**Table(s):** `vault_items`. Storage bucket: `vault-photos`.

### `scrapbook`
**Owns:** noteit canvas creation/editing, drafts (`NoteitDraftStore`), the canvas widget cluster (`raster_canvas`, `rich_text_editor_overlay`, `custom_backgrounds`, `text_overlay_widget`), `ScrapbookShareUseCase`, `ScrapbookRef`.
**Must not contain:** chat message rendering (that's `chat`) — it may only *reference* chat through `ScrapbookShareUseCase`'s dependency on `chat`'s public `ChatController`.
**Depends on:** `relationship`, `chat` (via `ScrapbookShareUseCase` only — see ADR-009), `core/storage`.
**Table(s):** `love_notes` (scrapbook rows only — see the `chat` entry below for the shared-table resolution), storage bucket `love-notes`.

### `chat`
**Owns:** chat message list and sending, the `love_chat_screen`.
**Must not contain:** scrapbook canvas creation.
**Depends on:** `relationship`.
**Table(s):** `love_notes` (chat rows only, distinguished server-side by `type`, per ADR-005's fix to the current shared-key collision — each feature gets its own subscription key, `love_notes:scrapbook_$coupleId` / `love_notes:chat_$coupleId`).

### `bucket_list`
**Owns:** bucket list CRUD, its screen.
**Depends on:** `relationship`.
**Table(s):** `bucket_list`.

### `calendar`
**Owns:** calendar events CRUD, its screen. **Must not** push a second app shell (fixed navigation bug, ADR-007) or reach into any other feature.
**Depends on:** `relationship`.
**Table(s):** `calendar_events`.

### `gift_reminders`
**Owns:** gift reminder CRUD, its screen.
**Depends on:** `relationship`.
**Table(s):** `gift_reminders`.

### `topic_cards`
**Owns:** topic card deck, likes.
**Depends on:** `relationship`.
**Table(s):** `topic_cards`, `topic_card_likes`.

### `mood`
**Owns:** daily mood entries, the daily-question prompt, the love-meter screen.
**Depends on:** `relationship`.
**Table(s):** `moods`, `daily_questions`.

### `currently`
**Owns:** the "currently" status/love-tap feature.
**Depends on:** `relationship`.
**Table(s):** `love_taps`.

### `love_studio`
**Owns:** AI love-letter generation (`AIService`), time capsules, relationship insights, the premium paywall gating these three.
**Must not contain:** premium *state* (that's `WorkspaceController` in `relationship`) — it *reads* the premium flag, it does not own it.
**Depends on:** `relationship`.
**Table(s):** `time_capsules`. AI letters and insights are generated client-side/templated, no dedicated table.

### `wrapped`
**Owns:** the Wrapped year-in-review experience, its cinematic background/gradient system (`WrappedGradients`, intentionally separate from the app theme per ADR-008), the archive screen.
**Depends on:** aggregates read-only summaries from `timeline`, `bucket_list`, `mood`, `currently`, and others via each feature's public provider — this is expected, documented fan-in, analogous to `dashboard`.
**Table(s):** none of its own; read-only aggregation.

### `dashboard`
**Owns:** the Home tab composition (`bento_grid.dart`'s successor), milestone/presence/activity summary cards.
**Must not contain:** any feature's actual CRUD logic — only read-only summaries and navigation entry points into other features.
**Depends on:** broadly, by design — `relationship`, `timeline`, `bucket_list`, `mood`, `currently`, `scrapbook`, `chat`, and others, each through its public provider. This is the one feature where high fan-in is correct, not a smell (ADR-001).
**Table(s):** none of its own.

### `settings`
**Owns:** the settings tab, theme selection UI (post-relocation from `widgets/theme_selector.dart`), notification preferences, music controls, logout/account-deletion triggers (which now only clear state and let the router redirect, per ADR-007 — no more `import '../main.dart'`).
**Depends on:** `authentication`, `relationship` (for logout/deletion), `core/design_system`.
**Table(s):** `user_notification_preferences`.

---

## What is deliberately NOT a feature

- **`storage` / signed-URL resolution** — lives in `core/storage` (currently `StorageUrlService`), because it is infrastructure used by every feature with images, not a feature itself.
- **`notifications`** — `NotificationService` lives in `core/` (or `app/`), not `features/`, because per ADR-007 it becomes a thin payload-to-route resolver with no feature-specific UI knowledge.
- **`home_widget`** — the Android/iOS home-screen widget integration stays a `core/` service; it has no in-app UI screen of its own.
