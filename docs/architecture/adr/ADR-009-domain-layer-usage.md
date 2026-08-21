# ADR-009: Domain Layer — Optional, and Rarely Justified

## Status
Accepted

## Context
The planning brief's proposed target structure includes an optional `domain/` layer (`entities/`, `repositories/` contracts, `usecases/`) per feature. **CURRENT STATE, verified:** the audit searched for evidence of complex, multi-step business processes that would benefit from an explicit use-case abstraction, and found essentially one: `noteit_screen.dart`'s `_sendCanvas()` method (lines 606-696), which renders a canvas to a PNG, writes it to a temp file, calls `provider.sendCanvas(...)`, then cross-domain-mirrors the action into the chat feature via `chatProvider.sendMessage('[scrapbook]:${item.id}', ...)`, then clears a SharedPreferences draft key — a genuine multi-provider transaction, currently living inside a widget's `State` method.

Every other feature examined (bucket list, calendar, gift reminders, vault, topic cards, mood, currently/love-taps, timeline) is single-table CRUD: create/read/update/delete against one Supabase table, surfaced through one provider, with no cross-feature orchestration, no multi-step business rule beyond "write this row" / "read these rows."

Two areas *do* contain real domain logic today, but it is pure computation, not a use-case needing orchestration: relationship duration/milestone math (`relationship_provider.dart:1992-2128`, and independently reimplemented — worse, incorrectly, as an O(days) loop — in `relationship_duration_screen.dart:529-580`), and canvas document semantics (the `canvas_document.dart` model, plus a parallel, legacy, duplicate serialization format found coexisting in `noteit_model.dart`).

## Problem
The planning brief explicitly warns against "blindly applying Clean Architecture." A domain layer with entities, repository contracts, and use-cases for all 15 features would mean roughly 14 of them get a `usecases/` directory containing a single class that does nothing but call the one repository/service method the provider could have called directly — abstraction with no corresponding complexity to manage.

## Options considered

1. **Full domain layer (entities + usecases) for every feature.** Rejected: no evidence of a second use-case-worthy process beyond scrapbook sharing; would produce ~14 features with a single-method `usecases/` folder that adds indirection without benefit.
2. **No domain layer anywhere; pure logic lives wherever it's currently found (including inside widgets).** Rejected: this leaves the confirmed, concrete problems as-is — the O(days) loop re-running inside `build()` on every rebuild, the duplicated `_calculateAge`, and the scrapbook-sharing transaction embedded in a widget's `State` method, none of which is acceptable regardless of whether a formal "domain layer" exists to house the fix.
3. **No domain layer as an architectural tier; pure logic and the one genuine use-case are extracted to well-placed, ordinary classes — a domain layer only where a feature's complexity specifically earns it.** Chosen.

## Decision
**Default:** features are `presentation → data`, with no `domain/` directory. A feature's provider/notifier calls its repository (if it has one, per ADR-003) or service directly; there is no intermediate use-case class.

**The justification test, stated explicitly:** a use case is warranted by genuine business orchestration, a meaningful multi-step state transition, or real cross-feature coordination — **not simply because an operation exists.** This specifically rules out reflexive wrappers like `GetTimelineUseCase`, `GetProfileUseCase`, or `GetUserUseCase` that would do nothing but forward a single call to a repository or provider method the caller could invoke directly — these add a layer of indirection with no corresponding complexity to manage, and are explicitly rejected patterns for this codebase unless a specific feature later demonstrates real orchestration need at that call site.

**The one exception, evaluated against that test:** scrapbook sharing gets a `ScrapbookShareUseCase` (Definition-of-Done item 13), living in `features/scrapbook/domain/` (the only `domain/` directory the migration creates), because it is the one process in the app that is genuinely multi-step and cross-provider — moving it out of `noteit_screen.dart`'s `State` class and into a use-case is not architectural purism here, it is fixing a confirmed bug-prone pattern (a widget method silently doing filesystem I/O, two provider writes, and a prefs mutation as one un-transactional sequence). It passes the test; `GetTimelineUseCase` would not.

**Pure domain math is not a use-case — it becomes plain functions,** consolidated into `DateHelper` (which already exists and already provides equivalent, correct helpers that were bypassed): the duration/milestone calculations from `relationship_provider.dart` and the O(days) `countWeekends`/`countOccurrencesOfDate` loop from `relationship_duration_screen.dart` are both replaced by closed-form functions added to (or already present in) `DateHelper`, called from wherever needs them. No `entities/`, no `usecases/` wrapper — just correct, deduplicated, unit-tested pure functions in the service layer, consistent with the app's already-healthy service-layer pattern (ADR-003's context).

**Canvas document duplication** (the legacy format inside `noteit_model.dart` coexisting with `canvas_document.dart`) is resolved by deletion of the duplicate, not by introducing a domain abstraction over both — this is Phase 0 mechanical cleanup, not a domain-layer decision.

## Reasons

- Only one process in the entire audited codebase (scrapbook sharing) demonstrated the genuine multi-step, cross-provider complexity a use case exists to manage — the other 14 features are single-table CRUD with no corresponding complexity.
- Mandating `domain/usecases/` everywhere would produce ~14 features with a folder containing a single method that does nothing but forward a call — indirection with no complexity to justify it, the opposite of what a domain layer is for.
- The explicit justification test (business orchestration / meaningful state transition / cross-feature coordination) is reusable for any future feature, so the rule scales without needing to be revisited feature-by-feature from scratch.

## Consequences

**Positive:** avoids ~14 features carrying an empty-feeling `domain/usecases/` folder. The one real transactional process (scrapbook sharing) gets exactly the structure it needs — a testable, named class instead of a widget method doing a five-step cross-provider sequence — which directly enables Definition-of-Done item 13.

**Negative:** "domain layer is optional" requires ongoing judgment as features evolve — a future feature that grows genuine multi-step business rules should get a `domain/` directory at that point, and recognizing when that threshold is crossed is a design call, not a mechanical rule (unlike the repository rule in ADR-003, which has two objective conditions).

## Rejected alternatives
- Domain layer everywhere (option 1) — no evidence of corresponding complexity in 14 of 15 features.
- No domain layer and no fix for the confirmed use-case-worthy problem (option 2) — leaves a documented, transactional bug pattern in place.
