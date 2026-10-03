# Manual security actions

These steps cannot be done from the repository. None of them is recorded as
done here until a person performs it and updates its status.

## 1. Rotate the leaked Firebase service-account key (audit F-01) — NOT DONE

A service-account private key for Firebase project `days-together-2f484` was
committed in `4c7e2f7` and later rewritten out of branch history. The rewrite
does **not** make it safe: the key was valid while it was in history, a local
backup ref still contains it, and whether it ever reached GitHub can't be
determined from a clone.

1. Google Cloud console → IAM & Admin → Service Accounts → the account in the
   leaked file → **Keys**. Delete the key whose ID matches `private_key_id` in
   the local `service-account.json`. Deleting it is what makes the leaked
   copy useless.
2. Create a new JSON key for the same account (or a new account limited to
   the *Firebase Cloud Messaging API Admin* role, which is all
   `send-push-notification` needs).
3. Store it only as the Supabase secret the edge function reads:
   `supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$(cat new-key.json)"`.
   Never in the repository. `.gitignore` and `test/secret_scan_test.dart` now
   block it.
4. Delete the old `service-account.json` from your disk, and the new key file
   once it is stored as a secret.
5. Send a test push (pair two test accounts, send a chat message) to confirm
   the function still authenticates.

## 2. Purge the key from local git history (audit F-01) — NOT DONE

`refs/original/refs/heads/master` (left by `git filter-branch`) still
references commit `4c7e2f7`. After step 1:

```bash
git update-ref -d refs/original/refs/heads/master
git reflog expire --expire=now --all
git gc --prune=now
git log --all --oneline -- service-account.json   # must print nothing
```

If the commit was ever pushed, GitHub may still serve it by SHA. Rotation
(step 1) is the actual fix; ask GitHub Support to purge cached views if the
repository is or was public.

## 3. Verify bucket privacy on the hosted project (audit F-02) — NOT DONE

Migration `20261003000000_enforce_private_storage_buckets.sql` sets
`public = false` on every Days Together bucket when it is pushed. Before
pushing:

1. Confirm that every install runs a build with signed URLs (any build after
   the 2026-08-20 storage work). Older builds show no images once the buckets
   are private. See `supabase/manual/README.md` step 3.
2. `supabase db push`. The migration aborts on its own, leaving the buckets
   unchanged, if the storage read policies that signing depends on are
   missing.
3. In the SQL editor: `select id, public from storage.buckets;` — every row
   must show `public = false`.
4. From outside the project, pick a real object path and request its public
   URL; it must fail:
   `curl -s -o /dev/null -w '%{http_code}\n' 'https://<project>.supabase.co/storage/v1/object/public/timeline/<path>'`
   Expect 400/404, not 200.
5. In the app, confirm both partners still see photos, and a third account
   cannot.

Legacy media is not deleted or rewritten by any of this.

## 4. Apply the Phase 0 database migrations to the hosted project — NOT DONE

`20261003000000` … `20261003000300` have only been applied to the local stack
(`supabase db reset`). Pushing them changes pairing for everyone:

- Pairing codes become 8 characters. App builds from before this change
  reject 8-character input client-side, so **ship the matching app build
  first** (or together with the push).
- A `join` failure now returns `{success:false, error_code}` instead of
  raising. Older builds show the server's `error` text.

## 5. Apply the Phase 1 database migrations to the hosted project — NOT DONE

`20261003010000` … `20261003010400` have only been applied locally. Effects
when pushed:

- Every outstanding recovery code of a couple where someone has *already*
  unlinked stays valid until the next unlink, deletion, or regeneration --
  the migration fixes the unlink path going forward, it does not retroactively
  rotate codes. To close existing exposure, consider (product decision)
  nulling recovery codes on couples that currently have an empty slot:
  `update couples set recovery_lookup_key = null, recovery_code_hash = null,
  recovery_code_generated_at = null where partner_a_id is null or partner_b_id is null;`
- Stored partner email addresses on `couples` are cleared (irreversible; the
  values drove nothing but the removed slot logic).
- Builds that still write `couples.is_premium` get a permission error on that
  write (it was always silently reverted before). The current build no longer
  sends it.

## 6. Ship the Phase 2 app build — NOT DONE

The Phase 2 changes are client-side and only protect devices running a build
that contains them. On older builds, logout still leaves the previous
account's data and notification token behind. Nothing server-side needs to
change.
