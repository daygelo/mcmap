-- Run against a disposable Supabase database with all migrations applied.
\set ON_ERROR_STOP on
begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('94000000-0000-4000-8000-00000000000a', 'social-a@mcgill.ca', '{"full_name":"Maya Privacy"}'),
  ('94000000-0000-4000-8000-00000000000b', 'social-b@mcgill.ca', '{"full_name":"Leo Privacy"}'),
  ('94000000-0000-4000-8000-00000000000c', 'social-c@mcgill.ca', '{"full_name":"Unrelated Student"}');

update public.profiles set onboarding_completed = true, account_purpose = 'organizer'
where id in (
  '94000000-0000-4000-8000-00000000000a',
  '94000000-0000-4000-8000-00000000000b',
  '94000000-0000-4000-8000-00000000000c'
);
update public.profiles set account_purpose = 'student', degree_level = 'undergraduate',
  faculty = 'Science', major = 'Biology', u_year = 'U2'
where id = '94000000-0000-4000-8000-00000000000a';

do $$
begin
  if (select count(*) from public.profiles
      where id::text like '94000000-%' and not is_private and rsvp_visibility = 'private') <> 3
  then raise exception 'New public profiles must begin with Private RSVP privacy'; end if;
end;
$$;

insert into public.groups (id, slug, name, type)
values ('94100000-0000-4000-8000-000000000001', 'privacy-fixture', 'Privacy Fixture', 'club');
insert into public.events (id, group_id, title, starts_at, published_at, supports_unrestricted_rsvp)
select ('94200000-0000-4000-8000-00000000000' || suffix)::uuid,
  '94100000-0000-4000-8000-000000000001', title,
  now() + interval '10 hours', now() - interval '10 minutes', eligible
from (values ('1', 'Privacy test', false), ('2', 'Second event', false),
             ('3', 'Auto eligible', true), ('4', 'Auto excluded', false)) v(suffix, title, eligible);

insert into public.profile_organization_follows (profile_id, follows) values
  ('94000000-0000-4000-8000-00000000000a', jsonb_build_object(
    'privacy-fixture', jsonb_build_object('auto_rsvp_enabled_at', now() - interval '1 hour')
  )),
  ('94000000-0000-4000-8000-00000000000b', '{"privacy-fixture":{"event_notifications_enabled_at":"2000-01-01T00:00:00Z"}}'),
  ('94000000-0000-4000-8000-00000000000c', '{"privacy-fixture":{}}');

-- Verify every surface under the actual caller role, including aggregate
-- statistics and a previously written deadline reminder.
create function public.assert_social_visibility(expected int, friend_count int)
returns void language plpgsql security invoker as $$
declare
  a constant uuid := '94000000-0000-4000-8000-00000000000a';
  target constant uuid := '94200000-0000-4000-8000-000000000001';
  counts record;
  reminder record;
begin
  if (select count(*) from public.event_rsvps r join public.events e on e.id = r.event_id
      where r.profile_id = a and r.event_id = target) <> expected then
    raise exception 'Wrong attendance for viewer % (expected %)', auth.uid(), expected;
  end if;
  select * into counts from public.search_mcgillians('Maya Privacy') where id = a;
  if not found or counts.events_count <> expected or counts.clubs_count <> expected then
    raise exception 'Search statistics reveal or suppress attendance for viewer %', auth.uid();
  end if;
  if coalesce((select friend_rsvp_count from public.friend_rsvps(array[target])), 0) <> friend_count then
    raise exception 'Wrong friend count for viewer %', auth.uid();
  end if;
  if friend_count = 1 and not exists (
    select 1 from public.friend_rsvps(array[target]) f
    where f.friend_rsvps->0->>'profile_id' = a::text
      and f.friend_rsvps->0->>'full_name' = 'Maya Privacy'
  ) then raise exception 'Friend identity missing from permitted result'; end if;
  perform public.refresh_my_notifications();
  select * into reminder from public.notification_inbox
  where event_id = target and type = 'event_deadline_soon';
  if not found or reminder.friend_rsvp_count <> friend_count or
      (reminder.body like '%McGillians RSVPed!') <> (friend_count > 0) then
    raise exception 'Inbox count or text leaks or suppresses attendance for viewer %', auth.uid();
  end if;
end;
$$;

set local role authenticated;
set local request.jwt.claim.sub = '94000000-0000-4000-8000-00000000000a';
insert into public.mcgillians (follower_id, following_id)
values (auth.uid(), '94000000-0000-4000-8000-00000000000b');
-- A client-supplied visibility is ignored.
insert into public.event_rsvps (event_id, profile_id, visibility, created_at)
values ('94200000-0000-4000-8000-000000000001', auth.uid(), 'public', '2026-01-01T00:00:00Z');
do $$
begin
  if (select visibility from public.event_rsvps where profile_id = auth.uid())
     is distinct from 'private' then raise exception 'Insert bypassed global visibility'; end if;
  begin
    update public.profiles set rsvp_visibility = 'public' where id = auth.uid();
    raise exception 'Raw profile update bypassed atomic RPC';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.event_rsvps set visibility = 'public' where profile_id = auth.uid();
    raise exception 'Raw RSVP update bypassed account preference';
  exception when insufficient_privilege then null;
  end;
end;
$$;

set local request.jwt.claim.sub = '94000000-0000-4000-8000-00000000000b';
insert into public.mcgillians (follower_id, following_id)
values (auth.uid(), '94000000-0000-4000-8000-00000000000a');
select public.assert_social_visibility(0, 0);

set local request.jwt.claim.sub = '94000000-0000-4000-8000-00000000000c';
select public.refresh_my_notifications();
do $$
begin
  if exists (select 1 from public.notification_inbox) then
    raise exception 'Following alone enabled event notifications';
  end if;
end;
$$;
select public.set_organization_event_notifications('privacy-fixture', true);
-- Backdate fixture consent so it predates this test's existing publication.
update public.profile_organization_follows
set follows = '{"privacy-fixture":{"event_notifications_enabled_at":"2000-01-01T00:00:00Z"}}'
where profile_id = auth.uid();
select public.assert_social_visibility(0, 0);
insert into public.mcgillians (follower_id, following_id, status)
values (auth.uid(), '94000000-0000-4000-8000-00000000000a', 'following');
do $$
begin
  begin
    update public.mcgillians set follower_id = '94000000-0000-4000-8000-00000000000a'
      where following_id = auth.uid();
    raise exception 'A recipient can forge a reciprocal connection';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.event_rsvps (event_id, profile_id)
    values ('94200000-0000-4000-8000-000000000002', '94000000-0000-4000-8000-00000000000a');
    raise exception 'A viewer can insert another person''s RSVP';
  exception when insufficient_privilege then null;
  end;
  perform public.refresh_my_auto_rsvps();
  if exists(select 1 from public.event_rsvps where profile_id = auth.uid()) then
    raise exception 'Auto-RSVP requires explicit consent';
  end if;
end;
$$;

set local request.jwt.claim.sub = '94000000-0000-4000-8000-00000000000a';
select public.set_my_rsvp_visibility('friends');

set local request.jwt.claim.sub = '94000000-0000-4000-8000-00000000000b';
select public.assert_social_visibility(1, 1);
set local request.jwt.claim.sub = '94000000-0000-4000-8000-00000000000c';
select public.assert_social_visibility(0, 0);

set local request.jwt.claim.sub = '94000000-0000-4000-8000-00000000000a';
select public.set_my_rsvp_visibility('public');
set local request.jwt.claim.sub = '94000000-0000-4000-8000-00000000000c';
select public.assert_social_visibility(1, 0);

-- Sign back in and create a new RSVP. Defaults are server-owned for clients
-- that omit visibility and for auto-RSVP workers alike.
set local request.jwt.claim.sub = '94000000-0000-4000-8000-00000000000a';
insert into public.event_rsvps (event_id, profile_id)
values ('94200000-0000-4000-8000-000000000002', auth.uid());
select public.refresh_my_auto_rsvps();
do $$
begin
  if (select rsvp_visibility from public.profiles where id = auth.uid()) is distinct from 'public'
    or (select count(*) from public.event_rsvps where profile_id = auth.uid() and visibility = 'public') <> 3
    or exists (select 1 from public.event_rsvps where event_id = '94200000-0000-4000-8000-000000000004')
    or (select created_at from public.event_rsvps where event_id = '94200000-0000-4000-8000-000000000001')
      is distinct from '2026-01-01T00:00:00Z'::timestamptz
    or exists (select 1 from public.friend_rsvps()) then
    raise exception 'Preference, eligibility, original timestamps, or self-exclusion failed';
  end if;
end;
$$;
delete from public.event_rsvps where profile_id = auth.uid()
  and event_id in ('94200000-0000-4000-8000-000000000002', '94200000-0000-4000-8000-000000000003');
select public.refresh_my_auto_rsvps();

select public.set_my_rsvp_visibility('private');
do $$
begin
  if (select count(*) from public.event_rsvps where profile_id = auth.uid() and visibility = 'private') <> 1
  then raise exception 'Auto-RSVP returned after cancellation, or owner lost their RSVP'; end if;
end;
$$;
set local request.jwt.claim.sub = '94000000-0000-4000-8000-00000000000b';
select public.assert_social_visibility(0, 0);
set local request.jwt.claim.sub = '94000000-0000-4000-8000-00000000000c';
select public.assert_social_visibility(0, 0);

set local request.jwt.claim.sub = '94000000-0000-4000-8000-00000000000a';
select public.set_my_rsvp_visibility('friends');
delete from public.mcgillians where follower_id = auth.uid()
  and following_id = '94000000-0000-4000-8000-00000000000b';
set local request.jwt.claim.sub = '94000000-0000-4000-8000-00000000000b';
select public.assert_social_visibility(0, 0);

set local request.jwt.claim.sub = '94000000-0000-4000-8000-00000000000a';
insert into public.mcgillians (follower_id, following_id)
values (auth.uid(), '94000000-0000-4000-8000-00000000000b');
set local request.jwt.claim.sub = '94000000-0000-4000-8000-00000000000b';
select public.assert_social_visibility(1, 1);
set local request.jwt.claim.sub = '94000000-0000-4000-8000-00000000000a';
delete from public.event_rsvps where profile_id = auth.uid();
set local request.jwt.claim.sub = '94000000-0000-4000-8000-00000000000b';
select public.assert_social_visibility(0, 0);

set local role anon;
do $$
begin
  begin
    perform public.set_my_rsvp_visibility('public');
    raise exception 'Anon could update preference';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.refresh_my_auto_rsvps();
    raise exception 'Anon could request auto-RSVPs';
  exception when insufficient_privilege then null;
  end;
end;
$$;

rollback;
