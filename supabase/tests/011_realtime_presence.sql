-- S15: Only the couple's current members can join its presence channel.
--
-- Guards against: re-audit R-02 / audit F-13 -- the presence channel was a
-- PUBLIC Realtime channel named couple_presence_<coupleId>. Anyone holding
-- the anon key and a couple id (sent in every push payload, embedded in
-- storage paths, and known to any ex-partner) could join it, watch the
-- couple's online status and track() a spoofed user_id.
--
-- With private channels, Realtime authorizes a join / presence track by
-- evaluating realtime.messages RLS as the joining user, with the GUC
-- realtime.topic set to the channel topic. These tests reproduce exactly
-- that: set the topic, then SELECT (receive presence) or INSERT (track) as
-- the user.
begin;
\ir _helpers.psql

select plan(15);

select tests.create_user('a@test.local') as a \gset
select tests.create_user('b@test.local') as b \gset
select tests.create_user('c@test.local') as c \gset
select tests.create_user('d@test.local') as d \gset
select tests.pair(:'a', :'b') as ab \gset
select tests.pair(:'c', :'d') as cd \gset

-- Runs as the current role with realtime.topic = p_topic, returning whether
-- the user may receive presence (SELECT) / track presence (INSERT).
create or replace function pg_temp.can_receive(p_topic text, p_extension text default 'presence')
returns boolean
language plpgsql
as $$
declare
  v_seen int;
begin
  perform set_config('realtime.topic', p_topic, true);
  select count(*) into v_seen from realtime.messages
  where topic = p_topic and extension = p_extension;
  return v_seen > 0;
end;
$$;

create or replace function pg_temp.can_track(p_topic text, p_extension text default 'presence')
returns boolean
language plpgsql
as $$
begin
  perform set_config('realtime.topic', p_topic, true);
  begin
    insert into realtime.messages (topic, extension, event, payload, private)
    values (p_topic, p_extension, 'track', '{}'::jsonb, true);
    raise exception using errcode = 'XX001';  -- always roll the probe back
  exception
    when sqlstate 'XX001' then return true;
    when insufficient_privilege then return false;
  end;
end;
$$;

-- A presence and a broadcast row on AB's channel for the SELECT probes to find
-- (the same pair the real server inserts for its join check).
insert into realtime.messages (topic, extension, event, payload, private)
values ('couple_presence_' || :'ab', 'presence', 'track', '{"user_id":"seed"}', true),
       ('couple_presence_' || :'ab', 'broadcast', 'probe', '{}', true);

-- Members.
select tests.authenticate_as(:'b');
select ok(pg_temp.can_receive('couple_presence_' || :'ab'), 'member B receives presence on their couple''s channel');
select ok(pg_temp.can_track('couple_presence_' || :'ab'), 'member B can track presence on their couple''s channel');
select ok(pg_temp.can_receive('couple_presence_' || :'ab', 'broadcast'),
  'member B has broadcast READ (the real server requires it to join a private channel)');
select tests.authenticate_as(:'a');
select ok(pg_temp.can_track('couple_presence_' || :'ab'), 'member A can track presence too');

-- Outsider from another couple.
select tests.authenticate_as(:'c');
select ok(not pg_temp.can_receive('couple_presence_' || :'ab'), 'outsider C cannot receive AB''s presence');
select ok(not pg_temp.can_receive('couple_presence_' || :'ab', 'broadcast'), 'outsider C cannot join AB''s private channel (no broadcast read)');
select ok(not pg_temp.can_track('couple_presence_' || :'ab'), 'outsider C cannot track (spoof) on AB''s channel');
select ok(pg_temp.can_track('couple_presence_' || :'cd'), 'C can still track on their own channel');

-- Only presence is authorised, and only on the couple_presence_ topic.
select tests.authenticate_as(:'b');
select ok(not pg_temp.can_track('couple_presence_' || :'ab', 'broadcast'), 'members can never SEND a broadcast on the topic');
select ok(not pg_temp.can_track(:'ab'::text), 'a bare couple-id topic is not authorised');
select ok(not pg_temp.can_track('couple_presence_' || :'ab' || '_x'), 'a topic merely prefixed with the couple id is not authorised');

-- anon.
select tests.as_anon();
select ok(not pg_temp.can_receive('couple_presence_' || :'ab'), 'anon cannot receive presence');
select ok(not pg_temp.can_track('couple_presence_' || :'ab'), 'anon cannot track presence');

-- Ex-partner: unlinking ends presence access immediately.
select tests.authenticate_as(:'a');
select public.disconnect_relationship_workspace();
select ok(not pg_temp.can_track('couple_presence_' || :'ab'), 'after unlink A can no longer track on the old channel');
select ok(not pg_temp.can_receive('couple_presence_' || :'ab'), 'after unlink A can no longer watch B''s presence');

select * from finish();
rollback;
