-- Run as postgres against a local Supabase database with every migration
-- applied. Everything is rolled back.
\set ON_ERROR_STOP on
begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('a1000000-0000-4000-8000-000000000001', 'notify-me@mcgill.ca', '{"full_name": "Me Student"}'),
  ('a1000000-0000-4000-8000-000000000002', 'notify-ana@mcgill.ca', '{"full_name": "Ana Friend"}'),
  ('a1000000-0000-4000-8000-000000000003', 'notify-ben@mcgill.ca', '{"full_name": "Ben Friend"}'),
  ('a1000000-0000-4000-8000-000000000004', 'notify-cam@mcgill.ca', '{"full_name": "Cam Friend"}'),
  ('a1000000-0000-4000-8000-000000000005', 'notify-dee@mcgill.ca', '{"full_name": "Dee Friend"}'),
  ('a1000000-0000-4000-8000-000000000006', 'notify-private@mcgill.ca', '{"full_name": "Pat Private"}'),
  ('a1000000-0000-4000-8000-000000000007', 'notify-stranger@mcgill.ca', '{"full_name": "Sam Stranger"}'),
  ('a1000000-0000-4000-8000-000000000008', 'notify-requested@mcgill.ca', '{"full_name": "Ray Requested"}'),
  ('a1000000-0000-4000-8000-000000000009', 'notify-host@mcgill.ca', '{"full_name": "Hana Host"}');
update public.profiles set is_private = true
  where id = 'a1000000-0000-4000-8000-000000000008';
update public.profiles set avatar_url = 'https://example.test/dee.png'
  where id = 'a1000000-0000-4000-8000-000000000005';

-- "Me" follows everyone but Sam; Ray's request is still pending.
insert into public.mcgillians (follower_id, following_id)
select 'a1000000-0000-4000-8000-000000000001', id from public.profiles
where id in (
  'a1000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000003',
  'a1000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-000000000005',
  'a1000000-0000-4000-8000-000000000006', 'a1000000-0000-4000-8000-000000000008'
);

insert into public.groups (id, slug, name, short_name) values
  ('b1000000-0000-4000-8000-000000000001', 'notify-eus', 'Engineering Undergraduate Society', 'EUS'),
  ('b1000000-0000-4000-8000-000000000002', 'notify-chess', 'Chess Club', null),
  ('b1000000-0000-4000-8000-000000000003', 'notify-other', 'Unfollowed Club', null);

insert into public.profile_organization_follows (profile_id, follows) values
  ('a1000000-0000-4000-8000-000000000001', '{"notify-eus": {}, "notify-chess": {}}'),
  ('a1000000-0000-4000-8000-000000000007', '{"notify-eus": {}}'),
  ('a1000000-0000-4000-8000-000000000009', '{"notify-eus": {}}');
insert into public.group_publishers (profile_id, group_id, role) values
  ('a1000000-0000-4000-8000-000000000009', 'b1000000-0000-4000-8000-000000000001', 'president');

-- ---------------------------------------------------------------------------
-- New events
-- ---------------------------------------------------------------------------

-- Through the real publishing function, twice (a retry of the same event).
set local role authenticated;
set local request.jwt.claim.sub = 'a1000000-0000-4000-8000-000000000009';
select public.publish_event(
  'c1000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001',
  'Blues Pub', 'Weekly pub.', now() + interval '5 days', null, 'FDA'
);
select public.publish_event(
  'c1000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001',
  'Blues Pub', 'Weekly pub.', now() + interval '5 days', null, 'FDA'
);
reset role;

insert into public.events (id, group_id, title, starts_at, rsvp_deadline, published_at, created_at, cancelled) values
  -- no short name; closes tomorrow; nobody going
  ('c1000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000002', 'Blitz Night',
    now() + interval '20 hours', null, now(), now(), false),
  -- starts in three days but the deadline is in two hours
  ('c1000000-0000-4000-8000-000000000003', 'b1000000-0000-4000-8000-000000000001', 'Formal',
    now() + interval '3 days', now() + interval '2 hours', now(), now(), false),
  -- starts soon, but its own deadline has passed
  ('c1000000-0000-4000-8000-000000000004', 'b1000000-0000-4000-8000-000000000001', 'Closed',
    now() + interval '3 hours', now() - interval '1 hour', now(), now(), false),
  ('c1000000-0000-4000-8000-000000000005', 'b1000000-0000-4000-8000-000000000001', 'Cancelled',
    now() + interval '3 hours', null, now(), now(), true),
  ('c1000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000003', 'Not followed',
    now() + interval '3 hours', null, now(), now(), false),
  -- not visible until tomorrow
  ('c1000000-0000-4000-8000-000000000007', 'b1000000-0000-4000-8000-000000000001', 'Scheduled',
    now() + interval '10 hours', null, now() + interval '5 hours', now(), false),
  -- one friend going
  ('c1000000-0000-4000-8000-000000000008', 'b1000000-0000-4000-8000-000000000001', 'Study Hall',
    now() + interval '6 hours', null, now(), now(), false),
  -- I'm already going
  ('c1000000-0000-4000-8000-000000000009', 'b1000000-0000-4000-8000-000000000001', 'Already Going',
    now() + interval '6 hours', null, now(), now(), false),
  -- no date at all, and 100% in the title (format() must not choke on it)
  ('c1000000-0000-4000-8000-00000000000a', 'b1000000-0000-4000-8000-000000000001', '100% %s Undated',
    null, null, now(), now(), false);

do $$
declare
  mine text[];
begin
  select array_agg(e.title order by e.title) into mine
  from public.notifications n join public.events e on e.id = n.event_id
  where n.user_id = 'a1000000-0000-4000-8000-000000000001' and n.type = 'new_followed_event';
  if mine is distinct from array['100% %s Undated', 'Already Going', 'Blitz Night',
    'Blues Pub', 'Formal', 'Study Hall'] then
    raise exception 'Wrong new-event notifications: %', mine;
  end if;
  if not exists (select 1 from public.notifications
    where user_id = 'a1000000-0000-4000-8000-000000000001'
      and event_id = 'c1000000-0000-4000-8000-000000000001'
      and title = 'New Event from EUS' and body = 'EUS just posted: Blues Pub') then
    raise exception 'Wrong new-event wording';
  end if;
  if not exists (select 1 from public.notifications
    where event_id = 'c1000000-0000-4000-8000-000000000002' and title = 'New Event from Chess Club') then
    raise exception 'A group without a short name should use its name';
  end if;
  if exists (select 1 from public.notifications
    where user_id = 'a1000000-0000-4000-8000-000000000009'
      and event_id = 'c1000000-0000-4000-8000-000000000001') then
    raise exception 'Organizers should not be told about their own event';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- RSVPs
-- ---------------------------------------------------------------------------

insert into public.event_rsvps (event_id, profile_id, visibility) values
  -- Formal: four visible friends, one private, one stranger, one pending.
  ('c1000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000002', 'friends'),
  ('c1000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000003', 'public'),
  ('c1000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000004', 'friends'),
  ('c1000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000005', 'friends'),
  ('c1000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000006', 'private'),
  ('c1000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000007', 'public'),
  ('c1000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000008', 'public'),
  -- Study Hall: one.
  ('c1000000-0000-4000-8000-000000000008', 'a1000000-0000-4000-8000-000000000002', 'friends'),
  -- Blitz Night: only a private one.
  ('c1000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000006', 'private'),
  ('c1000000-0000-4000-8000-000000000009', 'a1000000-0000-4000-8000-000000000001', 'private');

set local role authenticated;
set local request.jwt.claim.sub = 'a1000000-0000-4000-8000-000000000001';
do $$
declare
  formal record;
begin
  if (select count(*) from public.friend_rsvps()) <> 2 then
    raise exception 'Only Formal and Study Hall have visible friends going';
  end if;
  select * into formal from public.friend_rsvps(array['c1000000-0000-4000-8000-000000000003']::uuid[]);
  if formal.friend_rsvp_count <> 4 then
    raise exception 'Formal should count 4 friends, got %', formal.friend_rsvp_count;
  end if;
  if jsonb_array_length(formal.friend_rsvps) <> 3
    or formal.friend_rsvps->0->>'full_name' <> 'Dee Friend'
    or formal.friend_rsvps->0->>'avatar_url' <> 'https://example.test/dee.png' then
    raise exception 'Wrong friends: %', formal.friend_rsvps;
  end if;
  if (select (formal.friend_rsvps->0) - 'full_name' - 'avatar_url') <> '{}'::jsonb then
    raise exception 'Friends should only carry a name and a picture';
  end if;

  begin
    insert into public.event_rsvps (event_id, profile_id) values
      ('c1000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-000000000001');
    raise exception 'RSVP after the deadline was accepted';
  exception when insufficient_privilege then null;
  end;
  insert into public.event_rsvps (event_id, profile_id) values
    ('c1000000-0000-4000-8000-00000000000a', 'a1000000-0000-4000-8000-000000000001'),
    ('c1000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001');
end;
$$;

-- A stranger sees only public RSVPs by people they follow: none.
set local request.jwt.claim.sub = 'a1000000-0000-4000-8000-000000000007';
do $$
begin
  if exists (select 1 from public.friend_rsvps()) then
    raise exception 'Someone with no McGillians has friend RSVPs';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Deadlines
-- ---------------------------------------------------------------------------

-- Students can't run the generator for everyone, or for someone else.
do $$
begin
  begin
    perform public.generate_ending_soon_notifications();
    raise exception 'A student ran the generator for everyone';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.write_notifications('a1000000-0000-4000-8000-000000000001');
    raise exception 'A student wrote notifications for someone else';
  exception when insufficient_privilege then null;
  end;
end;
$$;

set local request.jwt.claim.sub = 'a1000000-0000-4000-8000-000000000001';
select public.refresh_my_notifications();
reset role;

do $$
declare
  mine text[];
begin
  if exists (select 1 from public.notifications
    where type = 'event_deadline_soon' and user_id <> 'a1000000-0000-4000-8000-000000000001') then
    raise exception 'Refreshing wrote notifications for other students';
  end if;
  select array_agg(body order by body) into mine from public.notifications
  where user_id = 'a1000000-0000-4000-8000-000000000001' and type = 'event_deadline_soon';
  if mine is distinct from array[
    'RSVP deadline for Blitz Night hosted by Chess Club ends soon.',
    'RSVP deadline for Formal ends soon — 4 of your McGillians RSVPed!',
    'RSVP deadline for Study Hall ends soon — 1 of your McGillians RSVPed!'
  ] then
    raise exception 'Wrong deadline notifications: %', mine;
  end if;
  if (select friend_rsvp_count from public.notifications
      where event_id = 'c1000000-0000-4000-8000-000000000003' and type = 'event_deadline_soon') <> 4 then
    raise exception 'Wrong stored count';
  end if;
end;
$$;

-- The scheduled run covers everyone else and repeats nothing. EUS is followed
-- by Sam (going to Formal already) and by Hana.
set local role service_role;
do $$
begin
  perform public.generate_ending_soon_notifications();
  if public.generate_ending_soon_notifications() <> 0 then
    raise exception 'A second run wrote duplicates';
  end if;
end;
$$;
reset role;
do $$
declare
  sams text[];
begin
  select array_agg(e.title order by e.title) into sams
  from public.notifications n join public.events e on e.id = n.event_id
  where n.user_id = 'a1000000-0000-4000-8000-000000000007' and n.type = 'event_deadline_soon';
  if sams is distinct from array['Already Going', 'Study Hall'] then
    raise exception 'Wrong reminders for another follower: %', sams;
  end if;
end;
$$;

-- A scheduled publication is announced once it becomes visible.
do $$
begin
  if exists (select 1 from public.notifications where event_id = 'c1000000-0000-4000-8000-000000000007') then
    raise exception 'An unpublished event was announced';
  end if;
  update public.events set created_at = now() - interval '1 day', published_at = now() - interval '1 minute'
    where id = 'c1000000-0000-4000-8000-000000000007';
  perform public.generate_ending_soon_notifications();
  if (select count(*) from public.notifications
      where event_id = 'c1000000-0000-4000-8000-000000000007' and type = 'new_followed_event') <> 3 then
    raise exception 'A scheduled event was not announced to its three followers';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claim.sub = 'a1000000-0000-4000-8000-000000000007';
do $$
begin
  if exists (select 1 from public.notifications
    where user_id <> 'a1000000-0000-4000-8000-000000000007') then
    raise exception 'Another student''s notifications are readable';
  end if;
  update public.notifications set is_read = true
    where user_id = 'a1000000-0000-4000-8000-000000000001';
  if found then raise exception 'Another student''s notifications can be changed'; end if;

  update public.notifications set is_read = true;
  if not found then raise exception 'Notifications can''t be marked read'; end if;

  begin
    update public.notifications set is_read = false;
    raise exception 'A notification was marked unread';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.notifications set body = 'Changed';
    raise exception 'A notification''s text was changed';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.notifications (user_id, type, event_id, group_id, title, body) values
      ('a1000000-0000-4000-8000-000000000001', 'new_followed_event',
        'c1000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000003', 'Fake', 'Fake');
    raise exception 'A student wrote a notification';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.notifications;
    raise exception 'A student deleted notifications';
  exception when insufficient_privilege then null;
  end;
end;
$$;

set local role anon;
do $$
begin
  begin
    perform 1 from public.notifications;
    raise exception 'Signed-out visitors can read notifications';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.friend_rsvps();
    raise exception 'Signed-out visitors can read friend RSVPs';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.refresh_my_notifications();
    raise exception 'Signed-out visitors can write notifications';
  exception when insufficient_privilege then null;
  end;
end;
$$;

rollback;
