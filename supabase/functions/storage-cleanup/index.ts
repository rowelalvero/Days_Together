// Drains public.storage_cleanup_queue (audit F-21, migration
// 20261003060000): removes, through the Storage API, every object under a
// queued prefix -- a deleted couple's photos, a deleted user's avatars --
// then settles the queue. Postgres cannot do this itself: direct DML on
// storage.objects is blocked so rows and backing files never diverge.
//
// Service-role only. Invoke on a schedule (see
// docs/security/manual-actions.md); it is idempotent, so overlapping or
// repeated runs are harmless and a failed run is simply retried next time.
import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Bounds one invocation; anything left is picked up by the next run.
const MAX_ROUNDS = 20;
const REMOVE_CHUNK = 100;

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  }
  return diff === 0;
}

serve(async (req) => {
  const token = req.headers.get("Authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token || !SUPABASE_SERVICE_ROLE_KEY || !timingSafeEqual(token, SUPABASE_SERVICE_ROLE_KEY)) {
    return json(401, { error: "Service role required" });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  let removed = 0;
  const failures: string[] = [];
  try {
    for (let round = 0; round < MAX_ROUNDS; round++) {
      const { data: pending, error } = await supabase.rpc("storage_cleanup_pending", { p_limit: 1000 });
      if (error) throw error;
      if (!pending || pending.length === 0) break;

      const byBucket = new Map<string, string[]>();
      for (const row of pending as { bucket_name: string; object_name: string }[]) {
        const names = byBucket.get(row.bucket_name) ?? [];
        names.push(row.object_name);
        byBucket.set(row.bucket_name, names);
      }

      let removedThisRound = 0;
      for (const [bucket, names] of byBucket) {
        for (let i = 0; i < names.length; i += REMOVE_CHUNK) {
          const chunk = names.slice(i, i + REMOVE_CHUNK);
          const { data, error: removeError } = await supabase.storage.from(bucket).remove(chunk);
          if (removeError) {
            failures.push(`${bucket}: ${removeError.message}`);
            continue;
          }
          removedThisRound += data?.length ?? 0;
        }
      }
      removed += removedThisRound;
      // Nothing could be removed: stop rather than spin on the same rows.
      if (removedThisRound === 0) break;
    }

    const { data: remaining, error: settleError } = await supabase.rpc("storage_cleanup_settle");
    if (settleError) throw settleError;

    if (failures.length > 0) console.error("storage-cleanup remove failures:", failures);
    return json(200, { removed, remaining_prefixes: remaining, failed_batches: failures.length });
  } catch (e) {
    console.error("storage-cleanup failed:", e);
    return json(500, { error: "Cleanup failed" });
  }
});
