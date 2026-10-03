-- S13: Cross-couple feature data remains inaccessible through RLS.
-- S02: Users cannot join arbitrary couples by modifying users.couple_id.
--
-- Two couples: (A, B) and (C, D). One row per couple-scoped table is seeded
-- for couple AB. For every table, the member B is a positive control (the row
-- exists and is visible, so the outsider checks cannot pass vacuously) and
-- the outsider C must be unable to SELECT, INSERT into, UPDATE or DELETE it.
begin;
\ir _helpers.psql

select plan(71);

select tests.create_user('a@test.local') as a \gset
select tests.create_user('b@test.local') as b \gset
select tests.create_user('c@test.local') as c \gset
select tests.create_user('d@test.local') as d \gset
select tests.pair(:'a', :'b') as ab \gset
select tests.pair(:'c', :'d') as cd \gset

-- tbl, a predicate that pins the seeded row, an INSERT values clause for the
-- outsider (all aimed at couple AB), and a harmless UPDATE assignment.
create temp table rls_fixture (
  tbl text, seed_sql text, insert_sql text, update_set text
) on commit drop;

insert into rls_fixture values
  ('timeline_items',
   'insert into public.timeline_items (couple_id, title, date) values (%1$L, ''seed'', now())',
   'insert into public.timeline_items (couple_id, title, date) values (%1$L, ''evil'', now())',
   'title = ''evil'''),
  ('bucket_list',
   'insert into public.bucket_list (couple_id, title) values (%1$L, ''seed'')',
   'insert into public.bucket_list (couple_id, title) values (%1$L, ''evil'')',
   'title = ''evil'''),
  ('calendar_events',
   'insert into public.calendar_events (couple_id, title, date) values (%1$L, ''seed'', now())',
   'insert into public.calendar_events (couple_id, title, date) values (%1$L, ''evil'', now())',
   'title = ''evil'''),
  ('love_notes',
   'insert into public.love_notes (couple_id, type, content) values (%1$L, ''chat'', ''seed'')',
   'insert into public.love_notes (couple_id, type, content) values (%1$L, ''chat'', ''evil'')',
   'content = ''evil'''),
  ('moods',
   'insert into public.moods (id, couple_id, date) values (''seed-'' || %1$L, %1$L, ''2026-01-01'')',
   'insert into public.moods (id, couple_id, date) values (''evil-'' || %1$L, %1$L, ''2026-01-02'')',
   'note = ''evil'''),
  ('daily_questions',
   'insert into public.daily_questions (date, couple_id, question) values (''2026-01-01'', %1$L, ''seed'')',
   'insert into public.daily_questions (date, couple_id, question) values (''2026-01-02'', %1$L, ''evil'')',
   'question = ''evil'''),
  ('gift_reminders',
   'insert into public.gift_reminders (couple_id, title, date) values (%1$L, ''seed'', now())',
   'insert into public.gift_reminders (couple_id, title, date) values (%1$L, ''evil'', now())',
   'title = ''evil'''),
  ('time_capsules',
   'insert into public.time_capsules (couple_id, message, open_date) values (%1$L, ''seed'', now())',
   'insert into public.time_capsules (couple_id, message, open_date) values (%1$L, ''evil'', now())',
   'message = ''evil'''),
  ('topic_cards',
   'insert into public.topic_cards (couple_id, category, question) values (%1$L, ''c'', ''seed'')',
   'insert into public.topic_cards (couple_id, category, question) values (%1$L, ''c'', ''evil'')',
   'question = ''evil'''),
  ('topic_card_likes',
   'insert into public.topic_card_likes (couple_id, user_id, card_id) values (%1$L, %2$L, ''seed'')',
   'insert into public.topic_card_likes (couple_id, user_id, card_id) values (%1$L, %3$L, ''evil'')',
   'card_id = ''evil'''),
  ('love_taps',
   'insert into public.love_taps (couple_id, date) values (%1$L, ''2026-01-01'')',
   'insert into public.love_taps (couple_id, date) values (%1$L, ''2026-01-02'')',
   'partner1_tapped = true'),
  ('license_details',
   'insert into public.license_details (couple_id) values (%1$L) on conflict do nothing',
   'insert into public.license_details (couple_id) values (%1$L)',
   'relationship_title = ''evil''');

-- Seeds as postgres, then for each table: member sees it, outsider cannot
-- see / insert / update / delete it. 5 assertions per table.
create or replace function pg_temp.probe(p_ab uuid, p_member uuid, p_outsider uuid)
returns setof text
language plpgsql
as $$
declare
  f record;
  v_count int;
begin
  for f in select * from rls_fixture order by tbl loop
    perform tests.as_postgres();
    execute format(f.seed_sql, p_ab, p_member, p_outsider);

    perform tests.authenticate_as(p_member);
    execute format('select count(*) from public.%I where couple_id = %L', f.tbl, p_ab) into v_count;
    return next ok(v_count >= 1, f.tbl || ': member sees its couple''s rows');

    perform tests.authenticate_as(p_outsider);
    execute format('select count(*) from public.%I where couple_id = %L', f.tbl, p_ab) into v_count;
    return next is(v_count, 0, f.tbl || ': outsider SELECT sees nothing');

    return next throws_ok(format(f.insert_sql, p_ab, p_member, p_outsider), '42501', null,
      f.tbl || ': outsider INSERT into another couple is refused');

    execute format('with u as (update public.%I set %s where couple_id = %L returning 1) select count(*) from u',
      f.tbl, f.update_set, p_ab) into v_count;
    return next is(v_count, 0, f.tbl || ': outsider UPDATE touches nothing');

    execute format('with d as (delete from public.%I where couple_id = %L returning 1) select count(*) from d',
      f.tbl, p_ab) into v_count;
    return next is(v_count, 0, f.tbl || ': outsider DELETE removes nothing');
  end loop;
  perform tests.as_postgres();
end;
$$;

select * from pg_temp.probe(:'ab', :'b', :'c');   -- 60 assertions

-- Ground truth after the outsider's attempts: every seeded row still intact.
select is(
  (select count(*)::int from public.timeline_items where couple_id = :'ab' and title = 'seed')
  + (select count(*)::int from public.bucket_list where couple_id = :'ab' and title = 'seed')
  + (select count(*)::int from public.love_notes where couple_id = :'ab' and content = 'seed'),
  3,
  'seeded rows survived the outsider''s UPDATE/DELETE attempts unchanged'
);

-- users / couples / key material.
select tests.authenticate_as(:'a');
select store_wrapped_key(:'b', 'wrapped-for-b');
select tests.authenticate_as(:'c');
select is((select count(*)::int from public.users where id in (:'a', :'b')), 0, 'users: outsider cannot read another couple''s profiles');
select is((select count(*)::int from public.couples where id = :'ab'), 0, 'couples: outsider cannot read another couple''s row');
select is((select count(*)::int from public.couple_key_exchanges where couple_id = :'ab'), 0, 'couple_key_exchanges: outsider cannot read wrapped keys');
update public.users set display_name = 'pwned' where id = :'a';
select is(
  (select count(*)::int from public.user_notification_preferences),
  1,
  'user_notification_preferences: user sees only their own row'
);
select tests.as_postgres();
select isnt((select display_name from public.users where id = :'a'), 'pwned', 'users: outsider cannot update another user''s profile');
select tests.authenticate_as(:'c');

-- S02: pivot attempt -- C rewrites their own couple_id to AB.
update public.users set couple_id = :'ab' where id = :'c';
select tests.as_postgres();
select is((select couple_id from public.users where id = :'c'), :'cd'::uuid, 'S02: protect_users_couple_id reverted C''s pivot to couple AB');
select tests.authenticate_as(:'c');
select is((select count(*)::int from public.timeline_items where couple_id = :'ab'), 0, 'S02: after the pivot attempt C still sees none of AB''s data');
select is(public.is_member_of_couple(:'ab'), false, 'S02: C is not a member of AB');

-- Anonymous callers see nothing (no couple-scoped policy admits anon).
select tests.as_anon();
select throws_ok($$ select count(*) from public.couples $$, '42501', null, 'anon: holds no privilege on couples at all');
select is((select count(*)::int from public.users), 0, 'anon: users invisible');

select * from finish();
rollback;
