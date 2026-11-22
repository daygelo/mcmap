-- Friend RSVP counts, RSVP deadlines and in-app notifications.
-- Run after 20261122100200. Safe to run more than once.

-- ---------------------------------------------------------------------------
-- RSVP deadlines
-- ---------------------------------------------------------------------------

-- Null means RSVPs close when the event starts.
alter table public.events add column if not exists rsvp_deadline timestamptz;

alter table public.events drop constraint if exists rsvp_deadline_before_start;
alter table public.events add constraint rsvp_deadline_before_start
  check (rsvp_deadline is null or starts_at is null or rsvp_deadline <= starts_at);

create index if not exists events_rsvp_closes_idx
  on public.events ((coalesce(rsvp_deadline, starts_at)));

drop policy if exists "users rsvp for themselves" on public.event_rsvps;
create policy "users rsvp for themselves"
  on public.event_rsvps for insert
  to authenticated
  with check (
    profile_id = (select auth.uid())
    and exists (
      select 1 from public.events e
      where e.id = event_id
        and not e.cancelled
        and e.published_at <= now()
        and (
          coalesce(e.rsvp_deadline, e.starts_at) is null
          or coalesce(e.rsvp_deadline, e.starts_at) > now()
        )
    )
  );

-- ---------------------------------------------------------------------------
-- Friend RSVPs
-- ---------------------------------------------------------------------------

-- How many of the caller's McGillians are going to each event, with up to
-- three of them for avatars. Events nobody they follow is going to are left
-- out. Runs as the caller, so RLS on event_rsvps keeps private RSVPs private.
-- Null event_ids means every event that hasn't started.
create or replace function public.friend_rsvps(event_ids uuid[] default null)
returns table (event_id uuid, friend_rsvp_count int, friend_rsvps jsonb)
language sql
stable
security invoker
set search_path = ''
as $$
  with going as (
    select
      r.event_id,
      p.full_name,
      p.avatar_url,
      row_number() over (
        partition by r.event_id
        -- People with a photo first: these become the avatars.
        order by (p.avatar_url is null), r.created_at, p.id
      ) as position
    from public.mcgillians m
    join public.event_rsvps r on r.profile_id = m.following_id
    join public.profiles p on p.id = r.profile_id
    join public.events e on e.id = r.event_id
    where m.follower_id = (select auth.uid())
      and m.status = 'following'
      and r.visibility in ('friends', 'public')
      and case
        when event_ids is null
          then not e.cancelled and (e.starts_at is null or e.starts_at > now())
        else r.event_id = any (event_ids)
      end
  )
  select
    g.event_id,
    count(*)::int,
    jsonb_agg(
      jsonb_build_object('full_name', g.full_name, 'avatar_url', g.avatar_url)
      order by g.position
    ) filter (where g.position <= 3)
  from going g
  group by g.event_id;
$$;

revoke all on function public.friend_rsvps(uuid[]) from public, anon, authenticated;
grant execute on function public.friend_rsvps(uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- notifications
-- ---------------------------------------------------------------------------

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  type text not null check (type in ('new_followed_event', 'event_deadline_soon')),
  event_id uuid not null references public.events (id) on delete cascade,
  group_id uuid not null references public.groups (id) on delete cascade,
  title text not null,
  body text not null,
  friend_rsvp_count int not null default 0 check (friend_rsvp_count >= 0),
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  constraint notifications_once_per_event unique (user_id, type, event_id)
);

create index if not exists notifications_inbox_idx
  on public.notifications (user_id, created_at desc);
create index if not exists notifications_event_idx
  on public.notifications (event_id);
create index if not exists notifications_group_idx
  on public.notifications (group_id);

alter table public.notifications enable row level security;

-- Students read their own and mark them read; only the functions below write
-- new ones.
revoke all on public.notifications from public, anon, authenticated;
grant select on public.notifications to authenticated;
grant update (is_read) on public.notifications to authenticated;

drop policy if exists "users read their own notifications" on public.notifications;
create policy "users read their own notifications"
  on public.notifications for select
  to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "users mark their own notifications read" on public.notifications;
create policy "users mark their own notifications read"
  on public.notifications for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and is_read);

-- Finding a group's followers: follows ? 'group-slug'.
create index if not exists profile_organization_follows_idx
  on public.profile_organization_follows using gin (follows);

-- ---------------------------------------------------------------------------
-- New event from a followed group
-- ---------------------------------------------------------------------------

create or replace function public.notify_new_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Scheduled publications are announced by write_notifications once visible.
  if new.cancelled
    or new.published_at > now()
    or coalesce(new.rsvp_deadline, new.starts_at) <= now()
  then
    return null;
  end if;

  insert into public.notifications (user_id, type, event_id, group_id, title, body)
  select
    f.profile_id, 'new_followed_event', new.id, g.id,
    'New Event from ' || coalesce(nullif(g.short_name, ''), g.name),
    coalesce(nullif(g.short_name, ''), g.name) || ' just posted: ' || new.title
  from public.groups g
  join public.profile_organization_follows f on f.follows ? g.slug
  where g.id = new.group_id
    and f.profile_id is distinct from new.created_by
  on conflict (user_id, type, event_id) do nothing;
  return null;
exception when others then
  -- Publishing an event must not fail because an announcement did.
  raise warning 'notify_new_event %: %', new.id, sqlerrm;
  return null;
end;
$$;

revoke all on function public.notify_new_event() from public, anon, authenticated;

drop trigger if exists events_notify_followers on public.events;
create trigger events_notify_followers
  after insert on public.events
  for each row execute function public.notify_new_event();

-- ---------------------------------------------------------------------------
-- Deadlines ending soon
-- ---------------------------------------------------------------------------

-- Writes whatever notifications are due, for one student or (null) everyone.
-- Internal: reached through the two functions below.
create or replace function public.write_notifications(only_user uuid)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  announced int;
  reminded int;
begin
  -- Scheduled publications that became visible in the last day.
  insert into public.notifications (user_id, type, event_id, group_id, title, body)
  select
    f.profile_id, 'new_followed_event', e.id, g.id,
    'New Event from ' || coalesce(nullif(g.short_name, ''), g.name),
    coalesce(nullif(g.short_name, ''), g.name) || ' just posted: ' || e.title
  from public.events e
  join public.groups g on g.id = e.group_id
  join public.profile_organization_follows f on f.follows ? g.slug
  where e.published_at > e.created_at
    and e.published_at <= now()
    and e.published_at > now() - interval '24 hours'
    and not e.cancelled
    and (
      coalesce(e.rsvp_deadline, e.starts_at) is null
      or coalesce(e.rsvp_deadline, e.starts_at) > now()
    )
    and (only_user is null or f.profile_id = only_user)
    and f.profile_id is distinct from e.created_by
  on conflict (user_id, type, event_id) do nothing;
  get diagnostics announced = row_count;

  -- Followers who haven't RSVPed to something closing within a day.
  insert into public.notifications (
    user_id, type, event_id, group_id, title, body, friend_rsvp_count
  )
  select
    f.profile_id, 'event_deadline_soon', e.id, g.id,
    'RSVP ending soon',
    case
      when friends.going > 0 then format(
        'RSVP deadline for %s ends soon — %s of your McGillians RSVPed!',
        e.title, friends.going
      )
      else format(
        'RSVP deadline for %s hosted by %s ends soon.',
        e.title, coalesce(nullif(g.short_name, ''), g.name)
      )
    end,
    friends.going
  from public.events e
  join public.groups g on g.id = e.group_id
  join public.profile_organization_follows f on f.follows ? g.slug
  -- Same rule as RLS: a private RSVP never reaches someone else's count.
  cross join lateral (
    select count(*)::int as going
    from public.mcgillians m
    join public.event_rsvps r on r.profile_id = m.following_id
    where m.follower_id = f.profile_id
      and m.status = 'following'
      and r.event_id = e.id
      and r.visibility in ('friends', 'public')
  ) friends
  where coalesce(e.rsvp_deadline, e.starts_at) > now()
    and coalesce(e.rsvp_deadline, e.starts_at) <= now() + interval '24 hours'
    and e.published_at <= now()
    and not e.cancelled
    and (only_user is null or f.profile_id = only_user)
    and not exists (
      select 1 from public.event_rsvps mine
      where mine.event_id = e.id and mine.profile_id = f.profile_id
    )
  on conflict (user_id, type, event_id) do nothing;
  get diagnostics reminded = row_count;

  return announced + reminded;
end;
$$;

revoke all on function public.write_notifications(uuid)
  from public, anon, authenticated;

-- For pg_cron or an Edge Function. Returns how many were written.
create or replace function public.generate_ending_soon_notifications()
returns int
language sql
security definer
set search_path = ''
as $$
  select public.write_notifications(null);
$$;

revoke all on function public.generate_ending_soon_notifications()
  from public, anon, authenticated;
grant execute on function public.generate_ending_soon_notifications() to service_role;

-- For the app on load, so reminders still arrive without pg_cron. Covers the
-- caller only.
create or replace function public.refresh_my_notifications()
returns int
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;
  return public.write_notifications(auth.uid());
end;
$$;

revoke all on function public.refresh_my_notifications() from public, anon, authenticated;
grant execute on function public.refresh_my_notifications() to authenticated;

-- ---------------------------------------------------------------------------
-- Realtime and scheduling
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
    and not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public' and tablename = 'notifications'
    )
  then
    alter publication supabase_realtime add table public.notifications;
  end if;
end;
$$;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule(
      'ending-soon-notifications',
      '*/15 * * * *',
      'select public.generate_ending_soon_notifications()'
    );
  else
    raise notice 'pg_cron is unavailable; reminders are written when students open the app.';
  end if;
exception when others then
  raise warning 'Reminders were not scheduled (%). Students still get them when they open the app.', sqlerrm;
end;
$$;

-- The API serves the new column, table and functions right away.
notify pgrst, 'reload schema';
