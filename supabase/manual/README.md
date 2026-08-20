# Manual, sequenced SQL — SEC-1 storage lockdown

Scripts in this directory are **deliberately NOT in `supabase/migrations/`** so that
`supabase db push` cannot apply them early. Running them out of order takes every
image in the app offline.

Currently all four storage buckets (`avatars`, `love-notes`, `timeline`,
`vault-photos`) are `public = true`. Supabase serves public-bucket objects at
`/storage/v1/object/public/{bucket}/{path}`, a route that **bypasses
`storage.objects` RLS entirely** — so anyone with (or guessing) an object path
can read any couple's private Vault photos anonymously. The Vault's PIN screen is
a client-side UI gate only.

Closing this requires flipping the buckets to private, which breaks plain public
URLs — and those URLs are what the app currently stores in
`vault_items.image_url`, `timeline_items.network_image_url`,
`love_notes.image_url`, and `users.avatar_url`. Hence the sequence below.

---

## The invariant

> The client must be able to mint signed URLs **and** read both storage formats
> (bare path *and* legacy public URL) **before** any row is rewritten and
> **before** any bucket goes private.

Signing works against public buckets too, so step 2 is behaviourally identical to
today and can be verified with nothing at risk.

---

## Order of operations

**Step 1 — apply the normal migrations** (safe now, already in `migrations/`):

```bash
supabase db push
```
- `20260820000000_protect_couple_id.sql` — closes SEC-2.
- `20260820000001_avatars_read_policy.sql` — scopes avatar reads to the couple.
  Harmless while buckets are public, but required before signing is enforced.

**Step 2 — ship the signed-URL client build.** Buckets stay public. New uploads
store bare paths; existing rows keep their full URLs; `StorageUrlService`
resolves both. Verify images still render everywhere before continuing.

**Step 3 — wait for adoption.** ⚠️ **Anyone still on an older build breaks
permanently at step 5.** If the install base is just the two of you, update both
phones and continue. If the app is published, gate on a minimum version first.

**Step 4 — backfill existing rows** (`01_backfill_storage_paths.sql`). Rewrites
stored public URLs down to bare paths. Old clients break here; new clients are
unaffected either way. Take the snapshot the script creates, and keep it until
step 5 is verified.

**Step 5 — flip the buckets private** (`02_make_buckets_private.sql`). This is
the step that actually closes SEC-1. Run the verification block at the bottom of
that file immediately afterwards.

---

## If something goes wrong

`99_rollback_make_buckets_public.sql` reverts step 5 and restores public reads.
It is an **emergency escape hatch that re-opens the vulnerability** — use it only
to restore service while diagnosing, then fix forward.

Step 4 is reverted from the `_bk_*` snapshot tables the backfill script creates.

Worst case to avoid: flipping buckets private *before* step 2. That causes a
total image blackout, and the pre-signed-URL build's avatar validator actively
*deletes* cached avatar refs from SharedPreferences on launch — so recovery is
not simply "ship the fix."
