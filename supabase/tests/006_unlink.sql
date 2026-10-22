-- Unlink: the leaving partner loses access immediately; the remaining
-- partner keeps the relationship. S06: unlink invalidates previous recovery
-- authority; only a code the remaining partner issues afterwards re-admits.
--
-- Guards against: stale access after unlink via RLS, and (audit F-05)
-- the leaving partner re-entering with the recovery code both partners were
-- shown -- disconnect_relationship_workspace never rotated it, and the
-- remaining partner's device would auto-wrap the photo key for them again.
begin;
\ir _helpers.psql

select plan(15);

select tests.create_user('a@test.local') as a \gset
select tests.create_user('b@test.local') as b \gset
select tests.create_workspace(:'a') as ws \gset
select (:'ws'::json->>'couple_id') as ab \gset
select tests.authenticate_as(:'b');
select public.join_relationship_with_code(:'ws'::json->>'pairing_code');
select tests.as_postgres();
insert into public.timeline_items (couple_id, title, date) values (:'ab', 'shared memory', now());

-- Positive control before unlinking.
select tests.authenticate_as(:'a');
select is((select count(*)::int from public.timeline_items where couple_id = :'ab'), 1, 'before unlink A sees the shared memory');

select is(public.disconnect_relationship_workspace()->>'success', 'true', 'A unlinks');

select is((select count(*)::int from public.timeline_items where couple_id = :'ab'), 0, 'after unlink A sees none of the couple''s data');
select is((select count(*)::int from public.couples where id = :'ab'), 0, 'after unlink A cannot read the couple row');
select is((select count(*)::int from public.users where id = :'b'), 0, 'after unlink A cannot read B''s profile');
select is(public.is_member_of_couple(:'ab'), false, 'after unlink A is not a member');

select tests.authenticate_as(:'b');
select is((select count(*)::int from public.timeline_items where couple_id = :'ab'), 1, 'B keeps the shared history');

select tests.as_postgres();
select results_eq(
  format($$ select partner_a_id, partner_b_id, (select couple_id from public.users where id = %L) from public.couples where id = %L $$, :'a', :'ab'),
  format($$ values (null::uuid, %L::uuid, null::uuid) $$, :'b'),
  'A''s slot and A''s couple link are cleared; B''s slot remains'
);

-- A trying to re-point their own couple_id back is still blocked (S02).
select tests.authenticate_as(:'a');
update public.users set couple_id = :'ab' where id = :'a';
select tests.as_postgres();
select is((select couple_id from public.users where id = :'a'), null, 'A cannot re-link by writing couple_id directly');

-- ---------------------------------------------------------------------------
-- S06 (audit F-05): unlink invalidates the recovery code both partners saw.
-- ---------------------------------------------------------------------------
select tests.as_postgres();
select results_eq(
  format($$ select recovery_lookup_key, recovery_code_hash, recovery_code_generated_at from public.couples where id = %L $$, :'ab'),
  $$ values (null::text, null::text, null::timestamptz) $$,
  'S06: unlink cleared the outstanding recovery credential'
);

select tests.authenticate_as(:'a');
select is(
  public.recover_relationship_with_code(:'ws'::json->>'recovery_code')->>'error_code',
  'INVALID_CODE',
  'S06: the old recovery code no longer re-admits the partner who left'
);
select tests.as_postgres();
select is((select couple_id from public.users where id = :'a'), null, 'S06: A remains outside the relationship');
select is((select partner_a_id from public.couples where id = :'ab'), null, 'S06: A''s slot is still empty');

-- Re-entry is still possible, but only with the remaining partner's consent:
-- B issues a fresh code and shares it.
select tests.authenticate_as(:'b');
select public.regenerate_recovery_code() as fresh \gset
select tests.authenticate_as(:'a');
select is(public.recover_relationship_with_code(:'fresh'::json->>'recovery_code')->>'success', 'true',
  'a code freshly issued by the remaining partner re-admits A');
select tests.as_postgres();
select is((select couple_id from public.users where id = :'a'), :'ab'::uuid, 'A is back in the couple with B''s consent');

select * from finish();
rollback;
