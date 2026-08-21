# ADR-011: Error Handling

## Status
Accepted

## Context
**CURRENT STATE, verified:** error handling in Days Together is inconsistent by construction, not by oversight — different layers were written at different times with no shared convention. Providers generally wrap Supabase calls in `try/catch` and either `debugPrint` and swallow the error, or leave `_isLoading` in an inconsistent state on failure. Some methods (e.g. `ProfileService.uploadAvatar`, `NoteitSyncManager`) distinguish recoverable from non-recoverable failures via Postgrest/Storage error codes (`42501`, `400`, `403` treated as terminal; everything else retried) — a real, useful pattern that exists in exactly two places and nowhere else. No domain-level error type exists anywhere in `lib/`; a raw `PostgrestException`, `StorageException`, or `AuthException` is the error type a caller (and sometimes, indirectly, the UI) sees.

There is no crash-reporting or centralized logging integration in the app.

## Problem
As state moves into Riverpod notifiers (ADR-002) and repositories are introduced for three tables (ADR-003), inconsistent error handling would be baked into new code exactly as it exists in old code, and the useful recoverable/non-recoverable distinction found in `NoteitSyncManager` would remain undiscoverable and unreused elsewhere.

## Options considered

1. **Leave error handling as an unspecified, per-file convention, same as today.** Rejected: guarantees the same inconsistency gets carried into every newly written notifier/repository during the migration.
2. **A full typed error hierarchy (sealed `AppException` with dozens of subtypes) mapped at every layer boundary, with mandatory Result/Either return types everywhere.** Rejected as excessive for this app's actual failure surface, which the audit shows is small and well-understood: network/Postgrest errors, Storage errors, Auth errors, and local persistence errors — four categories, not dozens.
3. **A small, shared error taxonomy, mapped once at the data-layer boundary, with the existing recoverable/non-recoverable distinction generalized rather than reinvented.** Chosen.

## Decision
Introduce one shared error type, `AppFailure`, in `lib/core/errors/` with exactly the categories the audit found actually occurring:

```dart
sealed class AppFailure {
  const AppFailure(this.message, {this.cause});
  final String message;
  final Object? cause;
}
class NetworkFailure extends AppFailure { const NetworkFailure({...}) ...; }
class AuthFailure extends AppFailure { const AuthFailure({...}) ...; }
class AuthorizationFailure extends AppFailure { const AuthorizationFailure({...}) ...; }  // RLS/permission denials
class ValidationFailure extends AppFailure { const ValidationFailure({...}) ...; }
class NotFoundFailure extends AppFailure { const NotFoundFailure({...}) ...; }
class StorageFailure extends AppFailure { const StorageFailure({...}) ...; }             // Supabase Storage
class UnknownFailure extends AppFailure { const UnknownFailure({...}) ...; }
```

**Mapping happens once, at the repository/service boundary** (the same boundary defined in ADR-004): a raw `PostgrestException`/`StorageException`/`AuthException` is caught there and converted to an `AppFailure`, using the existing status-code-based recoverable/non-recoverable distinction from `NoteitSyncManager`/`ProfileService` as the pattern (codes `42501`/`400`/`403`-class → `AuthorizationFailure`/`ValidationFailure`, non-retryable; connectivity/5xx-class → `NetworkFailure`, retryable). **UI code never sees a raw Supabase exception type** — a notifier's error state is always an `AppFailure`.

**User-facing messages** are derived from `AppFailure` at the presentation layer (a small mapping function per feature, or a shared default), not stored inside the failure object itself — keeping the data layer free of UI-string concerns.

**Retry behavior:** the existing per-feature retry patterns (`NoteitSyncManager`'s backoff queue is the most sophisticated example already in the codebase) are preserved as-is; this ADR does not mandate a single app-wide retry policy, only a shared vocabulary for *classifying* what's retryable.

**Logging:** errors are `debugPrint`-logged at the point of mapping (consistent with today), with a single format include the `AppFailure` subtype and the original `cause`. Crash reporting / remote logging integration is explicitly **out of scope** for this architecture migration — it is a production-readiness concern already tracked separately (see the prior full-codebase audit's production-readiness findings), not an architectural layering decision.

## Reasons

- The app's actual failure surface, as observed across the codebase, is small — four to seven categories, not the dozens a full typed hierarchy would imply — so a small taxonomy is a proportionate match, not an under-engineered shortcut.
- One genuinely good pattern already exists in the codebase (`NoteitSyncManager`'s recoverable/non-recoverable status-code split) — generalizing it app-wide reuses proven logic instead of inventing a new classification scheme from nothing.
- Mapping errors once, at the repository/service boundary, means every notifier and every screen benefits from consistent handling without each having to reimplement classification logic.

## Consequences

**Positive:** every repository and every ported notifier gets the same, small error vocabulary instead of reinventing `try/catch` handling per file. The one genuinely good pattern already in the codebase (`NoteitSyncManager`'s recoverable/non-recoverable split) becomes the app-wide convention instead of a local curiosity.

**Negative:** every repository/service method touched during the migration needs its `try/catch` rewritten to map into `AppFailure` — this is spread across Phases 4 and 6 (wherever a repository or ported notifier is created) rather than done as a single upfront pass, so it doesn't become its own dedicated phase.

## Rejected alternatives
- Status quo, no shared type (option 1) — carries inconsistency into new code.
- Full typed hierarchy with Result/Either everywhere (option 2) — more ceremony than the app's actual four-category failure surface warrants.
