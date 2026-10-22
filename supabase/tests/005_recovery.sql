-- Recovery-code security baseline, S07 and audit F-24.
--
-- Guards against: the recovery limiter regressing to RAISE-after-update
-- (counter rolled back -- fixed in 20260926000000), a valid code claiming an
-- occupied slot (including via a recorded email match -- audit F-24),
-- expired codes being honoured, and a regenerated code inheriting the
-- original code's 90-day clock (audit F-09).
begin;
\ir _helpers.psql

select plan(25);

select tests.create_user('a@test.local') as a \gset
select tests.create_user('b@test.local') as b \gset
select tests.create_user('r@test.local') as r \gset
select tests.create_workspace(:'a') as ws \gset
select (:'ws'::json->>'couple_id') as ab \gset
select (:'ws'::json->>'recovery_code') as rcode \gset
select split_part(:'rcode', '-', 1) as lookup \gset
select tests.authenticate_as(:'b');
select public.join_relationship_with_code(:'ws'::json->>'pairing_code');

-- ---------------------------------------------------------------------------
-- Failures are returned (not raised) and the counters persist.
-- ---------------------------------------------------------------------------
select tests.authenticate_as(:'r');
select public.recover_relationship_with_code('NOPE00-AAAA-BBBB-CCCC-DDDD') as bad \gset
select is(:'bad'::json->>'error_code', 'INVALID_CODE', 'unknown recovery code: INVALID_CODE');
select tests.as_postgres();
select is((select failed_attempts from public.user_recovery_attempts where user_id = :'r'), 1, 'per-user failure persisted');

-- Correct lookup key, wrong secret: counts against the couple too.
select tests.authenticate_as(:'r');
select public.recover_relationship_with_code(:'lookup' || '-AAAA-BBBB-CCCC-DDDD');
select tests.as_postgres();
select is((select failed_recovery_attempts from public.couples where id = :'ab'), 1, 'per-couple failure persisted');

select tests.authenticate_as(:'r');
select public.recover_relationship_with_code('NOPE01-AAAA-BBBB-CCCC-DDDD');
select public.recover_relationship_with_code('NOPE02-AAAA-BBBB-CCCC-DDDD');
select public.recover_relationship_with_code('NOPE03-AAAA-BBBB-CCCC-DDDD');
select is(public.recover_relationship_with_code(:'rcode')->>'error_code', 'USER_LOCKED', 'after 5 failures the account is locked, even for a valid code');

-- Couple lockout is independent of which account is guessing.
select tests.as_postgres();
update public.couples set failed_recovery_attempts = 5, recovery_locked_until = now() + interval '15 minutes' where id = :'ab';
select tests.create_user('s@test.local') as s \gset
select tests.authenticate_as(:'s');
select is(public.recover_relationship_with_code(:'rcode')->>'error_code', 'COUPLE_LOCKED', 'a locked recovery key refuses every account');
select tests.as_postgres();
update public.couples set failed_recovery_attempts = 0, recovery_locked_until = null where id = :'ab';
update public.user_recovery_attempts set failed_attempts = 0, locked_until = null where user_id = :'r';

-- ---------------------------------------------------------------------------
-- A valid code never claims an occupied slot.
-- ---------------------------------------------------------------------------
select tests.authenticate_as(:'r');
select throws_ok(format($$ select public.recover_relationship_with_code(%L) $$, :'rcode'),
  'P0001', 'No vacant slot available in this relationship workspace',
  'a valid code cannot displace either current partner');
select tests.as_postgres();
select results_eq(
  format($$ select partner_a_id, partner_b_id from public.couples where id = %L $$, :'ab'),
  format($$ values (%L::uuid, %L::uuid) $$, :'a', :'b'),
  'both slots still belong to A and B'
);
select is((select couple_id from public.users where id = :'r'), null, 'R was not linked');

-- ---------------------------------------------------------------------------
-- Expiry: a code older than 90 days is refused.
-- ---------------------------------------------------------------------------
update public.couples set recovery_code_generated_at = now() - interval '91 days' where id = :'ab';
select tests.authenticate_as(:'r');
select throws_ok(format($$ select public.recover_relationship_with_code(%L) $$, :'rcode'),
  'P0001', 'Recovery code has expired (valid for 90 days). Request a new recovery code.',
  'a 91-day-old recovery code is refused');

-- ---------------------------------------------------------------------------
-- Legitimate replacement: B's account is deleted, A regenerates, R recovers
-- into the vacated slot.
-- ---------------------------------------------------------------------------
select tests.authenticate_as(:'b');
select public.delete_current_user();
select tests.as_postgres();
select is((select recovery_code_hash from public.couples where id = :'ab'), null, 'account deletion invalidated the outstanding recovery code');

select tests.authenticate_as(:'a');
select public.regenerate_recovery_code() as regen \gset
select matches((:'regen'::json->>'recovery_code')::text, '^[A-Z0-9]{6}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$', 'regenerated code has the expected shape');

select tests.authenticate_as(:'r');
select is(public.recover_relationship_with_code(:'rcode')->>'error_code', 'INVALID_CODE', 'the pre-regeneration code is dead');
select public.recover_relationship_with_code(:'regen'::json->>'recovery_code', 'pubkey-r') as ok \gset
select is(:'ok'::json->>'success', 'true', 'the regenerated code recovers into the vacated slot');
select tests.as_postgres();
select is((select couple_id from public.users where id = :'r'), :'ab'::uuid, 'R is now linked to the couple');
select is((select partner_b_id from public.couples where id = :'ab'), :'r'::uuid, 'R occupies the vacated slot');
select is((select public_key from public.users where id = :'r'), 'pubkey-r', 'the recovering device''s fresh public key was stored');

-- ---------------------------------------------------------------------------
-- S07 (audit F-09): regeneration starts a new validity period, clears the
-- recovery lockout, and kills the previous code.
-- ---------------------------------------------------------------------------
select tests.create_user('p@test.local') as p \gset
select tests.create_user('q@test.local') as q \gset
select tests.create_workspace(:'p') as ws_p \gset
select (:'ws_p'::json->>'couple_id') as cp \gset
update public.couples
set recovery_code_generated_at = now() - interval '120 days',
    failed_recovery_attempts = 3,
    recovery_locked_until = now() + interval '10 minutes'
where id = :'cp';
select tests.authenticate_as(:'p');
select public.regenerate_recovery_code() as regen_p \gset
select tests.as_postgres();

select ok(
  (select recovery_code_generated_at > now() - interval '1 minute' from public.couples where id = :'cp'),
  'S07: regeneration stamps recovery_code_generated_at = now()'
);
select results_eq(
  format($$ select failed_recovery_attempts, recovery_locked_until from public.couples where id = %L $$, :'cp'),
  $$ values (0, null::timestamptz) $$,
  'S07: regeneration clears the per-couple recovery lockout'
);

-- Vacate P's slot (as account deletion would) so Q has somewhere to land.
update public.couples set partner_a_id = null where id = :'cp';
update public.users set couple_id = null where id = :'p';

select tests.authenticate_as(:'q');
select is(public.recover_relationship_with_code(:'ws_p'::json->>'recovery_code')->>'error_code', 'INVALID_CODE',
  'S07: the code from before regeneration is dead');
select is(public.recover_relationship_with_code(:'regen_p'::json->>'recovery_code')->>'success', 'true',
  'S07: a freshly regenerated code is not born expired');
select tests.as_postgres();
select is((select couple_id from public.users where id = :'q'), :'cp'::uuid, 'Q recovered into the couple');
select is((select partner_a_email from public.couples where id = :'cp'), null,
  'F-24: recovery no longer records email addresses on the couple');

select is(
  array(
    select p.proname::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosrc ilike '%random()%'
    order by 1
  ),
  '{}'::text[],
  'S04: no function in public draws security codes from random()'
);

-- ---------------------------------------------------------------------------
-- F-24: a matching email address never overrides an occupied slot.
-- ---------------------------------------------------------------------------
select tests.create_user('u@test.local') as u \gset
select tests.create_user('v@test.local') as v \gset
select tests.create_user('w@test.local') as w \gset
select tests.create_workspace(:'u') as ws_u \gset
select tests.authenticate_as(:'v');
select public.join_relationship_with_code(:'ws_u'::json->>'pairing_code');
select tests.as_postgres();
-- Legacy rows still carry recorded emails; pretend U's slot recorded W's.
update public.couples set partner_a_email = 'w@test.local'
where id = (:'ws_u'::json->>'couple_id')::uuid;

select tests.authenticate_as(:'w');
select throws_ok(format($$ select public.recover_relationship_with_code(%L) $$, :'ws_u'::json->>'recovery_code'),
  'P0001', 'No vacant slot available in this relationship workspace',
  'F-24: an email match cannot displace the current occupant');
select tests.as_postgres();
select results_eq(
  format($$ select partner_a_id, partner_b_id from public.couples where id = %L $$, :'ws_u'::json->>'couple_id'),
  format($$ values (%L::uuid, %L::uuid) $$, :'u', :'v'),
  'F-24: both slots still belong to U and V'
);

select * from finish();
rollback;
