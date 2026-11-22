-- RSVP privacy: the public default, the saved choice, and who can see what.
-- Uses fixture identities and rolls everything back.
\set ON_ERROR_STOP on
begin;

create function pg_temp.check(ok boolean, what text) returns void
language plpgsql as $$
begin
  if ok is not true then raise exception 'FAILED: %', what; end if;
end $$;

create function pg_temp.login(id uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', id::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', id, 'role', 'authenticated')::text,
    true
  );
end $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000000e1', 'viewer@mail.mcgill.ca', '{}'),
  ('00000000-0000-4000-8000-0000000000e2', 'going@mail.mcgill.ca', '{}'),
  ('00000000-0000-4000-8000-0000000000e3', 'stranger@mail.mcgill.ca', '{}');

insert into public.groups (id, slug, name, type) values
  ('00000000-0000-4000-8000-0000000000f0', 'public-rsvps-test', 'Test', 'club');

insert into public.events (id, group_id, title, starts_at, published_at)
select id::uuid, '00000000-0000-4000-8000-0000000000f0', title,
  now() + interval '2 days', now() - interval '1 day'
from (values
  ('00000000-0000-4000-8000-0000000000f1', 'Default'),
  ('00000000-0000-4000-8000-0000000000f2', 'Friends'),
  ('00000000-0000-4000-8000-0000000000f3', 'Private')
) as e (id, title);

insert into public.mcgillians (follower_id, following_id) values (
  '00000000-0000-4000-8000-0000000000e1',
  '00000000-0000-4000-8000-0000000000e2'
);

select pg_temp.check(
  (select bool_and(rsvp_visibility = 'public') from public.profiles
    where id::text like '00000000-0000-4000-8000-0000000000e%'),
  'new accounts start public'
);

-- Someone RSVPs three ways, once without saying who can see it.
set local role authenticated;
select pg_temp.login('00000000-0000-4000-8000-0000000000e2');
insert into public.event_rsvps (event_id, profile_id) values
  ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000e2');
insert into public.event_rsvps (event_id, profile_id, visibility) values
  ('00000000-0000-4000-8000-0000000000f2', '00000000-0000-4000-8000-0000000000e2', 'friends'),
  ('00000000-0000-4000-8000-0000000000f3', '00000000-0000-4000-8000-0000000000e2', 'private');

select pg_temp.check(
  (select visibility = 'public' from public.event_rsvps
    where event_id = '00000000-0000-4000-8000-0000000000f1'),
  'an RSVP without an audience is public'
);

update public.profiles set rsvp_visibility = 'private'
  where id = '00000000-0000-4000-8000-0000000000e2';
select pg_temp.check(
  (select rsvp_visibility = 'private' from public.profiles
    where id = '00000000-0000-4000-8000-0000000000e2'),
  'the choice is saved'
);
select pg_temp.check(
  (select visibility = 'public' from public.event_rsvps
    where event_id = '00000000-0000-4000-8000-0000000000f1'),
  'changing it leaves existing RSVPs alone'
);

-- What the app asks for on their profile.
create function pg_temp.sees() returns text language sql as $$
  select coalesce(string_agg(e.title, ', ' order by e.title), '')
  from public.event_rsvps r join public.events e on e.id = r.event_id
  where r.profile_id = '00000000-0000-4000-8000-0000000000e2'
$$;

select pg_temp.login('00000000-0000-4000-8000-0000000000e1');
select pg_temp.check(pg_temp.sees() = 'Default, Friends', 'a follower sees public and friends RSVPs');
select pg_temp.check(
  (select count(*) from public.friend_rsvps() f
    where f.event_id in ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000f2')
      and f.friend_rsvp_count = 1) = 2,
  'both count on event cards'
);
select pg_temp.check(
  not exists (select 1 from public.friend_rsvps() f
    where f.event_id = '00000000-0000-4000-8000-0000000000f3'),
  'the private one does not'
);

update public.profiles set rsvp_visibility = 'public'
  where id = '00000000-0000-4000-8000-0000000000e2';
select pg_temp.check(
  (select rsvp_visibility = 'private' from public.profiles
    where id = '00000000-0000-4000-8000-0000000000e2'),
  'nobody else can change it'
);

select pg_temp.login('00000000-0000-4000-8000-0000000000e3');
select pg_temp.check(pg_temp.sees() = 'Default', 'a stranger only sees the public RSVP');

reset role;
set local role anon;
select pg_temp.login('00000000-0000-4000-8000-0000000000e3');
do $$
begin
  perform pg_temp.check(pg_temp.sees() = '', 'signed-out visitors see none');
exception when insufficient_privilege then null;
end $$;

reset role;
rollback;
\echo 'public_rsvps: all checks passed'
