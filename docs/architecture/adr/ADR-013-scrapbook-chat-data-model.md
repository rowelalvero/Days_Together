# ADR-013: The `love_notes` Table Collision — Data Model Analysis

## Status
Accepted (decision on code-layer fix and process; schema question left as an explicit OPEN QUESTION for a future ADR)

## Context
**CURRENT STATE, verified:** `lib/providers/noteit_provider.dart:44` and `lib/providers/love_chat_provider.dart:21` both declare `tableName = 'love_notes'`. Because `RealtimeSubscriptionManager` keys its multiplexed streams by `'${tableName}_$coupleId'` (ADR-005), both providers share exactly one subscription slot and each independently filters the same raw stream client-side: `love_chat_provider.dart:45` keeps rows where `type == 'chat'`; `noteit_provider.dart:76` keeps rows where `type != 'chat'`.

Separately, cross-feature communication between these two already-conflated features happens through an untyped string protocol: `noteit_screen.dart:653-655` writes `'[scrapbook]:${newItem.id}'` as a chat message body, and `bento_grid.dart:1999-2012` parses that prefix back out with `jsonDecode` and an untyped `int?` switch, with no shared type connecting writer and reader.

ADR-005 already decided the code-layer fix (distinct subscription keys, server-side `type` filtering) as part of Migration Phase 6. This ADR exists to answer the deeper question ADR-005 deliberately did not: **is this a provider-cleanup problem, or a data-model problem** — and if the latter, should the schema itself eventually change?

## Analysis

**1. Do scrapbook notes and chat messages represent the same underlying domain data?**
No, not really — they share physical proximity (one table) but not domain identity. A chat message is an ephemeral conversational turn: short-lived in relevance, read in a linear stream, with no persistent "artifact" status. A scrapbook note (canvas drawing/photo/text) is a persistent, revisitable artifact — closer in kind to a Timeline memory than to a chat message. That they currently share a table appears to be an implementation convenience (both are "things one partner sends the other," both needed roughly the same columns: `couple_id`, `sender_id`, `content`/`image_url`, `created_at`) rather than a deliberate domain modeling decision.

**2. Are they separate concepts stored in one table?**
Yes, confirmed. The `type` column is the only thing distinguishing a scrapbook row from a chat row; every other column is shared.

**3. Is a typed discriminator required?**
Yes — and one exists today only at the *database* layer (the `type` text column), not at the *application* layer. Dart code currently re-derives the distinction via ad-hoc string comparison (`type == 'chat'`) in two different providers, rather than through a shared enum. This ADR mandates introducing a proper Dart-side discriminator (`enum LoveNoteType { chat, scrapbook }` or feature-specific equivalents) as part of the Phase 6 provider port, independent of any schema decision.

**4. Should server-side filtering replace client-side filtering?**
Yes — already decided in ADR-005, reaffirmed here as the immediate, schema-unchanged fix: each feature's realtime query includes `.eq('type', 'chat')` / `.eq('type', 'scrapbook')` server-side, and each gets its own subscription key (`love_notes:chat_$coupleId` / `love_notes:scrapbook_$coupleId`) rather than sharing one raw, client-filtered stream.

**5. Should the schema eventually separate Chat and Scrapbook into distinct tables?**
**OPEN QUESTION — not decided by this ADR.** Arguments for splitting: cleaner RLS policies per concept if they ever need to diverge (e.g. different retention rules for ephemeral chat vs. persistent scrapbook artifacts); a smaller, more legible schema per table; removes the `type` discriminator entirely rather than managing it carefully. Arguments against: single-table-with-discriminator is a legitimate, common pattern (not automatically a smell) when the shared columns genuinely are shared and the split doesn't need to happen at the storage layer to be correct at the application layer; splitting a live table with existing rows is itself a real-data schema migration with its own risk, entirely disproportionate to a problem that Migration Phase 6's application-layer fix (rules 3–4 above) already fully resolves from the user's and the developer's perspective. **No concrete pain point currently demonstrates the split is needed** — RLS policies for `love_notes` are not currently diverging between the two use cases, and no performance or retention issue has been identified.

**6. Should the current schema remain unchanged during this architecture migration?**
**Yes, decided.** Per the planning brief's explicit constraint ("do not modify the database in this planning phase," extending through the migration's execution unless a future ADR revisits this question with a demonstrated need), the `love_notes` table's schema is not touched by this migration. All fixes in this ADR and ADR-005 are application-layer only: typed discriminator, server-side filtering, distinct subscription keys.

## Decision

1. **Schema:** unchanged. No migration to `supabase/migrations/` is part of this architecture work.
2. **Application-layer discriminator:** introduce a typed enum shared between the `chat` and `scrapbook` features (living in whichever of the two — or a small shared location — is least coupled; a `lib/core/` location is acceptable here specifically because the discriminator describes the *shared table's* rows, not either feature's private domain model).
3. **Realtime:** per ADR-005 — distinct subscription keys, server-side `type` filtering. Executed in Migration Phase 6.
4. **Cross-feature reference type:** the ad-hoc `'[scrapbook]:'` string protocol is replaced by `ScrapbookRef` (Definition-of-Done item 14, detailed in `god-file-decomposition.md` §3) — a small, explicit type with `toChatPayload()`/`fromChatPayload()` methods, so the writer (`scrapbook`, via `ScrapbookShareUseCase`) and the reader (`chat`, and `dashboard`'s bento grid) share a compiler-checked contract instead of a string convention neither side can verify against the other at compile time.

**Standing rule this ADR establishes:** string-prefix protocols (`'[tag]:...'`) are prohibited for cross-feature communication going forward. Any feature needing to reference another feature's entity does so through a typed reference class (following `ScrapbookRef`'s pattern), never a parsed string convention. This is added to `architecture-rules.md` as a durable rule, not a one-time fix specific to scrapbook/chat.

## Reasons

- Splitting the table now would be a real-data schema migration carrying disproportionate risk against a problem the application-layer fix (typed discriminator, server-side filtering, distinct subscription keys) already fully resolves from both the user's and the developer's perspective.
- No concrete pain point (diverging RLS needs, retention differences, performance issue) currently demonstrates that a schema split is actually needed — deciding it under migration time pressure, without that evidence, risks solving a problem that doesn't yet exist while the real, confirmed bug (the shared subscription key) goes unfixed.
- Leaving the collision entirely unaddressed was rejected because it is a real, if currently low-severity, bug class that would worsen the moment a third `love_notes`-backed feature is added.

## ⚠️ Corrected on implementation (Phase 6a)

**Decision point 4's "server-side filtering" and this ADR's reaffirmation of ADR-005's fix are both retracted — see ADR-005's own "Corrected on implementation" section for the full technical finding.** In short: the installed `supabase` package's `.stream()` API stores only one `.eq()` filter (verified directly against `SupabaseStreamBuilder`'s source), so `.eq('couple_id', ...).eq('type', ...)` silently drops the couple scoping rather than combining both filters — the prescribed fix is not achievable without a schema change, which decision point 5 (below) already ruled out for this migration. The shared subscription key was re-examined in light of this and found not to be a bug at all: it is `RealtimeSubscriptionManager`'s intended deduplication behavior (one physical subscription, two client-side-filtered consumers), not a violation of anything. `NoteitController`/`LoveChatController` (Phase 6a) both keep `tableName => 'love_notes'` and client-side filtering, unchanged from the original providers.

**Decision point 3 (the typed Dart-side discriminator) is unaffected by this correction** and still stands as this ADR's mandate for the Phase 6 provider port — `NoteitItem`/`LoveChatMessage`'s existing `type`/derived-sender handling already satisfies it structurally, even without a shared `enum LoveNoteType` extracted yet; that extraction remains open, tracked here rather than newly introduced by this correction.

## Consequences

**Positive:** no risky schema migration on live data — turns out none was ever required, since the "collision" this ADR's motivating context described was already correct, dedup-optimizing behavior rather than a bug. The deeper modeling question is answered honestly — flagged as a real, considered open question rather than either ignored or decided under migration time pressure.

**Negative:** the `love_notes` table remains a single-table-with-discriminator design indefinitely unless a future ADR revisits it — a developer working on either `chat` or `scrapbook` must remember the table is shared and that the `type` column matters, which the typed enum (decision 2) mitigates but doesn't eliminate as a fact about the schema.

## Rejected alternatives
- Splitting the table now, as part of this migration — rejected: no demonstrated need, disproportionate risk on live data for a problem the application-layer fix fully resolves.
- Leaving the client-side filtering and shared subscription key as-is, treating this purely as acceptable technical debt — rejected: it is a confirmed, if currently low-severity, bug class (a third `love_notes`-backed feature would silently join the shared stream with no warning), and ADR-005 already committed to fixing it.
