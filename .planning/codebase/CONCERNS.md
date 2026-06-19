# Codebase Concerns

**Analysis Date:** 2026-06-19

## Tech Debt

**BaaS SDK Naming Ambiguity:**
- Issue: Legacy naming conventions referring to Firebase (e.g., `isFirebaseAvailable`, `_initFirebaseSync()`) are used to execute Supabase logic and state monitoring.
- Files: `lib/providers/relationship_provider.dart`, `lib/providers/timeline_provider.dart`, etc.
- Impact: Increases onboarding friction and risks misconfigured logic if developers expect actual Firebase rules or configs to apply.
- Fix approach: Rename methods and streams to reference Supabase, and clear out outdated "Firebase" naming holdovers.

**Lack of Repository Layer Abstraction:**
- Issue: Business logic providers (like `RelationshipProvider`) interact directly with the database client (`Supabase.instance.client`) rather than going through dedicated repository layers.
- Files: `lib/providers/relationship_provider.dart`
- Impact: Testing provider states and refactoring backend interactions is highly complex due to deep couplings.
- Fix approach: Extract database mutations and stream queries into a `RelationshipRepository` class.

## Security Considerations

**Hardcoded Credentials & Configs:**
- Issue: Static TODO comments prompt developers to hardcode Google Client IDs directly in code for OAuth.
- Files: `lib/providers/relationship_provider.dart` (L1716, L1721)
- Impact: Private credentials could be exposed in version control, leading to security threats.
- Fix approach: Leverage Dart environment parameters (`--dart-define`) to load credentials securely at build time.

## Performance Bottlenecks

**Heavy Realtime Streams:**
- Issue: Unbounded realtime database listeners are mounted in providers on startup (e.g. `_coupleSub`, `_userSub`, `_presenceChannel`).
- Files: `lib/providers/relationship_provider.dart`
- Impact: Excessive network traffic, battery drain, and potential client-side lag if streams trigger UI updates frequently.
- Fix approach: Restrict stream scopes, handle disposals cleanly when components unmount, and implement throttle limits.

## Fragile Areas

**Couple Pairing Flow:**
- Issue: Pairing users via couples code relies on fragile multi-step database actions (upserts on `couples` table, updates on `users` table).
- Files: `lib/providers/relationship_provider.dart`
- Impact: If any operation fails halfway, users could enter a semi-paired state, preventing them from accessing the app.
- Fix approach: Execute pairing transactions server-side using Supabase Edge Functions or database RPC functions to ensure atomicity.

## Test Coverage Gaps

**Untested Business Logic:**
- Issue: No unit or integration tests exist for provider classes, authentication flows, pairing workflows, or theme selections.
- Files: `lib/providers/` directory (entirely untested)
- Risk: Subtle regression bugs in state updates, auth listeners, or cache loadings could go unnoticed until deployment.
- Priority: High

---

*Concerns audit: 2026-06-19*
