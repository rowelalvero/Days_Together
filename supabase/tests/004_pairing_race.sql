-- S05 (concurrency): two users racing for the same final slot -- exactly one
-- may succeed.
--
-- A genuine two-session race, not a sequential simulation. Session R1 joins
-- inside an open transaction (holding the couple row lock); session R2 then
-- issues its join for the same code asynchronously, so it is in flight and
-- blocked on that lock *before* R1 commits. After R1 commits, R2 must
-- re-check the slot and lose cleanly with a structured INVALID_CODE result --
-- not overwrite partner_b_id, and not raise.
--
-- Fixtures must be COMMITTED for other sessions to see them, so they are
-- created over a third dblink session and removed explicitly at the end.
-- Connects back over inet_server_addr() (the non-loopback address this test
-- session itself arrived on), where Supabase's pg_hba requires a password --
-- dblink refuses password-less connections for non-superusers. Uses the local
-- stack's default postgres password; this file only runs against
-- `supabase test db`, never a hosted project.
begin;
\ir _helpers.psql
create extension if not exists dblink with schema extensions;

select plan(6);

select format('host=%s port=%s dbname=%s user=postgres password=postgres',
              host(inet_server_addr()), inet_server_port(), current_database()) as conn \gset

select extensions.dblink_connect('setup', :'conn');
select extensions.dblink_connect('r1', :'conn');
select extensions.dblink_connect('r2', :'conn');

-- Sweep fixtures a previously aborted run may have committed.
select extensions.dblink_exec('setup', $$
  update public.users set couple_id = null
  where id in (select id from auth.users where email like 'race-%@test.local');
  delete from public.couples
  where partner_a_id in (select id from auth.users where email like 'race-%@test.local')
     or partner_b_id in (select id from auth.users where email like 'race-%@test.local');
  delete from auth.users where email like 'race-%@test.local';
$$);

-- Committed fixtures: creator A, racers X and Y.
select id as a from extensions.dblink('setup', $$
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'race-a-' || gen_random_uuid() || '@test.local', '{}', now(), now())
  returning id $$) as t(id uuid) \gset
select id as x from extensions.dblink('setup', $$
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'race-x-' || gen_random_uuid() || '@test.local', '{}', now(), now())
  returning id $$) as t(id uuid) \gset
select id as y from extensions.dblink('setup', $$
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'race-y-' || gen_random_uuid() || '@test.local', '{}', now(), now())
  returning id $$) as t(id uuid) \gset

select extensions.dblink_exec('setup', format('set "request.jwt.claims" = %L',
  json_build_object('sub', :'a', 'role', 'authenticated')::text));
select extensions.dblink_exec('setup', 'set role authenticated');
select r as ws from extensions.dblink('setup',
  'select public.create_relationship_workspace()::text') as t(r text) \gset
select extensions.dblink_exec('setup', 'reset role');
select extensions.dblink_exec('setup', 'reset "request.jwt.claims"');

-- R1: open a transaction and join (takes the couple row lock), do NOT commit.
select extensions.dblink_exec('r1', 'begin');
select extensions.dblink_exec('r1', format('set local "request.jwt.claims" = %L',
  json_build_object('sub', :'x', 'role', 'authenticated')::text));
select extensions.dblink_exec('r1', 'set local role authenticated');
select r as r1 from extensions.dblink('r1', format(
  $$select public.join_relationship_with_code(%L)::text$$, :'ws'::json->>'pairing_code')) as t(r text) \gset

-- R2: same code, sent asynchronously -- it blocks on R1's lock.
select extensions.dblink_exec('r2', 'begin');
select extensions.dblink_exec('r2', format('set local "request.jwt.claims" = %L',
  json_build_object('sub', :'y', 'role', 'authenticated')::text));
select extensions.dblink_exec('r2', 'set local role authenticated');
select extensions.dblink_send_query('r2', format(
  $$select public.join_relationship_with_code(%L)::text$$, :'ws'::json->>'pairing_code'));
select pg_sleep(0.5);
select is(extensions.dblink_is_busy('r2'), 1, 'R2 is genuinely in flight, blocked behind R1');

select extensions.dblink_exec('r1', 'commit');
select r as r2 from extensions.dblink_get_result('r2') as t(r text) \gset
-- Drain the async result stream so the connection accepts the next command.
select count(*) from extensions.dblink_get_result('r2') as t(r text);
select extensions.dblink_exec('r2', 'commit');

select is(:'r1'::json->>'success', 'true', 'R1 (first to lock) wins the slot');
select is(:'r2'::json->>'success', 'false', 'R2 loses the race');
select is(:'r2'::json->>'error_code', 'INVALID_CODE', 'R2 gets a structured INVALID_CODE, not an exception');

select r as final from extensions.dblink('setup', format($$
  select partner_b_id::text || '|' || status || '|' || coalesce(pairing_code, 'null')
  from public.couples where id = %L $$, :'ws'::json->>'couple_id')) as t(r text) \gset
select is(:'final'::text, :'x' || '|active|null', 'partner_b is R1''s user; status active; code consumed');

select r as y_couple from extensions.dblink('setup', format(
  $$select coalesce(couple_id::text, 'null') from public.users where id = %L$$, :'y')) as t(r text) \gset
select is(:'y_couple'::text, 'null', 'the losing user was not linked to the couple');

-- Remove the committed fixtures. Unlink first so the deletion trigger has
-- nothing to clean up.
select extensions.dblink_exec('setup', format($$
  update public.users set couple_id = null where id in (%1$L, %2$L, %3$L);
  delete from public.couples where id = %4$L;
  delete from auth.users where id in (%1$L, %2$L, %3$L);
$$, :'a', :'x', :'y', :'ws'::json->>'couple_id'));

select extensions.dblink_disconnect('setup');
select extensions.dblink_disconnect('r1');
select extensions.dblink_disconnect('r2');

select * from finish();
rollback;
