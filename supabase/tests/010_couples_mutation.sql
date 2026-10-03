-- S08: Users cannot modify relationship security fields directly.
-- S09: Users cannot delete a couple directly.
-- Audit F-11; enforced by 20261003010300_couples_mutation_boundary.sql.
--
-- Guards against: two live UPDATE policies on couples with no column
-- restriction (a member could evict their partner, archive the couple --
-- locking BOTH partners out via is_member_of_couple -- or swap the recovery
-- hash), and the never-dropped baseline DELETE policy that lets one partner
-- cascade-delete the entire shared history in a single PostgREST call.
begin;
\ir _helpers.psql

select plan(9);

-- Runs a write and ALWAYS rolls it back, reporting what happened:
-- 'refused:<sqlstate>' or 'affected:<rows>'. Keeps a write that is (still)
-- permitted from mutating the fixture the later assertions depend on.
create or replace function pg_temp.try_write(p_sql text)
returns text
language plpgsql
as $$
declare
  v_rows int;
begin
  begin
    execute p_sql;
    get diagnostics v_rows = row_count;
    raise exception using errcode = 'XX001', message = v_rows::text;
  exception
    when sqlstate 'XX001' then return 'affected:' || sqlerrm;
    when others then return 'refused:' || sqlstate;
  end;
end;
$$;

select tests.create_user('a@test.local') as a \gset
select tests.create_user('b@test.local') as b \gset
select tests.pair(:'a', :'b') as ab \gset

-- Legitimate client writes (CoupleSession: story_title, start_date,
-- start_time_hour/minute) must keep working.
select tests.authenticate_as(:'b');
select is(
  tests.rows_affected(format($$ update public.couples set story_title = 'Ours', start_date = now(), start_time_hour = 9, start_time_minute = 30
              where id = %L $$, :'ab')),
  1, 'a member can edit the client-editable couple fields'
);

select ok(pg_temp.try_write(format($$ update public.couples set partner_a_id = null where id = %L $$, :'ab')) in ('refused:42501', 'affected:0'),
  'S08: a member cannot evict their partner');
select ok(pg_temp.try_write(format($$ update public.couples set status = 'archived' where id = %L $$, :'ab')) in ('refused:42501', 'affected:0'),
  'S08: a member cannot archive the couple');
select ok(pg_temp.try_write(format($$ update public.couples set recovery_code_hash = 'x', recovery_lookup_key = 'X' where id = %L $$, :'ab')) in ('refused:42501', 'affected:0'),
  'S08: a member cannot replace the recovery credential');
select ok(pg_temp.try_write(format($$ update public.couples set pairing_code = 'AAAAAAAA' where id = %L $$, :'ab')) in ('refused:42501', 'affected:0'),
  'S08: a member cannot set the pairing code');
select ok(pg_temp.try_write(format($$ update public.couples set failed_recovery_attempts = 0, recovery_locked_until = null where id = %L $$, :'ab')) in ('refused:42501', 'affected:0'),
  'S08: a member cannot reset recovery lockouts');
select ok(pg_temp.try_write(format($$ delete from public.couples where id = %L $$, :'ab')) in ('refused:42501', 'affected:0'),
  'S09: a member cannot delete the couple');

select tests.as_postgres();
select results_eq(
  format($$ select partner_a_id, partner_b_id, status, story_title from public.couples where id = %L $$, :'ab'),
  format($$ values (%L::uuid, %L::uuid, 'active'::text, 'Ours'::text) $$, :'a', :'b'),
  'ground truth: slots/status intact, legitimate edit landed'
);
select is((select is_premium from public.couples where id = :'ab'), false, 'is_premium stays server-controlled');

select * from finish();
rollback;
