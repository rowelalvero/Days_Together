# External Integrations

**Analysis Date:** 2026-06-19

## APIs & External Services

**Backend-as-a-Service (BaaS):**
- Supabase - Primary backend service for database, authentication, presence, and storage.
  - SDK/Client: `supabase_flutter` (`^2.6.0`)
  - Initialization: Configured in `lib/main.dart` with project URL (`https://njrdvhvftgpvcmckzeqh.supabase.co`) and public anon key.
  - *Note: The codebase contains naming legacy referencing "Firebase" (e.g. `isFirebaseAvailable`, `_initFirebaseSync()`), but these point entirely to Supabase Client operations.*

## Data Storage

**Databases:**
- Supabase PostgreSQL Database
  - Connection: Managed internally by Supabase client.
  - Client: `Supabase.instance.client`
  - Synced tables: `users`, `couples`, `license_details`, `timeline_items`, etc.
- Local Cache (Key-Value):
  - SharedPreferences - Key-value storage for local caching of timeline items, theme choices, and couple configurations.
  - Client: `SharedPreferences.getInstance()`
  - Key variables: `timeline_items`, `app_settings` in `lib/repositories/timeline_repository.dart`.

**File Storage:**
- Supabase Storage
  - Bucket: Used for user avatar uploads, license graphics, and media storage (`Supabase.instance.client.storage`).
- Local Filesystem:
  - Path Provider (`path_provider` ^2.1.0) - Resolves local directories for file selection and local caching.

## Authentication & Identity

**Auth Provider:**
- Supabase Auth & Google Sign-In
  - Implementation: Email/password authentication, Google Sign-In via ID tokens, and a custom Couple Code onboarding pairing flow (creating, sharing, and joining couples via `couples` table).
  - Method calls: `Supabase.instance.client.auth.signUp`, `signInWithPassword`, `signInWithIdToken`, `signOut`.

## Monitoring & Observability

**Error Tracking:**
- None detected. Basic try/catch blocks log errors locally using `debugPrint` or `print`.

## CI/CD & Deployment

**Hosting/Legacy Configurations:**
- Firebase configuration files are present (`firebase.json`, `.firebaserc` target: `days-together-2f484`), referencing Firestore and Storage security rules (`firestore.rules`, `storage.rules`). These are likely legacy configurations or configured for staging hosting/rules.

---

*Integration audit: 2026-06-19*
