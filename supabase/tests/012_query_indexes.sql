-- The app's hottest ordered queries are served by matching indexes
-- (20261003040000_query_matched_indexes.sql). Checks the planner's actual
-- choice for the exact query shapes the controllers issue, on enough data
-- that a sequential scan would otherwise win.
begin;
\ir _helpers.psql

select plan(4);

select tests.create_user('a@test.local') as a \gset
select tests.create_user('b@test.local') as b \gset
select tests.pair(:'a', :'b') as ab \gset

insert into public.love_notes (couple_id, type, content, created_at)
select :'ab', case when g % 10 = 0 then 'drawing' else 'chat' end, 'x' || g,
       now() - (g || ' minutes')::interval
from generate_series(1, 5000) g;
insert into public.timeline_items (couple_id, title, date)
select :'ab', 'm' || g, now() - (g || ' days')::interval from generate_series(1, 3000) g;
analyze public.love_notes;
analyze public.timeline_items;

create or replace function pg_temp.plan_of(p_sql text)
returns text
language plpgsql
as $$
declare
  v_line text;
  v_plan text := '';
begin
  for v_line in execute 'explain (costs off) ' || p_sql loop
    v_plan := v_plan || v_line || E'\n';
  end loop;
  return v_plan;
end;
$$;

-- LoveChatController.syncInitialData
select matches(
  pg_temp.plan_of(format(
    $$ select * from public.love_notes where couple_id = %L and type = 'chat' order by created_at desc limit 200 $$, :'ab')),
  'Index Scan using love_notes_couple_type_created_idx',
  'chat load walks the composite index'
);
select doesnt_match(
  pg_temp.plan_of(format(
    $$ select * from public.love_notes where couple_id = %L and type = 'chat' order by created_at desc limit 200 $$, :'ab')),
  'Sort',
  'chat load needs no sort step'
);

-- TimelineController.syncInitialData
select matches(
  pg_temp.plan_of(format(
    $$ select * from public.timeline_items where couple_id = %L order by date desc limit 100 $$, :'ab')),
  'timeline_items_couple_date_idx',
  'timeline load uses the (couple_id, date) index'
);

-- The dropped single-column indexes are really gone (no double write cost).
select is(
  array(select indexname::text from pg_indexes where schemaname = 'public'
        and indexname in ('idx_love_notes_couple_id', 'idx_timeline_items_couple_id')),
  '{}'::text[],
  'redundant couple_id-only indexes were dropped'
);

select * from finish();
rollback;
