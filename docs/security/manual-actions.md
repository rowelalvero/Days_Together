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

## 7. Apply the re-audit fix to the hosted project — NOT DONE

`20261003020000_pairing_throttle_survives_profile_churn.sql` (re-audit R-01)
has only been applied locally. It removes the client's ability to delete its
own `public.users` row; account deletion is unaffected (it goes through
`delete_current_user()`).

## 8. Phase 3 on the hosted project — NOT DONE

1. Push `20261003030000_private_couple_presence.sql` (the Realtime presence
   policies).
2. Ship the app build that joins presence as a private channel. Older builds
   join it as a public channel, and since public and private channels with the
   same name are separate, their "partner online" indicator won't see users on
   the new build until both phones update.
3. **Do NOT turn off "Allow public access"** in Realtime settings. An earlier
   version of this document said to. It is not needed: verified against the
   real Realtime server (`test/e2e/realtime_e2e_test.dart`), an outsider
   joining the same topic as a public channel sees none of the couple's
   private presence. And every feature stream (`.stream()`) joins a public
   channel, so turning public access off risks breaking all live updates.

## 9. Phases 5–7 on the hosted project — NOT DONE

1. Push the remaining migrations: `20261003040000_query_matched_indexes.sql`,
   `20261003050000_drop_legacy_objects.sql`,
   `20261003060000_storage_cleanup_queue.sql`.
2. Deploy both edge functions: `supabase functions deploy send-push-notification`
   and `supabase functions deploy storage-cleanup`.
3. Schedule `storage-cleanup`. It only accepts the project's service-role key
   as its bearer token. One way is Supabase Cron (pg_cron + pg_net) calling the
   function hourly, with the service-role key read from Supabase Vault, never
   written into a migration or committed. Until it is scheduled, deleted
   couples' photos stay queued (not lost, not removed). The function is
   idempotent; a manual run is just a POST to `/functions/v1/storage-cleanup`.
4. Couples deleted *before* the migration was applied were never queued. To
   find their leftover folders, list `couples/<id>/` prefixes in the three
   photo buckets whose `<id>` is no longer in `public.couples`, check them,
   and remove them with
   `supabase storage rm ss:///<bucket>/couples/<id> -r --experimental --yes`.
5. Release signing: create `android/key.properties` and the upload keystore
   on the build machine (not in the repository) before `flutter build
   appbundle`; without it the release build now stops with an error instead
   of silently producing a debug-signed bundle.
