-- S14: Storage objects require authenticated couple membership.
--
-- Guards against: audit F-02 -- the four buckets were created public = true
-- (20260702000003/4), and Supabase serves public buckets at
-- /storage/v1/object/public/... WITHOUT consulting storage.objects RLS. The
-- couple-scoped policies below are only the real boundary once every bucket
-- is private, so this file asserts both halves.
begin;
\ir _helpers.psql

select plan(13);

-- ---------------------------------------------------------------------------
-- Bucket privacy
-- ---------------------------------------------------------------------------
select is(
  array(select id from storage.buckets where id in ('avatars', 'love-notes', 'timeline', 'vault-photos') and public order by id),
  '{}'::text[],
  'no Days Together bucket is public'
);
select is(
  (select count(*)::int from storage.buckets where id in ('avatars', 'love-notes', 'timeline')),
  3,
  'the three live buckets exist (privacy check is not vacuous)'
);

-- ---------------------------------------------------------------------------
-- Object-level RLS: couple AB's objects vs. outsider C
-- ---------------------------------------------------------------------------
select tests.create_user('a@test.local') as a \gset
select tests.create_user('b@test.local') as b \gset
select tests.create_user('c@test.local') as c \gset
select tests.create_user('d@test.local') as d \gset
select tests.pair(:'a', :'b') as ab \gset
select tests.pair(:'c', :'d') as cd \gset

insert into storage.objects (bucket_id, name, owner) values
  ('timeline',   'couples/' || :'ab' || '/timeline/m1.enc', :'a'),
  ('love-notes', 'couples/' || :'ab' || '/notes/n1.enc',    :'a'),
  ('avatars',    'couples/' || :'ab' || '/avatars/a.jpg',   :'a');

select tests.authenticate_as(:'b');
select is((select count(*)::int from storage.objects where name like 'couples/' || :'ab' || '/%'), 3, 'partner B can read all of the couple''s objects');

select tests.authenticate_as(:'c');
select is((select count(*)::int from storage.objects where bucket_id = 'timeline'   and name like 'couples/' || :'ab' || '/%'), 0, 'outsider cannot read timeline objects');
select is((select count(*)::int from storage.objects where bucket_id = 'love-notes' and name like 'couples/' || :'ab' || '/%'), 0, 'outsider cannot read love-notes objects');
select is((select count(*)::int from storage.objects where bucket_id = 'avatars'    and name like 'couples/' || :'ab' || '/%'), 0, 'outsider cannot read avatar objects');
select throws_ok(
  format($$ insert into storage.objects (bucket_id, name, owner) values ('timeline', 'couples/%s/timeline/evil.enc', %L) $$, :'ab', :'c'),
  '42501', null, 'outsider cannot upload into another couple''s folder'
);
select is(
  tests.rows_affected(format($$ update storage.objects set metadata = '{"evil":true}' where name like 'couples/%s/%%' $$, :'ab')),
  0, 'outsider cannot overwrite another couple''s objects'
);
select lives_ok(
  format($$ insert into storage.objects (bucket_id, name, owner) values ('timeline', 'couples/%s/timeline/own.enc', %L) $$, :'cd', :'c'),
  'outsider can still upload into their own couple''s folder'
);

-- Avatars have their own write policy; it must be couple-scoped too.
select throws_ok(
  format($$ insert into storage.objects (bucket_id, name, owner) values ('avatars', 'couples/%s/avatars/evil.jpg', %L) $$, :'ab', :'c'),
  '42501', null, 'outsider cannot plant an avatar in another couple''s folder'
);

select tests.as_anon();
select is((select count(*)::int from storage.objects where bucket_id in ('avatars', 'love-notes', 'timeline')), 0, 'anon cannot list any object');

-- After unlink, the leaving partner loses storage access too.
select tests.authenticate_as(:'a');
select public.disconnect_relationship_workspace();
select is((select count(*)::int from storage.objects where name like 'couples/' || :'ab' || '/%'), 0, 'after unlink A can no longer read the couple''s objects');
select tests.authenticate_as(:'b');
select is((select count(*)::int from storage.objects where name like 'couples/' || :'ab' || '/%'), 3, 'B still can');

select * from finish();
rollback;
