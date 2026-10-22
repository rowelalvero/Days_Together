-- S03: Pairing attempts are rate-limited server-side, and the limit persists.
-- S04: Pairing codes use cryptographically secure randomness.
-- S05: Successful pairing invalidates the pairing credential.
--
-- Guards against: audit F-03/F-17 -- the live join RPC had no attempt limit
-- (a rewrite in 20260808000003 silently dropped it), codes were 6 chars from
-- random(), and the earlier limiter wrote its counter and then RAISEd, which
-- rolled the counter back. Failures now RETURN a structured result so the
-- counter commits; these tests read the counter back as ground truth.
begin;
\ir _helpers.psql

select plan(46);

-- ---------------------------------------------------------------------------
-- Code generation (S04)
-- ---------------------------------------------------------------------------
select tests.create_user('a@test.local') as a \gset
select tests.create_workspace(:'a') as ws \gset
select (:'ws'::json->>'pairing_code') as code \gset
select (:'ws'::json->>'couple_id') as couple_a \gset

select matches((:'code')::text, '^[A-Z0-9]{8}$', 'pairing code is 8 characters of [A-Z0-9]');
select matches((:'ws'::json->>'recovery_code')::text, '^[A-Z0-9]{6}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$', 'recovery code keeps its LOOKUP-XXXX-XXXX-XXXX-XXXX shape');

select is(
  array(
    select p.proname::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('create_relationship_workspace', 'get_or_rotate_pairing_code',
                        'join_relationship_with_code', 'generate_secure_code')
      and p.prosrc ilike '%random()%'
    order by 1
  ),
  '{}'::text[],
  'no pairing-path function draws from random()'
);

select is(
  (select count(*)::int from (select public.generate_secure_code(8) c from generate_series(1, 2000)) s
   where c ~ '^[A-Z0-9]{8}$'),
  2000,
  'generate_secure_code emits only the 36-symbol alphabet at the requested length'
);
select is(
  (select count(distinct c)::int from (select public.generate_secure_code(8) c from generate_series(1, 2000)) s),
  2000,
  '2000 generated codes are all distinct'
);
select is(
  (select count(distinct ch)::int
   from (select public.generate_secure_code(16) c from generate_series(1, 200)) s,
        regexp_split_to_table(c, '') ch),
  36,
  'every symbol of the alphabet is reachable'
);
select ok(
  not has_function_privilege('authenticated', 'public.generate_secure_code(integer)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.generate_secure_code(integer)', 'EXECUTE'),
  'generate_secure_code is internal (not an RPC)'
);

select tests.authenticate_as(:'a');
select public.get_or_rotate_pairing_code(true) as rotated \gset
select tests.as_postgres();
select matches((:'rotated'::json->>'pairing_code')::text, '^[A-Z0-9]{8}$', 'rotation issues an 8-character code');
select isnt(:'rotated'::json->>'pairing_code', :'code', 'rotation replaces the code');
select :'rotated'::json->>'pairing_code' as code \gset

-- ---------------------------------------------------------------------------
-- Failed attempts: structured result + persistent counter (S03)
-- ---------------------------------------------------------------------------
select tests.create_user('e@test.local') as e \gset
select tests.authenticate_as(:'e');
select public.join_relationship_with_code('ZZZZZZZZ') as r1 \gset
select is(:'r1'::json->>'success', 'false', 'wrong code: success=false (returned, not raised)');
select is(:'r1'::json->>'error_code', 'INVALID_CODE', 'wrong code: error_code INVALID_CODE');
select ok(:'r1'::json->>'error' is not null, 'wrong code: carries a human-readable message for older clients');

select tests.as_postgres();
select is((select attempts from public.failed_pairing_attempts where user_id = :'e'), 1, 'the failed attempt was persisted (not rolled back)');

select tests.authenticate_as(:'e');
select throws_ok($$ update public.failed_pairing_attempts set attempts = 0 $$, '42501', null, 'a user cannot reset their own attempt counter');
select throws_ok($$ delete from public.failed_pairing_attempts $$, '42501', null, 'a user cannot delete their own attempt counter');

select public.join_relationship_with_code('ZZZZZZZY');
select public.join_relationship_with_code('ZZZZZZZX');
select public.join_relationship_with_code('ZZZZZZZW');
select is(public.join_relationship_with_code('ZZZZZZZV')->>'error_code', 'INVALID_CODE', '5th wrong code is still evaluated');

select public.join_relationship_with_code(:'code') as locked \gset
select is(:'locked'::json->>'error_code', 'RATE_LIMITED', 'after 5 failures even the correct code is refused');
select ok((:'locked'::json->>'retry_after')::timestamptz > now(), 'RATE_LIMITED carries a future retry_after');

select tests.as_postgres();
select is((select status from public.couples where id = :'couple_a'), 'waiting', 'the lockout kept the workspace waiting');
select ok((select locked_until > now() + interval '14 minutes' from public.failed_pairing_attempts where user_id = :'e'), 'lockout lasts ~15 minutes and persisted');

-- Lockout expiry, then success.
update public.failed_pairing_attempts set locked_until = now() - interval '1 second' where user_id = :'e';
select tests.authenticate_as(:'e');
select public.join_relationship_with_code(:'code') as joined \gset
select is(:'joined'::json->>'success', 'true', 'after the lockout expires the correct code succeeds');
select is(:'joined'::json->>'couple_id', :'couple_a', 'join returns the couple id');
select is(:'joined'::json->>'partner_id', :'a', 'join returns the creator as partner');

select tests.as_postgres();
select results_eq(
  format($$ select status, partner_a_id, partner_b_id, pairing_code from public.couples where id = %L $$, :'couple_a'),
  format($$ values ('active'::text, %L::uuid, %L::uuid, null::varchar) $$, :'a', :'e'),
  'couple is active with both slots filled and the pairing code cleared (S05)'
);
select is((select couple_id from public.users where id = :'e'), :'couple_a'::uuid, 'joiner is linked to the couple');
select is((select attempts from public.failed_pairing_attempts where user_id = :'e'), 0, 'success resets the attempt counter');

-- S05: the consumed code is dead for everyone else.
select tests.create_user('f@test.local') as f \gset
select tests.authenticate_as(:'f');
select is(public.join_relationship_with_code(:'code')->>'error_code', 'INVALID_CODE', 'a consumed code cannot be reused');

-- Already paired / self-pairing.
select tests.authenticate_as(:'e');
select is(public.join_relationship_with_code('ZZZZZZZZ')->>'error_code', 'ALREADY_PAIRED', 'a paired user cannot join another couple');
select tests.create_user('i@test.local') as i \gset
select tests.create_workspace(:'i') as ws_i \gset
select tests.authenticate_as(:'i');
select is(public.join_relationship_with_code(:'ws_i'::json->>'pairing_code')->>'error_code', 'ALREADY_PAIRED', 'a creator cannot join their own workspace');

-- ---------------------------------------------------------------------------
-- Expiry
-- ---------------------------------------------------------------------------
select tests.create_user('g@test.local') as g \gset
select tests.create_user('h@test.local') as h \gset
select tests.create_workspace(:'g') as ws_g \gset
update public.couples set pairing_code_updated_at = now() - interval '21 minutes'
where id = (:'ws_g'::json->>'couple_id')::uuid;

select tests.authenticate_as(:'h');
select is(public.join_relationship_with_code(:'ws_g'::json->>'pairing_code')->>'error_code', 'CODE_EXPIRED', 'a code older than 20 minutes is refused as CODE_EXPIRED');
select tests.as_postgres();
select is((select status from public.couples where id = (:'ws_g'::json->>'couple_id')::uuid), 'waiting', 'expired join left the workspace waiting');
select is((select attempts from public.failed_pairing_attempts where user_id = :'h'), 1, 'an expired-code attempt counts as a failure');

select tests.authenticate_as(:'g');
select public.get_or_rotate_pairing_code(false) as fresh \gset
select isnt(:'fresh'::json->>'pairing_code', :'ws_g'::json->>'pairing_code', 'an expired code is rotated on next fetch');
select tests.authenticate_as(:'h');
select is(
  public.join_relationship_with_code('  ' || lower(:'fresh'::json->>'pairing_code') || ' ')->>'success',
  'true',
  'the fresh code works, case- and whitespace-insensitively'
);

-- ---------------------------------------------------------------------------
-- Malformed input never raises
-- ---------------------------------------------------------------------------
select tests.create_user('m@test.local') as m \gset
select tests.authenticate_as(:'m');
select is(public.join_relationship_with_code(null)->>'error_code', 'INVALID_CODE', 'null code: INVALID_CODE');
select is(public.join_relationship_with_code('')->>'error_code', 'INVALID_CODE', 'empty code: INVALID_CODE');
select is(public.join_relationship_with_code('ab!'' or 1=1 --')->>'error_code', 'INVALID_CODE', 'garbage code: INVALID_CODE');

-- ---------------------------------------------------------------------------
-- Global protection: a many-account brute-force storm
-- ---------------------------------------------------------------------------
-- Simulate a storm of failures across the system within the window. Users
-- who are themselves part of the storm (have recent failures) are throttled;
-- a user making a first attempt is still evaluated normally.
select tests.as_postgres();
select tests.create_user('j@test.local') as j \gset
select tests.create_user('k@test.local') as k \gset
insert into public.pairing_attempt_failures (user_id, attempted_at)
select :'j'::uuid, now() - make_interval(secs => n * 0.25) from generate_series(1, 600) n;

select tests.authenticate_as(:'j');
select is(public.join_relationship_with_code('ZZZZZZZZ')->>'error_code', 'RATE_LIMITED', 'global storm: a user with recent failures is throttled');
select tests.authenticate_as(:'k');
select is(public.join_relationship_with_code('ZZZZZZZZ')->>'error_code', 'INVALID_CODE', 'global storm: a first attempt is still evaluated');
select tests.authenticate_as(:'k');
select is(public.join_relationship_with_code('ZZZZZZZZ')->>'error_code', 'RATE_LIMITED', 'global storm: that user''s second failure is throttled');
select throws_ok($$ select count(*) from public.pairing_attempt_failures $$, '42501', null, 'the global failure log is not readable by clients');

-- ---------------------------------------------------------------------------
-- Re-audit R-01: the throttle cannot be reset by deleting and recreating
-- one's own profile row. Both counters used to reference public.users
-- ON DELETE CASCADE, and a baseline policy let a user delete their own row,
-- so `delete; insert` (the app's own self-heal shape) erased the lockout.
-- ---------------------------------------------------------------------------
select tests.create_user('z@test.local') as z \gset
select tests.authenticate_as(:'z');
select public.join_relationship_with_code('ZZZZZZZZ') from generate_series(1, 5);
select is(public.join_relationship_with_code('ZZZZZZZY')->>'error_code', 'RATE_LIMITED', 'R-01: Z is locked out after 5 failures');

select throws_ok($$ delete from public.users where id = auth.uid() $$, '42501', null,
  'R-01: a user cannot delete their own profile row');
select lives_ok($$ insert into public.users (id, display_name) values (auth.uid(), 'again') on conflict (id) do nothing $$,
  'self-heal insert-if-absent still works (and is a no-op for an existing row)');
select is(public.join_relationship_with_code('ZZZZZZZX')->>'error_code', 'RATE_LIMITED', 'R-01: the lockout survives the delete/recreate attempt');

-- Defense in depth: even when a profile row IS removed by trusted code, the
-- counters stay attached to the auth identity.
select is(
  array(
    select conrelid::regclass::text || '->' || confrelid::regclass::text
    from pg_constraint
    where contype = 'f'
      and conrelid in ('public.failed_pairing_attempts'::regclass, 'public.pairing_attempt_failures'::regclass)
    order by 1
  ),
  array['failed_pairing_attempts->auth.users', 'pairing_attempt_failures->auth.users'],
  'R-01: attempt counters reference auth.users, not the deletable profile row'
);

select * from finish();
rollback;
