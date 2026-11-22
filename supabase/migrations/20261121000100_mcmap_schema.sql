-- McMap core schema: profiles, McGillians (connections), groups, events,
-- RSVPs, Row Level Security and storage buckets.
--
-- Apply after 20261121000000_create_account_lookup.sql, either with
-- `supabase db push` or by pasting into the Supabase SQL editor.

create extension if not exists pg_trgm with schema extensions;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

create type public.degree_level as enum (
  'undergraduate',
  'masters',
  'doctorate',
  'professional',
  'exchange_continuing'
);

create type public.u_year as enum ('U0', 'U1', 'U2', 'U3', 'U4_plus');

create type public.group_type as enum (
  'club',
  'student_association',
  'faculty',
  'society',
  'faculty_affiliation',
  'design_team',
  'first_year_council',
  'first_year_committee',
  'first_year_society'
);

-- following = a confirmed McGillian; requested = waiting on a private profile.
create type public.connection_status as enum ('following', 'requested');

create type public.rsvp_visibility as enum ('private', 'friends', 'public');

-- ---------------------------------------------------------------------------
-- Shared trigger: keep updated_at fresh
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- profiles: public, non-auth user data (1:1 with auth.users)
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  handle text not null unique
    check (handle ~ '^[a-z0-9._]{3,30}$'),
  avatar_url text,
  bio text not null default '' check (char_length(bio) <= 250),

  -- Onboarding step 2 (academic profile)
  degree_level public.degree_level,
  u_year public.u_year,
  is_first_year_u1 boolean not null default false,
  faculty text,
  major text check (char_length(major) <= 100),

  -- Froshie = U0, or U1 in their first year at McGill (CEGEP / AP / IB).
  is_froshie boolean generated always as (
    u_year = 'U0' or (u_year = 'U1' and is_first_year_u1)
  ) stored,

  -- Onboarding step 3. Empty when skipped.
  interests text[] not null default '{}',

  is_private boolean not null default false,
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- U-years only make sense for undergrads.
  constraint u_year_only_for_undergrads check (
    u_year is null or degree_level = 'undergraduate'
  ),
  -- The first-year question is only asked of U1s.
  constraint first_year_only_for_u1 check (
    not is_first_year_u1 or u_year = 'U1'
  ),
  -- Finished onboarding means step 2 was answered.
  constraint onboarding_has_academics check (
    not onboarding_completed or (
      degree_level is not null
      and faculty is not null
      and (degree_level <> 'undergraduate' or u_year is not null)
      and (degree_level = 'exchange_continuing' or major is not null)
    )
  )
);

create index profiles_full_name_trgm
  on public.profiles using gin (full_name extensions.gin_trgm_ops);
create index profiles_handle_trgm
  on public.profiles using gin (handle extensions.gin_trgm_ops);

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Handle from the email (angela.morin@mail.mcgill.ca → angela.morin), with a
-- numeric suffix if it's taken.
create or replace function public.unique_handle(email text)
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  base text;
  candidate text;
  n int := 0;
begin
  base := regexp_replace(lower(split_part(email, '@', 1)), '[^a-z0-9._]', '', 'g');
  if char_length(base) < 3 then
    base := 'mcgillian';
  end if;
  base := left(base, 26);
  candidate := base;
  while exists (select 1 from public.profiles p where p.handle = candidate) loop
    n := n + 1;
    candidate := base || n::text;
  end loop;
  return candidate;
end;
$$;

-- Create the profile row as soon as someone signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, handle)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), ''),
    public.unique_handle(new.email)
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;

-- Any signed-in student can find other students (the McGillians search).
create policy "profiles are visible to signed-in users"
  on public.profiles for select
  to authenticated
  using (true);

create policy "users update their own profile"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- ---------------------------------------------------------------------------
-- mcgillians: connections between students
-- ---------------------------------------------------------------------------

create table public.mcgillians (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  following_id uuid not null references public.profiles (id) on delete cascade,
  status public.connection_status not null default 'following',
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint no_self_follow check (follower_id <> following_id)
);

create index mcgillians_following_idx on public.mcgillians (following_id, status);

-- The server decides the status: private profiles get a request,
-- public ones are followed right away.
create or replace function public.set_connection_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.status := case
      when (select is_private from public.profiles where id = new.following_id)
        then 'requested'::public.connection_status
      else 'following'::public.connection_status
    end;
  end if;
  return new;
end;
$$;

create trigger mcgillians_set_status
  before insert on public.mcgillians
  for each row execute function public.set_connection_status();

alter table public.mcgillians enable row level security;

-- Confirmed connections are visible (for counts and lists); pending
-- requests only to the two people involved.
create policy "connections are visible"
  on public.mcgillians for select
  to authenticated
  using (
    status = 'following'
    or (select auth.uid()) in (follower_id, following_id)
  );

create policy "users add their own connections"
  on public.mcgillians for insert
  to authenticated
  with check ((select auth.uid()) = follower_id);

-- Only the person who received a request can accept it.
create policy "users accept requests sent to them"
  on public.mcgillians for update
  to authenticated
  using ((select auth.uid()) = following_id)
  with check ((select auth.uid()) = following_id and status = 'following');

-- Either side can remove a connection or cancel/decline a request.
create policy "users remove their own connections"
  on public.mcgillians for delete
  to authenticated
  using ((select auth.uid()) in (follower_id, following_id));

-- ---------------------------------------------------------------------------
-- groups: clubs, student associations, faculties, societies
-- ---------------------------------------------------------------------------

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  -- Matches the app's club catalog ids, e.g. 'ssmu-mcgill-e-sports-students-society'.
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  name text not null,
  type public.group_type not null default 'club',
  category text,
  avatar_url text,
  description text,
  website_url text,
  -- True until the Faculty/Club page has real content.
  is_placeholder boolean not null default true,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index groups_name_trgm
  on public.groups using gin (name extensions.gin_trgm_ops);

create trigger groups_updated_at
  before update on public.groups
  for each row execute function public.set_updated_at();

alter table public.groups enable row level security;

create policy "groups are public"
  on public.groups for select
  to anon, authenticated
  using (true);
-- No client writes: groups are managed from the dashboard / service role
-- until organizer accounts exist.

-- ---------------------------------------------------------------------------
-- events
-- ---------------------------------------------------------------------------

create table public.events (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  title text not null,
  ai_synopsis text check (char_length(ai_synopsis) <= 400),
  full_description text,
  starts_at timestamptz,
  ends_at timestamptz,
  -- Free-text fallback when starts_at isn't confirmed ("Fridays · 5 PM").
  schedule_label text,
  location_name text not null default '',
  latitude numeric(9, 6) check (latitude between -90 and 90),
  longitude numeric(9, 6) check (longitude between -180 and 180),
  tags text[] not null default '{}',
  is_froshie_event boolean not null default false,
  cancelled boolean not null default false,
  -- In-app RSVP with no external ticket/approval/capacity step.
  supports_unrestricted_rsvp boolean not null default true,
  published_at timestamptz not null default now(),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ends_after_start check (ends_at is null or ends_at >= starts_at)
);

create index events_group_idx on public.events (group_id);
create index events_starts_at_idx on public.events (starts_at);
create index events_tags_idx on public.events using gin (tags);
create index events_title_trgm
  on public.events using gin (title extensions.gin_trgm_ops);

create trigger events_updated_at
  before update on public.events
  for each row execute function public.set_updated_at();

alter table public.events enable row level security;

-- Scheduled publications stay hidden until published_at.
create policy "published events are visible"
  on public.events for select
  to authenticated
  using (published_at <= now());
-- No client writes yet (organizer tooling is future work).

-- ---------------------------------------------------------------------------
-- event_rsvps
-- ---------------------------------------------------------------------------

create table public.event_rsvps (
  event_id uuid not null references public.events (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  visibility public.rsvp_visibility not null default 'private',
  created_at timestamptz not null default now(),
  primary key (event_id, profile_id)
);

create index event_rsvps_profile_idx on public.event_rsvps (profile_id);

alter table public.event_rsvps enable row level security;

-- You see your own RSVPs, public ones, and "friends" ones from people
-- you're connected to.
create policy "rsvps follow their visibility"
  on public.event_rsvps for select
  to authenticated
  using (
    profile_id = (select auth.uid())
    or visibility = 'public'
    or (
      visibility = 'friends'
      and exists (
        select 1 from public.mcgillians m
        where m.follower_id = (select auth.uid())
          and m.following_id = event_rsvps.profile_id
          and m.status = 'following'
      )
    )
  );

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
        and (e.starts_at is null or e.starts_at > now())
    )
  );

create policy "users change their own rsvp"
  on public.event_rsvps for update
  to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

create policy "users cancel their own rsvp"
  on public.event_rsvps for delete
  to authenticated
  using (profile_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- McGillians search with stats (one round trip for the search results)
-- ---------------------------------------------------------------------------

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
security definer
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
    (select count(*) from public.event_rsvps r where r.profile_id = p.id),
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

revoke all on function public.search_mcgillians(text, int) from public;
grant execute on function public.search_mcgillians(text, int) to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: avatars (user photos) and group-images (club/event art)
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880,
    array['image/jpeg', 'image/png', 'image/webp']),
  ('group-images', 'group-images', true, 5242880,
    array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- Avatars live at avatars/<user id>/<file>. Anyone can view (public bucket);
-- only the owner can write inside their own folder.
create policy "users upload their own avatar"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "users replace their own avatar"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "users delete their own avatar"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
-- group-images: read-only for clients; upload from the dashboard.

-- ---------------------------------------------------------------------------
-- Backfill: accounts created before this migration get a profile row too.
-- ---------------------------------------------------------------------------

do $$
declare
  u record;
begin
  for u in
    select au.id, au.email, au.raw_user_meta_data
    from auth.users au
    where not exists (select 1 from public.profiles p where p.id = au.id)
  loop
    insert into public.profiles (id, full_name, handle)
    values (
      u.id,
      coalesce(nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''), ''),
      public.unique_handle(u.email)
    );
  end loop;
end;
$$;
