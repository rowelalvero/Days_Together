-- S10: Users cannot mutate another user's FCM token.
--
-- Guards against: audit F-12 -- 20260808000004 replaced the owner-only UPDATE
-- policy with USING (auth.role() = 'authenticated'). A filtered UPDATE was
-- still stopped by the owner-only SELECT policy, but an UNFILTERED
--   UPDATE user_fcm_tokens SET user_id = auth.uid()
-- needs no SELECT rights, passed USING for every row and WITH CHECK for the
-- new value -- reassigning every device token in the system to the caller.
begin;
\ir _helpers.psql

select plan(17);

select tests.create_user('a@test.local') as a \gset
select tests.create_user('b@test.local') as b \gset

select tests.authenticate_as(:'a');
select lives_ok($$ select public.upsert_user_fcm_token('token-a', 'android') $$, 'A registers own token');
select is((select count(*)::int from public.user_fcm_tokens), 1, 'A sees only their own token');
select is(
  tests.rows_affected($$ update public.user_fcm_tokens set device_type = 'ios' where token = 'token-a' $$),
  1, 'A can update their own token row'
);

select tests.authenticate_as(:'b');
select lives_ok($$ select public.upsert_user_fcm_token('token-b', 'ios') $$, 'B registers own token');

-- A attacks B's row: unfiltered (the exploitable shape), filtered, delete, insert.
select tests.authenticate_as(:'a');
update public.user_fcm_tokens set user_id = auth.uid(), updated_at = now();
update public.user_fcm_tokens set user_id = auth.uid() where token = 'token-b';
delete from public.user_fcm_tokens where token = 'token-b';
select throws_ok(
  format($$ insert into public.user_fcm_tokens (user_id, token) values (%L, 'planted') $$, :'b'),
  '42501', null, 'A cannot insert a token row owned by B'
);

select tests.as_postgres();
select is((select user_id from public.user_fcm_tokens where token = 'token-b'), :'b'::uuid, 'S10: B''s token still belongs to B after A''s unfiltered UPDATE');
select is((select count(*)::int from public.user_fcm_tokens where token = 'token-b'), 1, 'S10: A could not delete B''s token');
select is((select user_id from public.user_fcm_tokens where token = 'token-a'), :'a'::uuid, 'A''s own token is untouched');

select tests.authenticate_as(:'b');
select is(
  tests.rows_affected($$ update public.user_fcm_tokens set device_type = 'android' where token = 'token-b' $$),
  1, 'B can still update their own token row'
);

-- anon: nothing visible, nothing writable.
select tests.as_anon();
select is((select count(*)::int from public.user_fcm_tokens), 0, 'anon sees no tokens');
update public.user_fcm_tokens set user_id = null;
select throws_ok($$ insert into public.user_fcm_tokens (user_id, token) values (gen_random_uuid(), 'anon') $$, '42501', null, 'anon cannot insert tokens');
select tests.as_postgres();
select is((select count(*)::int from public.user_fcm_tokens where user_id is not null), 2, 'anon''s UPDATE changed nothing');

-- ---------------------------------------------------------------------------
-- S12, server side: one device handed from A to B.
-- ---------------------------------------------------------------------------
-- Logout path: while A is still signed in, NotificationService.clearToken()
-- deletes A's row for the device token; then B registers the same token.
select tests.authenticate_as(:'a');
select lives_ok($$ select public.upsert_user_fcm_token('shared-device', 'android') $$, 'A registers the shared device');
select is(
  tests.rows_affected(format($$ delete from public.user_fcm_tokens where user_id = %L and token = 'shared-device' $$, :'a')),
  1, 'logout: A can delete their own row for the device (the clearToken query)'
);
select tests.authenticate_as(:'b');
select lives_ok($$ select public.upsert_user_fcm_token('shared-device', 'android') $$, 'B registers the same device');
select tests.as_postgres();
select results_eq(
  $$ select user_id from public.user_fcm_tokens where token = 'shared-device' $$,
  format($$ values (%L::uuid) $$, :'b'),
  'after A''s logout the device belongs to B alone'
);

-- Revocation path: A never got to delete (no JWT any more). B's registration
-- must still take the token over rather than leave A receiving on it.
select tests.authenticate_as(:'a');
select public.upsert_user_fcm_token('revoked-device', 'ios');
select tests.authenticate_as(:'b');
select public.upsert_user_fcm_token('revoked-device', 'ios');
select tests.as_postgres();
select results_eq(
  $$ select user_id from public.user_fcm_tokens where token = 'revoked-device' $$,
  format($$ values (%L::uuid) $$, :'b'),
  'without A''s delete, B''s registration still takes the device over'
);

select * from finish();
rollback;
