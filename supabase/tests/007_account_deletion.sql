-- Account deletion via delete_current_user().
--
-- Paired deletion: the deleted user's auth/public rows go, the remaining
-- partner keeps the couple and its shared data and is notified, the
-- outstanding recovery code is invalidated, and the deleted user's key
-- material and FCM tokens go with them.
--
-- Solo / last-member deletion (audit F-08, reproduced, fixed in
-- 20261003010100). handle_user_deletion_cleanup() (BEFORE DELETE on
-- public.users) used to delete the now-empty couple itself; the couple's FK
-- ON DELETE SET NULL then rewrote the very users row being deleted, whose FK
-- to the already-deleted auth.users failed, aborting the whole deletion:
--   ERROR: insert or update on table "users" violates foreign key
--          constraint "users_id_fkey"
begin;
\ir _helpers.psql

select plan(18);

-- ---------------------------------------------------------------------------
-- Paired deletion
-- ---------------------------------------------------------------------------
select tests.create_user('a@test.local') as a \gset
select tests.create_user('b@test.local') as b \gset
select tests.pair(:'a', :'b') as ab \gset
insert into public.timeline_items (couple_id, title, date) values (:'ab', 'shared memory', now());
insert into public.user_fcm_tokens (user_id, token) values (:'b', 'token-b');
select tests.authenticate_as(:'a');
select public.store_wrapped_key(:'b', 'wrapped-for-b');

select tests.authenticate_as(:'b');
select is(public.delete_current_user()->>'success', 'true', 'paired user B deletes their account');

select tests.as_postgres();
select is((select count(*)::int from auth.users where id = :'b'), 0, 'B''s auth.users row is gone');
select is((select count(*)::int from public.users where id = :'b'), 0, 'B''s public.users row is gone');
select results_eq(
  format($$ select couple_id, partner_deleted_notice from public.users where id = %L $$, :'a'),
  format($$ values (%L::uuid, true) $$, :'ab'),
  'A stays in the couple and is told the partner left'
);
select results_eq(
  format($$ select partner_a_id, partner_b_id, recovery_code_hash from public.couples where id = %L $$, :'ab'),
  format($$ values (%L::uuid, null::uuid, null::text) $$, :'a'),
  'B''s slot is vacated and the outstanding recovery code is invalidated'
);
select is((select count(*)::int from public.timeline_items where couple_id = :'ab'), 1, 'shared history survives for A');
select is((select count(*)::int from public.couple_key_exchanges where recipient_user_id = :'b'), 0, 'B''s wrapped key material is gone');
select is((select count(*)::int from public.user_fcm_tokens where user_id = :'b'), 0, 'B''s device tokens are gone (no notifications to a deleted account)');

-- ---------------------------------------------------------------------------
-- Solo deletion (audit F-08): the couple's only member deletes their account.
-- ---------------------------------------------------------------------------
select tests.create_user('s@test.local') as s \gset
select tests.create_workspace(:'s') as ws_s \gset
select (:'ws_s'::json->>'couple_id') as cs \gset
insert into public.timeline_items (couple_id, title, date) values (:'cs', 'solo memory', now());
insert into storage.objects (bucket_id, name, owner) values ('timeline', 'couples/' || :'cs' || '/timeline/m.enc', :'s');

select tests.authenticate_as(:'s');
select lives_ok($$ select public.delete_current_user() $$, 'solo user can delete their account');
select tests.as_postgres();
select is((select count(*)::int from auth.users where id = :'s'), 0, 'solo user''s auth.users row is gone');
select is((select count(*)::int from public.users where id = :'s'), 0, 'solo user''s profile row is gone');
select is((select count(*)::int from public.couples where id = :'cs'), 0, 'their now-empty couple is removed');
select is((select count(*)::int from public.timeline_items where couple_id = :'cs'), 0, 'and its feature data with it');

-- ---------------------------------------------------------------------------
-- Last remaining partner: L2 unlinked earlier, then L1 deletes.
-- ---------------------------------------------------------------------------
select tests.create_user('l1@test.local') as l1 \gset
select tests.create_user('l2@test.local') as l2 \gset
select tests.pair(:'l1', :'l2') as cl \gset
insert into public.timeline_items (couple_id, title, date) values (:'cl', 'old memory', now());
select tests.authenticate_as(:'l2');
select public.disconnect_relationship_workspace();
select tests.authenticate_as(:'l1');
select lives_ok($$ select public.delete_current_user() $$, 'the last remaining partner can delete their account');
select tests.as_postgres();
select is((select count(*)::int from public.couples where id = :'cl'), 0, 'the abandoned couple is removed');
select is((select count(*)::int from public.timeline_items where couple_id = :'cl'), 0, 'and its shared data');
select is((select count(*)::int from public.users where id = :'l2'), 1, 'the partner who left earlier is untouched');

-- ---------------------------------------------------------------------------
-- Storage expectation -- Phase 7 (audit F-21). Objects are not removed with
-- their couple: deleting stored objects is a Storage API operation, and
-- nothing queues it yet.
-- ---------------------------------------------------------------------------
select todo_start('Phase 7: F-21 -- deleted couples leave their storage objects behind');
select is(
  (select count(*)::int from storage.objects where name like 'couples/' || :'cs' || '/%'),
  0,
  'a deleted couple''s storage objects are removed (or queued for removal)'
);
select todo_end();

select * from finish();
rollback;
