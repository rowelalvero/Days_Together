# features/

Every business feature owns its code here. The feature-first migration is
complete: `lib/` is now exactly `app/`, `core/`, `features/`, `shared/`, and
`main.dart` — the legacy global `screens/`, `models/`, `services/`,
`providers/`, `data/`, `utils/`, `routing/`, and `themes/` directories are
gone.

## Layout

A feature uses only the layers it actually needs — layering is not applied
ceremonially:

```
features/<feature>/
├── <feature>_controller.dart   # the feature's public surface (Riverpod)
├── <feature>_state.dart        # the typed state it exposes
├── data/                       # repositories, datasources, sync managers
├── domain/                     # entities/, use cases
└── presentation/
    ├── pages/                  # screens
    ├── widgets/                # this feature's own widgets
    └── controllers/            # UI-local controllers, where a feature has them
```

Controllers and state stay at the feature root rather than under
`presentation/providers/`. They are the feature's public API — the only files
another feature may import — and they are not purely presentational: they own
REST sync and realtime subscriptions via `SupabaseLifecycleNotifier`. Keeping
them at the root makes the public surface obvious and matches the naming
convention `test/architecture_test.dart` enforces.

## Cross-feature rule

A feature may depend on another feature **only** through that feature's
`*_controller.dart` or `*_state.dart`. Reaching into another feature's
`presentation/`, `data/`, or `domain/` is a violation, and
`test/architecture_test.dart` fails the build on it.

Anything genuinely shared goes up, not sideways:

- `core/` — infrastructure several unrelated features need (session, network,
  storage, security, notifications, platform integration).
- `shared/` — cross-feature widgets and the data contracts more than one
  feature speaks (`shared/models/`).

`core/` and `shared/` must never import from `features/` (Architecture
Rule 12).

## Where the boundaries came from

`docs/architecture/feature-boundaries.md` defines which features exist, what
each owns, and the dependency matrix between them. Two placements deliberately
differ from that document, both because `core/` cannot depend on `features/`:

- **`CoupleSession` lives in `core/session/`**, not `features/authentication/`.
  `core/riverpod/supabase_lifecycle_notifier.dart` depends on it and 13
  features read it. `features/authentication/` owns the onboarding UI.
- **The OS home-screen widget bridge lives in `core/platform/home_widget/`**
  (service, constants, models, offscreen render templates), while
  `features/home_widgets/` keeps the in-app Studio screen that configures it —
  the same split that already separates `core/notifications/` from the
  `settings` feature.

The application shell (`LoveStoryScreen` and its four tabs) lives in
`app/shell/`, not here: a scaffold that composes every feature's entry point is
application composition, like `app/router/`, not a business feature of its own.
