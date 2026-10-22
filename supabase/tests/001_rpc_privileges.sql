-- S01: Anonymous users cannot execute relationship RPCs, and authenticated
-- users can execute only the explicit RPC allowlist.
--
-- Guards against: audit F-04 -- every SECURITY DEFINER function was
-- executable by PUBLIC/anon (Postgres' default EXECUTE grant plus
-- remote_schema's ALTER DEFAULT PRIVILEGES ... TO anon), and
-- create_relationship_workspace/join_relationship_with_code had lost their
-- auth.uid() guard, so the anon key alone could create orphan workspaces and
-- burn a waiting couple's pairing code. The set-based checks enumerate
-- pg_proc dynamically, so a SECURITY DEFINER function added by a future
-- migration without an explicit grant fails here.
begin;
\ir _helpers.psql

select plan(43);

-- ---------------------------------------------------------------------------
-- 1. Privilege model, set-based over every SECURITY DEFINER fn in public.
-- ---------------------------------------------------------------------------
select is(
  array(
    select p.oid::regprocedure::text
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef
      and has_function_privilege('anon', p.oid, 'EXECUTE')
    order by 1
  ),
  '{}'::text[],
  'anon can execute no SECURITY DEFINER function in public'
);

select is(
  array(
    select p.oid::regprocedure::text
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace,
         aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where n.nspname = 'public' and p.prosecdef and a.grantee = 0
    order by 1
  ),
  '{}'::text[],
  'PUBLIC holds EXECUTE on no SECURITY DEFINER function in public'
);

select set_eq(
  $$
    select p.oid::regprocedure::text
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  $$,
  array[
    'create_relationship_workspace(text)',
    'join_relationship_with_code(text,text)',
    'get_or_rotate_pairing_code(boolean)',
    'recover_relationship_with_code(text,text)',
    'regenerate_recovery_code()',
    'disconnect_relationship_workspace()',
    'update_partner_profile(uuid,jsonb)',
    'store_wrapped_key(uuid,text)',
    'upsert_user_fcm_token(text,text)',
    'delete_current_user()',
    -- RLS predicate used by every couple-scoped policy; policies run as the
    -- querying role, so it must stay executable. Side-effect free.
    'is_member_of_couple(uuid)',
    -- Same reason: the realtime.messages presence policies call it as the
    -- joining user (20261003030000). Side-effect free.
    'is_couple_presence_topic(text)'
  ],
  'authenticated can execute exactly the RPC allowlist'
);

select ok(
  not has_function_privilege('authenticated', 'public.handle_user_deletion_cleanup()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.protect_users_couple_id()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.handle_new_user()', 'EXECUTE'),
  'trigger functions are not callable as RPCs'
);

select ok(
  has_function_privilege('service_role', 'public.delete_current_user()', 'EXECUTE')
  and has_function_privilege('service_role', 'public.is_member_of_couple(uuid)', 'EXECUTE'),
  'service_role keeps EXECUTE'
);

-- ---------------------------------------------------------------------------
-- 2. Behavioural: anon is refused at the privilege layer (42501) for every
--    RPC, before any function body runs.
-- ---------------------------------------------------------------------------
select tests.create_user('a@test.local') as a \gset
select tests.create_user('b@test.local') as b \gset
select tests.create_workspace(:'a') as ws \gset
select (:'ws'::json->>'pairing_code') as code \gset

select tests.as_anon();
select throws_ok($$ select public.create_relationship_workspace() $$, '42501', null, 'anon: create_relationship_workspace refused');
select throws_ok(format($$ select public.join_relationship_with_code(%L) $$, :'code'), '42501', null, 'anon: join_relationship_with_code refused');
select throws_ok($$ select public.get_or_rotate_pairing_code(true) $$, '42501', null, 'anon: get_or_rotate_pairing_code refused');
select throws_ok($$ select public.recover_relationship_with_code('ABCDEF-AAAA-BBBB-CCCC-DDDD') $$, '42501', null, 'anon: recover_relationship_with_code refused');
select throws_ok($$ select public.regenerate_recovery_code() $$, '42501', null, 'anon: regenerate_recovery_code refused');
select throws_ok($$ select public.disconnect_relationship_workspace() $$, '42501', null, 'anon: disconnect_relationship_workspace refused');
select throws_ok(format($$ select public.update_partner_profile(%L, '{"display_name":"x"}') $$, :'a'), '42501', null, 'anon: update_partner_profile refused');
select throws_ok(format($$ select public.store_wrapped_key(%L, 'k') $$, :'a'), '42501', null, 'anon: store_wrapped_key refused');
select throws_ok($$ select public.upsert_user_fcm_token('tok', 'android') $$, '42501', null, 'anon: upsert_user_fcm_token refused');
select throws_ok($$ select public.delete_current_user() $$, '42501', null, 'anon: delete_current_user refused');
select hasnt_function('public', 'get_user_couple_id', 'the unused get_user_couple_id helper is gone (20261003050000)');

select tests.as_postgres();
select is(
  (select status || '|' || coalesce(partner_b_id::text, 'null') from public.couples where id = (:'ws'::json->>'couple_id')::uuid),
  'waiting|null',
  'the anon join attempt left the waiting workspace untouched'
);

-- ---------------------------------------------------------------------------
-- 3. Defense in depth: the authenticated role with NO user in the JWT
--    (auth.uid() IS NULL) is still refused inside every function body.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select set_config('role', 'authenticated', true);

select throws_ok($$ select public.create_relationship_workspace() $$, 'P0001', 'Unauthorized', 'no-uid: create_relationship_workspace raises Unauthorized');
select is(
  public.join_relationship_with_code(:'code')->>'error_code',
  'INVALID_SESSION',
  'no-uid: join_relationship_with_code returns INVALID_SESSION'
);
select throws_ok($$ select public.get_or_rotate_pairing_code(true) $$, 'P0001', 'Unauthorized', 'no-uid: get_or_rotate_pairing_code raises');
select throws_ok($$ select public.recover_relationship_with_code('ABCDEF-AAAA-BBBB-CCCC-DDDD') $$, 'P0001', 'Unauthorized', 'no-uid: recover_relationship_with_code raises');
select throws_ok($$ select public.regenerate_recovery_code() $$, 'P0001', 'Unauthorized', 'no-uid: regenerate_recovery_code raises');
select throws_ok($$ select public.disconnect_relationship_workspace() $$, 'P0001', 'Unauthorized', 'no-uid: disconnect_relationship_workspace raises');
select throws_ok(format($$ select public.update_partner_profile(%L, '{}') $$, :'a'), 'P0001', 'Unauthorized', 'no-uid: update_partner_profile raises');
select throws_ok(format($$ select public.store_wrapped_key(%L, 'k') $$, :'a'), 'P0001', 'Unauthorized', 'no-uid: store_wrapped_key raises');
select throws_ok($$ select public.upsert_user_fcm_token('tok', 'android') $$, 'P0001', 'Not authenticated', 'no-uid: upsert_user_fcm_token raises');
select throws_ok($$ select public.delete_current_user() $$, 'P0001', 'Unauthorized', 'no-uid: delete_current_user raises');
select is(public.is_member_of_couple((:'ws'::json->>'couple_id')::uuid), false, 'no-uid: is_member_of_couple is false');

select tests.as_postgres();
select is(
  (select count(*)::int from public.couples where partner_a_id is null and partner_b_id is null),
  0,
  'no orphan workspace was created by an identity-less call'
);

-- ---------------------------------------------------------------------------
-- 4. Unrelated authenticated user is refused; the authorized user succeeds.
-- ---------------------------------------------------------------------------
select tests.create_user('c@test.local') as c \gset
select tests.create_user('d@test.local') as d \gset
select tests.create_user('x@test.local') as x \gset
select tests.pair(:'c', :'d') as couple_cd \gset
select tests.authenticate_as(:'b');
select is(public.join_relationship_with_code(:'code')->>'success', 'true', 'authorized: B joins A');

-- X is signed in but in no relationship.
select tests.authenticate_as(:'x');
select throws_ok(format($$ select public.update_partner_profile(%L, '{"display_name":"pwned"}') $$, :'a'), 'P0001', null, 'unrelated: X cannot edit A''s profile');
select throws_ok(format($$ select public.store_wrapped_key(%L, 'k') $$, :'a'), 'P0001', null, 'unrelated: X cannot plant a wrapped key for A');
select throws_ok($$ select public.regenerate_recovery_code() $$, 'P0001', 'Not in a relationship', 'unrelated: X cannot regenerate any recovery code');
select throws_ok($$ select public.get_or_rotate_pairing_code(true) $$, 'P0001', null, 'unrelated: X cannot rotate any pairing code');
select is(public.disconnect_relationship_workspace()->>'success', 'false', 'unrelated: X has nothing to disconnect');

-- C is in a different couple.
select tests.authenticate_as(:'c');
select throws_ok(format($$ select public.update_partner_profile(%L, '{"display_name":"pwned"}') $$, :'a'), 'P0001', 'Target user is not your partner in this relationship', 'cross-couple: C cannot edit A''s profile');
select throws_ok(format($$ select public.store_wrapped_key(%L, 'k') $$, :'b'), 'P0001', 'Recipient is not your partner in this relationship', 'cross-couple: C cannot plant a key for B');

-- Authorized partner calls.
select tests.authenticate_as(:'a');
select is(public.update_partner_profile(:'b', '{"display_name":"Bee"}')->>'success', 'true', 'authorized: A edits partner B');
select is(public.store_wrapped_key(:'b', 'wrapped-for-b')->>'success', 'true', 'authorized: A wraps a key for partner B');
select lives_ok($$ select public.upsert_user_fcm_token('token-a', 'android') $$, 'authorized: A registers own FCM token');

select tests.as_postgres();
select isnt((select display_name from public.users where id = :'a'), 'pwned', 'X/C attempts did not rename A');
select is((select display_name from public.users where id = :'b'), 'Bee', 'authorized partner edit landed');
select is((select count(*)::int from public.couple_key_exchanges where recipient_user_id = :'b'), 1, 'exactly one wrapped key exists for B (the authorized one)');

select * from finish();
rollback;
