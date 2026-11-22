-- Integration safety: explicit Public RSVPs must be reversible, and the newest
-- migration must keep the Private defaults.
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
  (select bool_and(rsvp_visibility = 'private') from public.profiles
    where id::text like '00000000-0000-4000-8000-0000000000e%'),
  'new accounts start Private'
);
select pg_temp.check(
  (select column_default = '''private''::rsvp_visibility'
     from information_schema.columns
     where table_schema = 'public' and table_name = 'event_rsvps'
       and column_name = 'visibility'),
  'the RSVP column also defaults to Private'
);

create function pg_temp.sees() returns int language sql as $$
  select count(*)::int from public.event_rsvps
  where profile_id = '00000000-0000-4000-8000-0000000000e2'
$$;

set local role authenticated;
select pg_temp.login('00000000-0000-4000-8000-0000000000e2');
insert into public.event_rsvps (event_id, profile_id, visibility) values
  ('00000000-0000-4000-8000-0000000000f1', auth.uid(), 'public'),
  ('00000000-0000-4000-8000-0000000000f2', auth.uid(), 'friends'),
  ('00000000-0000-4000-8000-0000000000f3', auth.uid(), 'private');
select pg_temp.check(
  (select bool_and(visibility = 'private') from public.event_rsvps
    where profile_id = auth.uid()), 'clients cannot supply a different audience'
);
select public.set_my_rsvp_visibility('public');
select pg_temp.login('00000000-0000-4000-8000-0000000000e3');
select pg_temp.check(pg_temp.sees() = 3, 'an authenticated stranger sees explicit Public RSVPs');
select pg_temp.login('00000000-0000-4000-8000-0000000000e2');
select public.set_my_rsvp_visibility('friends');
select pg_temp.login('00000000-0000-4000-8000-0000000000e1');
select pg_temp.check(pg_temp.sees() = 0, 'a one-way follow cannot see Friends RSVPs');
select pg_temp.login('00000000-0000-4000-8000-0000000000e2');
insert into public.mcgillians (follower_id, following_id)
values (auth.uid(), '00000000-0000-4000-8000-0000000000e1');
select pg_temp.login('00000000-0000-4000-8000-0000000000e1');
select pg_temp.check(pg_temp.sees() = 3, 'a mutual connection sees Friends RSVPs');
select pg_temp.login('00000000-0000-4000-8000-0000000000e2');
select public.set_my_rsvp_visibility('private');
select pg_temp.login('00000000-0000-4000-8000-0000000000e1');
select pg_temp.check(pg_temp.sees() = 0, 'switching back to Private closes access to every RSVP');

reset role;
set local role anon;
do $$
begin
  perform pg_temp.check(pg_temp.sees() = 0, 'signed-out visitors see none');
exception when insufficient_privilege then null;
end $$;

reset role;
rollback;
