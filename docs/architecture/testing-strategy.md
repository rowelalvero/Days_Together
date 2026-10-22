# Testing Strategy

**PROPOSED**, built on the **CURRENT STATE** baseline of 82 passing tests, 0 widget tests, `flutter analyze` clean. See ADR-012 for the decision record and its rationale against both "manual review only" and "coverage-percentage targets."

## Why the pyramid is currently missing its middle and top tiers

Zero widget tests exist today not because none were judged worth writing, but because they are **structurally unreachable**: with no dependency injection (13 hand-rolled singletons, ADR-010), a widget test touching auth, pairing, or realtime state would need to exercise a real Supabase client, real platform channels, or a real global singleton — impractical, so none were attempted. This is the direct, causal link between ADR-002 (Riverpod adoption) and this document: `ProviderScope(overrides: [...])` is what makes fakeable dependencies possible, and fakeable dependencies are the prerequisite for everything below the base tier.

## The pyramid

```
                    Integration (fewest, most expensive)
                   /  pairing E2E, disconnect/re-pair,
                  /   scrapbook-share transaction
                 /---------------------------------------
                /  Widget
               /   SessionStage → screen rendering,
              /    router redirect resolution
             /---------------------------------------------
            /  Unit (most, cheapest)
           /   pure functions, model serialization,
          /    repository row-mapping, AppFailure mapping
         /-------------------------------------------------
```

### Unit tests (base)

**What:** pure functions (consolidated `DateHelper` duration/milestone/weekend-count math — ADR-009), model serialization round-trips (existing, healthy pattern — keep as-is for all 16+ model files), repository row-mapping against fake `Map<String, dynamic>` row data with **no network** (the three repositories from ADR-003 — the highest-value new tests in the whole migration, since they verify the exact boundary where Supabase column names either do or don't leak into the app's typed models), `AppFailure` mapping logic (ADR-011 — given a raw `PostgrestException`/`StorageException` with a known status code, assert the correct `AppFailure` subtype results).

**New artifacts this tier specifically requires:**
- `LicenseQrCodec` round-trip test (`god-file-decomposition.md` §1) — the QR wire format currently has zero coverage.
- `ScrapbookRef` round-trip test (`god-file-decomposition.md` §3).
- `countWeekends`/`countOccurrencesOfDate` closed-form vs. original-loop equivalence test (Migration Phase 0) — verifies the performance fix doesn't silently change the displayed statistic.
- Repository row-mapping tests for `UserRepository`/`CoupleRepository`/`LicenseRepository` (target 15+, per Migration Phase 4).

### Widget tests (middle) — currently zero, first ones land in Migration Phase 1

**What becomes testable, and why Phase 1 specifically unlocks it:** once `CoupleSession` exists behind `ProviderScope`, `AppHome` (soon, the go_router redirect) can be pumped against a **faked** `CoupleSession` for each of the 7 `SessionStage` values, asserting the correct screen renders — without touching real Supabase, real auth, or real platform channels. This single test file becomes the template for testing any other screen whose rendering depends on session/pairing state, and directly satisfies **Definition-of-Done item 20** ("auth/pairing flows have widget/integration coverage").

**Ongoing pattern going forward:** any screen whose content branches on a Notifier's state gets a widget test using the same `ProviderScope(overrides: [...])` technique — a fake Notifier with controlled state, pumped, asserted against.

### Integration tests (top, smallest volume)

**What:** full flows through a real widget tree with faked data sources at the network boundary only (Supabase itself is faked; everything above it is real). Three flows are named explicitly as worth this investment, because each is either a multi-screen sequence or the one genuine cross-feature transaction in the app:
1. **Pairing:** create workspace → generate code → (simulated) partner joins → both sides reach `SessionStage.ready`.
2. **Disconnect / re-pair:** paired couple disconnects → both sides return to unpaired state → one side pairs with a different partner → no residual state from the first couple (verifies the purge contract from `caching-strategy.md`).
3. **Scrapbook sharing:** the `ScrapbookShareUseCase` (`god-file-decomposition.md` §2) exercised end-to-end through the noteit screen and the chat feature, including its partial-failure case (note created, chat notification fails) — since this is the one place the app does a real multi-step transaction, it is the one place worth testing as a whole sequence rather than as isolated units.

No integration test is proposed for the 12 single-owner-table CRUD features (bucket list, calendar, etc.) — their unit + widget coverage is sufficient given they are each a simple, single-table read/write with no cross-feature interaction to verify end-to-end.

## The fourth, parallel tier: architecture tests

Distinct from the pyramid above — these don't test *behavior*, they test *structure*, and they run on every `flutter test` invocation alongside everything else. Introduced (mostly empty, but real and running) in Migration Phase 0, tightened as each later phase makes a new rule true. No new tooling: plain Dart file-system/import-graph assertions under `test/architecture_test.dart`.

| Rule | Enforces DoD item | Lands in phase |
|---|---|---|
| No file in `lib/screens/`\`widgets/` (later: `lib/features/**/presentation/`) imports `supabase_flutter` | 1 | 0 (already true) |
| No `StreamSubscription`/`.channel(`/`.stream(` in `lib/screens/`\`widgets/` | 2 | 0 (already true) |
| No `lib/services/**` file imports `lib/screens/**`\`lib/widgets/**` | 7 | 3 |
| No file in `lib/features/<A>/**` imports a non-public path in `lib/features/<B>/**` | 9 | 0 (harness) → 7b (tightened, active) |
| Every class in `lib/models/**` has all-`final` fields | 11 | 4 |
| No raw `SharedPreferences` string-literal key outside `PrefsKeys` | 12 | 0 |
| No `dynamic theme` parameter anywhere in `lib/` | 15 | 7 |
| No file under `lib/shared/**` is imported by exactly one feature (i.e., nothing sits in shared "just in case") | 17 | 7b |

This is what converts eight Definition-of-Done items from "true at the moment the migration finished" into "the test suite fails the instant it stops being true" — a ratchet, not a one-time audit.

## Mocking approach

No new mocking library (`mockito`, `mocktail`) is introduced — both are absent from `dev_dependencies` today and stay absent. `ProviderScope(overrides: [...])` is Riverpod's own, sufficient fake-injection mechanism for every test category above; introducing a separate mocking framework on top would be redundant tooling for a problem Riverpod's own architecture already solves (consistent with ADR-002's and ADR-010's broader "no unjustified new dependency" stance).

## What's explicitly out of scope

Coverage-percentage targets (ADR-012's rejected Option 2) — this document names *specific, risk-targeted* tests to write, not a number to hit. End-to-end tests driving a real device/emulator against a real (staging) Supabase project — valuable, but a CI/infrastructure investment separate from this architecture migration; the integration tier above fakes the network boundary specifically to stay fast and hermetic.
