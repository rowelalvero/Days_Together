// Pure helpers for send-push-notification (audit F-20), kept free of Deno
// and network imports so fcm.test.mjs can run them under plain Node.

// FCM v1 says a token is permanently dead with 404 / UNREGISTERED (app
// uninstalled, token rotated). Only those are pruned: a 400 can be a bad
// payload, and a 401/403/429/5xx is ours or transient -- deleting the token
// then would silently stop a working device from ever being notified.
export function isStaleTokenResponse(status: number, body: unknown): boolean {
  if (status === 404) return true;
  const details = (body as { error?: { details?: unknown } } | null)?.error?.details;
  if (!Array.isArray(details)) return false;
  return details.some(
    (d) => (d as { errorCode?: unknown } | null)?.errorCode === "UNREGISTERED",
  );
}

export type AccessToken = { token: string; expiresInSeconds: number };

// Caches the Google OAuth access token for the life of the worker instead of
// minting (and signing) a new one per request. Refreshed a minute before it
// expires; concurrent callers share one in-flight fetch; a failed fetch is not
// cached.
export function createAccessTokenCache(
  fetchToken: () => Promise<AccessToken>,
  now: () => number = Date.now,
) {
  let cached: { token: string; expiresAt: number } | null = null;
  let inFlight: Promise<string> | null = null;

  return async function getToken(): Promise<string> {
    if (cached && now() < cached.expiresAt - 60_000) return cached.token;
    if (!inFlight) {
      inFlight = fetchToken()
        .then(({ token, expiresInSeconds }) => {
          cached = { token, expiresAt: now() + expiresInSeconds * 1000 };
          return token;
        })
        .finally(() => {
          inFlight = null;
        });
    }
    return inFlight;
  };
}
