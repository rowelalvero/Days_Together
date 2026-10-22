# ADR-004: Supabase Integration Boundaries

## Status
Accepted

## Context
**CURRENT STATE, verified:** grepping every `import .*supabase` across `lib/` returns 23 files, all within `providers/`, `services/`, `repositories/`, plus `main.dart` (initialization only, zero call sites). **Zero files under `lib/screens/` or `lib/widgets/` import or call Supabase.** This is the single most reassuring finding of the architecture audit — the feared "UI directly hits the database" anti-pattern does not exist in this codebase.

The one nuance: `lib/widgets/storage_image.dart` calls `StorageUrlService.instance` directly (lines 68, 91, 100, 110) for signed-URL resolution, and that service in turn calls Supabase Storage. This is possible only because `StorageUrlService` is a global singleton reachable from anywhere (see ADR-002/ADR-010 on the DI gap) rather than because a widget was ever designed to know about Supabase.

Where the real coupling lives: 13 of 16 providers embed raw `.from(...)`/`.rpc(...)`/`.storage` calls directly, with no intermediating repository or consistent service boundary.

## Problem
Without a written rule, a future change could easily introduce the UI→Supabase coupling that the audit confirms does not currently exist — for example, a screen reaching for `Supabase.instance.client` directly "just this once" for a quick read. The `storage_image.dart` case shows how a service being globally reachable makes this easy to do accidentally.

## Options considered

1. **No written rule; rely on code review.** Rejected: the app has grown to 137 files without one, and the audit found the boundary has held by discipline alone so far — that isn't guaranteed to continue, especially with feature-based reorganization (ADR-001) inviting new files.
2. **Mandate every Supabase access go through a repository.** Rejected: contradicts ADR-003's finding that repository-per-table is ceremony without payoff for 12 of 15 tables; would force wrapping a healthy service layer that has no problem to solve.
3. **Layered rule matching the audit's actual findings, enforced by the architecture test suite.** Chosen.

## Decision
Formalize the boundary that already exists in practice:

```
Screen / Widget
     ↓ (Provider/Riverpod state only — never Supabase types)
Provider / Riverpod Notifier
     ↓
Repository (for users/couples/license_details — ADR-003)   OR   Service (for everything else)
     ↓
Supabase Client (auth / postgrest / realtime / storage)
```

**Rules, each enforced by `test/architecture_test.dart` (introduced Migration Phase 0):**
- No file in `lib/screens/**` or `lib/widgets/**` (post-relocation: `lib/features/**/presentation/**`) may import `package:supabase_flutter`. This formalizes what is already true today.
- No file in `lib/screens/**`/`lib/widgets/**` may reach a service singleton whose name matches `*Service`/`*Manager` for anything beyond pure, non-Supabase, non-I/O helpers (e.g. `AIService`'s templated-text generation stays screen-callable; `StorageUrlService`'s network calls do not — `storage_image.dart`'s direct call is grandfathered as the exception this ADR documents, and closes only when Phase 6's DI work makes `StorageUrlService` an injected dependency of the relevant providers instead).
- A **direct** Supabase call from a provider is acceptable for the 12 single-owner tables (ADR-003); it must go through a repository for `users`, `couples`, `license_details`.
- Realtime subscriptions are never opened by a screen or widget — see ADR-005.

## Reasons

- The boundary already holds in practice (0 of 23 Supabase imports are in the UI layer) — this ADR protects a real, already-achieved property rather than creating a new one from scratch.
- An architecture-test rule costs almost nothing to add today, precisely because so little of the codebase currently violates it — the cost of waiting until it's violated more broadly would be much higher.
- The one documented exception (`storage_image.dart`) is named honestly rather than the rule being weakened to accommodate it, keeping the rule meaningful.

## Consequences

**Positive:** a rule that matches reality is enforceable without a painful migration — most of the codebase already complies. The architecture test suite catches the one class of regression (a new file calling Supabase from the UI layer) that would otherwise require vigilant review forever.

**Negative:** `storage_image.dart`'s direct service call remains a documented, temporary exception until Phase 6 — this ADR does not pretend the boundary is currently perfect, only that it is close and worth protecting.

## Rejected alternatives
- No written rule (option 1) — insufficient given the app's growth trajectory and the one already-documented leak.
- Blanket repository mandate (option 2) — reintroduces the ceremony ADR-003 explicitly rejected.
