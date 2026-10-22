import test from 'node:test';
import assert from 'node:assert/strict';
import { createAccessTokenCache, isStaleTokenResponse } from './fcm.ts';

test('only 404 / UNREGISTERED marks a token stale', () => {
  assert.equal(isStaleTokenResponse(404, null), true);
  assert.equal(
    isStaleTokenResponse(400, {
      error: { details: [{ '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', errorCode: 'UNREGISTERED' }] },
    }),
    true,
  );
  // Our fault or transient: the device must keep its token.
  assert.equal(
    isStaleTokenResponse(400, { error: { details: [{ errorCode: 'INVALID_ARGUMENT' }] } }),
    false,
  );
  for (const status of [200, 401, 403, 429, 500, 503]) {
    assert.equal(isStaleTokenResponse(status, {}), false, `status ${status}`);
  }
  assert.equal(isStaleTokenResponse(400, 'not json'), false);
});

test('the access token is reused until a minute before expiry', async () => {
  let clock = 0;
  let fetches = 0;
  const get = createAccessTokenCache(async () => {
    fetches++;
    return { token: `t${fetches}`, expiresInSeconds: 3600 };
  }, () => clock);

  assert.equal(await get(), 't1');
  clock = 3600_000 - 61_000;
  assert.equal(await get(), 't1');
  assert.equal(fetches, 1);
  clock = 3600_000 - 59_000;
  assert.equal(await get(), 't2');
  assert.equal(fetches, 2);
});

test('concurrent callers share one fetch, and a failure is not cached', async () => {
  let fetches = 0;
  let fail = true;
  const get = createAccessTokenCache(async () => {
    fetches++;
    await new Promise((r) => setTimeout(r, 5));
    if (fail) throw new Error('oauth down');
    return { token: 'ok', expiresInSeconds: 3600 };
  });

  const results = await Promise.allSettled([get(), get(), get()]);
  assert.equal(fetches, 1);
  assert.ok(results.every((r) => r.status === 'rejected'));

  fail = false;
  assert.equal(await get(), 'ok');
  assert.equal(fetches, 2);
});
