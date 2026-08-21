# features/

This directory is the relocation target for the feature-oriented reorganization
defined in `docs/architecture/`. It is intentionally empty as of Migration
Phase 0 — features are moved here incrementally by later phases, not all at
once:

- **Phase 1** introduces `authentication/` (`CoupleSession`).
- **Phase 5** introduces `relationship/` (`LicenseController`,
  `ProfileController`, `WorkspaceController`, `PresenceController`).
- **Phase 6** relocates the 12 domain feature providers into their own
  `features/<name>/` directories as they're ported to Riverpod.
- **Phase 7b** relocates the ~73% of `lib/widgets/` that is feature-specific
  (not generic) into the `presentation/` directory of its owning feature.
- **Phase 8** relocates the decomposed pieces of the four god files.

See `docs/architecture/feature-boundaries.md` for the full target structure —
which features exist, what each owns, and the dependency rules between them
(enforced by `test/architecture_test.dart`) — and
`docs/architecture/migration-roadmap.md` for the phase-by-phase plan.

This file (and this directory) is removed once every feature has a real home
here and this notice is no longer needed.
