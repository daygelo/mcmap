-- Profile discoverability and RSVP privacy are independent.
alter table public.profiles
  add column rsvp_visibility public.rsvp_visibility not null default 'private';
alter table public.profiles alter column is_private set default false;

-- The old client stored only per-event choices. Start from a conservative
-- account-wide preference without deleting any RSVPs or changing timestamps.
update public.event_rsvps set visibility = 'private' where visibility <> 'private';

-- Clients can still edit other profile fields. Only the privacy RPC can
-- change this preference, so it cannot drift from the existing RSVPs.
revoke update on public.profiles from public, anon, authenticated;
do $$
declare
  editable_columns text;
begin
  select string_agg(quote_ident(column_name), ', ') into editable_columns
  from information_schema.columns
  where table_schema = 'public' and table_name = 'profiles'
    and column_name <> 'rsvp_visibility';
  execute format('grant update (%s) on public.profiles to authenticated', editable_columns);
end;
$$;

create function public.set_my_rsvp_visibility(preference public.rsvp_visibility)
returns public.rsvp_visibility
language plpgsql
security definer
set search_path = ''
as $$
declare
  viewer uuid := auth.uid();
begin
  if viewer is null or preference is null then
    raise exception 'Sign in and choose an RSVP visibility' using errcode = '42501';
  end if;
  update public.profiles set rsvp_visibility = preference where id = viewer;
  if not found then
    raise exception 'Account profile is unavailable' using errcode = '42501';
  end if;
  update public.event_rsvps
  set visibility = preference
  where profile_id = viewer and visibility <> preference;
  return preference;
end;
$$;

revoke all on function public.set_my_rsvp_visibility(public.rsvp_visibility)
  from public, anon, authenticated;
grant execute on function public.set_my_rsvp_visibility(public.rsvp_visibility)
  to authenticated;

create function public.apply_account_rsvp_visibility()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null and auth.uid() <> new.profile_id then
    raise exception 'Only your own RSVP can be created' using errcode = '42501';
  end if;
  -- Serialize insertion with updates to this account's privacy preference.
  select p.rsvp_visibility into strict new.visibility
  from public.profiles p where p.id = new.profile_id for share;
  return new;
end;
$$;

revoke all on function public.apply_account_rsvp_visibility()
  from public, anon, authenticated;

create trigger rsvps_apply_account_visibility
  before insert on public.event_rsvps
  for each row execute function public.apply_account_rsvp_visibility();

drop policy "users change their own rsvp" on public.event_rsvps;
revoke update on public.event_rsvps from public, anon, authenticated;

-- The recipient can accept a request. Neither endpoint can be changed in
-- place to manufacture a relationship with a different account.
revoke update on public.mcgillians from public, anon, authenticated;
grant update (status) on public.mcgillians to authenticated;

create function public.is_mutual_mcgillian(other_profile uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1 from public.mcgillians outgoing
    join public.mcgillians incoming
      on incoming.follower_id = outgoing.following_id
      and incoming.following_id = outgoing.follower_id
    where outgoing.follower_id = (select auth.uid())
      and outgoing.following_id = other_profile
      and outgoing.status = 'following'
      and incoming.status = 'following'
  );
$$;

revoke all on function public.is_mutual_mcgillian(uuid) from public, anon, authenticated;
grant execute on function public.is_mutual_mcgillian(uuid) to authenticated;

drop policy "rsvps follow their visibility" on public.event_rsvps;
create policy "rsvps follow their visibility"
  on public.event_rsvps for select to authenticated
  using (
    profile_id = (select auth.uid())
    or (
      (visibility = 'public' or (
        visibility = 'friends' and public.is_mutual_mcgillian(profile_id)
      ))
      and exists (select 1 from public.events e where e.id = event_id)
    )
  );

-- Keep the existing RPC shape. Its statistics now run under the viewer's RLS.
create or replace function public.search_mcgillians(q text, max_results int default 20)
returns table (
  id uuid,
  full_name text,
  handle text,
  avatar_url text,
  bio text,
  faculty text,
  major text,
  degree_level public.degree_level,
  u_year public.u_year,
  is_first_year_u1 boolean,
  is_private boolean,
  mcgillians_count bigint,
  events_count bigint,
  clubs_count bigint
)
language sql
stable
security invoker
set search_path = ''
as $$
  with term as (
    select '%' || lower(trim(leading '@' from trim(coalesce(q, '')))) || '%' as pattern
  )
  select
    p.id, p.full_name, p.handle, p.avatar_url, p.bio, p.faculty, p.major,
    p.degree_level, p.u_year, p.is_first_year_u1, p.is_private,
    (select count(*) from public.mcgillians m
      where m.follower_id = p.id and m.status = 'following'),
    (select count(*) from public.event_rsvps r
      join public.events e on e.id = r.event_id
      where r.profile_id = p.id),
    (select count(distinct e.group_id) from public.event_rsvps r
      join public.events e on e.id = r.event_id
      where r.profile_id = p.id)
  from public.profiles p, term
  where (select auth.uid()) is not null
    and p.id <> (select auth.uid())
    and p.onboarding_completed
    and (
      lower(p.full_name) like term.pattern
      or p.handle like term.pattern
      or lower(coalesce(p.faculty, '')) like term.pattern
      or lower(coalesce(p.major, '')) like term.pattern
    )
  order by p.full_name
  limit least(greatest(max_results, 1), 50);
$$;

-- The inbox view also uses this RPC, so reminder counts follow this rule.
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
      p.id as profile_id,
      p.full_name,
      p.avatar_url,
      row_number() over (
        partition by r.event_id
        -- People with a photo first: these become the avatars.
        order by (p.avatar_url is null), r.created_at, p.id
      ) as position
    from public.event_rsvps r
    join public.profiles p on p.id = r.profile_id
    join public.events e on e.id = r.event_id
    where public.is_mutual_mcgillian(r.profile_id)
      and p.onboarding_completed
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
      jsonb_build_object(
        'profile_id', g.profile_id, 'full_name', g.full_name, 'avatar_url', g.avatar_url
      )
      order by g.position
    ) filter (where g.position <= 3)
  from going g
  group by g.event_id;
$$;


-- Follow preferences are user-editable JSON. A malformed timestamp must not
-- prevent other people's notifications or create consent.
create function public.parse_organization_consent(value text)
returns timestamptz
language plpgsql
stable
strict
set search_path = ''
as $$
begin
  return value::timestamptz;
exception when invalid_datetime_format or datetime_field_overflow then
  return null;
end;
$$;

revoke all on function public.parse_organization_consent(text)
  from public, anon, authenticated;

-- Record automatic attempts and cancellations so a refresh never re-RSVPs
-- someone who cancelled. Only the functions below can access the ledger.
create table public.auto_rsvp_decisions (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  primary key (profile_id, event_id)
);
alter table public.auto_rsvp_decisions enable row level security;
revoke all on public.auto_rsvp_decisions from public, anon, authenticated;

create function public.remember_rsvp_cancellation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Skip cascades where the parent event or profile has been removed.
  insert into public.auto_rsvp_decisions (profile_id, event_id)
  select p.id, e.id
  from public.profiles p, public.events e
  where p.id = old.profile_id and e.id = old.event_id
  on conflict do nothing;
  return old;
end;
$$;
revoke all on function public.remember_rsvp_cancellation()
  from public, anon, authenticated;

create trigger rsvps_remember_cancellation
  after delete on public.event_rsvps
  for each row execute function public.remember_rsvp_cancellation();

create function public.refresh_my_auto_rsvps()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  viewer uuid := auth.uid();
begin
  if viewer is null then
    raise exception 'Sign in to refresh RSVPs' using errcode = '42501';
  end if;

  perform 1 from public.profiles where id = viewer for update;
  if not found then return; end if;

  -- Lock the consent row so a concurrent unfollow or opt-out cannot race the
  -- eligibility check. The insert trigger supplies the account's visibility.
  perform 1 from public.profile_organization_follows
    where profile_id = viewer for share;

  with eligible as (
    insert into public.auto_rsvp_decisions (profile_id, event_id)
    select viewer, e.id
    from public.profile_organization_follows f
    join public.groups g on f.follows ? g.slug
    join public.events e on e.group_id = g.id
    where f.profile_id = viewer
      and e.published_at <= now()
      and e.published_at > public.parse_organization_consent(f.follows->g.slug->>'auto_rsvp_enabled_at')
      and e.starts_at > now()
      and coalesce(e.rsvp_deadline, e.starts_at) > now()
      and not e.cancelled
      and e.supports_unrestricted_rsvp
      and not exists (
        select 1 from public.event_rsvps r
        where r.profile_id = viewer and r.event_id = e.id
      )
    on conflict do nothing
    returning profile_id, event_id
  )
  insert into public.event_rsvps (profile_id, event_id)
  select profile_id, event_id from eligible
  on conflict do nothing;
end;
$$;

revoke all on function public.refresh_my_auto_rsvps() from public, anon, authenticated;
grant execute on function public.refresh_my_auto_rsvps() to authenticated;

-- Following an organization and consenting to its event updates are separate.
create function public.set_organization_event_notifications(group_slug text, enabled boolean)
returns timestamptz
language plpgsql
security invoker
set search_path = ''
as $$
declare
  consent_at timestamptz;
begin
  update public.profile_organization_follows as owned
  set follows = jsonb_set(
    owned.follows,
    array[group_slug],
    case when enabled then (owned.follows->group_slug) || jsonb_build_object(
      'event_notifications_enabled_at',
      coalesce(owned.follows->group_slug->'event_notifications_enabled_at', to_jsonb(statement_timestamp()))
    ) else (owned.follows->group_slug) - 'event_notifications_enabled_at' end,
    false
  )
  where owned.profile_id = (select auth.uid()) and owned.follows ? group_slug
  returning (owned.follows->group_slug->>'event_notifications_enabled_at')::timestamptz into consent_at;

  if not found then
    raise exception 'Follow the organization before changing event notifications'
      using errcode = '42501';
  end if;

  return consent_at;
end;
$$;

revoke all on function public.set_organization_event_notifications(text, boolean) from public, anon, authenticated;
grant execute on function public.set_organization_event_notifications(text, boolean) to authenticated;

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
    and new.published_at > public.parse_organization_consent(f.follows->g.slug->>'event_notifications_enabled_at')
    and f.profile_id is distinct from new.created_by
  on conflict (user_id, type, event_id) do nothing;
  return null;
exception when others then
  -- Publishing an event must not fail because an announcement did.
  raise warning 'notify_new_event %: %', new.id, sqlerrm;
  return null;
end;
$$;


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
    and e.published_at > public.parse_organization_consent(f.follows->g.slug->>'event_notifications_enabled_at')
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
  insert into public.notifications (user_id, type, event_id, group_id, title, body)
  select
    f.profile_id, 'event_deadline_soon', e.id, g.id,
    'RSVP ending soon',
    format(
      'RSVP deadline for %s hosted by %s ends soon.',
      e.title, coalesce(nullif(g.short_name, ''), g.name)
    )
  from public.events e
  join public.groups g on g.id = e.group_id
  join public.profile_organization_follows f on f.follows ? g.slug
  where coalesce(e.rsvp_deadline, e.starts_at) > now()
    and coalesce(e.rsvp_deadline, e.starts_at) <= now() + interval '24 hours'
    and e.published_at <= now()
    and e.published_at > public.parse_organization_consent(f.follows->g.slug->>'event_notifications_enabled_at')
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


notify pgrst, 'reload schema';
