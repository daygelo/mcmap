-- Club follows and memberships, plus automatic follows: when a student
-- finishes onboarding they follow their campus society (SSMU, MCSS, MACES or
-- PGSS), their faculty association (AUS, SUS, EUS, MUS, ...) and, for
-- Froshies, their First-Year Council. Campus society and faculty
-- association also add a private membership.
--
-- Run after 20261122000000_group_types.sql, then (re)run supabase/seed.sql:
-- it loads the groups and the auto_follow_rules this trigger reads.

-- ---------------------------------------------------------------------------
-- groups: short names, and clean-up of the first seed's duplicate groups
-- ---------------------------------------------------------------------------

alter table public.groups add column if not exists short_name text;

-- The first seed added 'ssmu', 'aus', ... next to the catalog's own ids
-- ('mcgill-ssmu', ...). Move their events to the catalog group and drop the
-- duplicate, or just rename it if the catalog group isn't loaded yet.
do $$
declare
  pair record;
  old_id uuid;
  new_id uuid;
begin
  for pair in
    select * from (values
      ('ssmu', 'mcgill-ssmu'),
      ('pgss', 'mcgill-pgss'),
      ('aus', 'mcgill-aus'),
      ('sus', 'mcgill-sus'),
      ('eus', 'engineering-engineering-undergraduate-society-eus'),
      ('mus', 'desautels-mus')
    ) as t(old_slug, new_slug)
  loop
    select id into old_id from public.groups where slug = pair.old_slug;
    continue when old_id is null;
    select id into new_id from public.groups where slug = pair.new_slug;
    if new_id is null then
      update public.groups set slug = pair.new_slug where id = old_id;
    else
      update public.events set group_id = new_id where group_id = old_id;
      delete from public.groups where id = old_id;
    end if;
  end loop;
end;
$$;

update public.groups set type = 'campus_society'
where slug in ('mcgill-ssmu', 'mcgill-mcss', 'mcgill-maces', 'mcgill-pgss');

update public.groups set type = 'faculty_association'
where slug in (
  'mcgill-aus', 'mcgill-sus', 'engineering-engineering-undergraduate-society-eus',
  'desautels-mus', 'mcgill-edus', 'mcgill-lsa', 'mcgill-musa'
);

-- ---------------------------------------------------------------------------
-- group_follows: clubs a student follows (their feed's "Following" filter)
-- ---------------------------------------------------------------------------

create table public.group_follows (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  group_id uuid not null references public.groups (id) on delete cascade,
  -- In-app notifications for new events; the time stops older events from
  -- notifying.
  notifications_enabled_at timestamptz,
  -- 'auto' = added by onboarding rules; the student can still unfollow.
  source text not null default 'manual' check (source in ('manual', 'auto')),
  created_at timestamptz not null default now(),
  primary key (profile_id, group_id)
);

create index group_follows_group_idx on public.group_follows (group_id);

alter table public.group_follows enable row level security;

-- Following is private to its owner.
create policy "users see their own follows"
  on public.group_follows for select
  to authenticated
  using (profile_id = (select auth.uid()));

create policy "users follow for themselves"
  on public.group_follows for insert
  to authenticated
  with check (profile_id = (select auth.uid()));

create policy "users update their own follows"
  on public.group_follows for update
  to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

create policy "users unfollow for themselves"
  on public.group_follows for delete
  to authenticated
  using (profile_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- group_memberships: self-reported memberships ("Your Clubs")
-- ---------------------------------------------------------------------------

create table public.group_memberships (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  group_id uuid not null references public.groups (id) on delete cascade,
  show_on_profile boolean not null default false,
  -- Auto-RSVP to this group's new events; the time stops older events
  -- from being RSVPed.
  auto_rsvp_enabled_at timestamptz,
  source text not null default 'manual' check (source in ('manual', 'auto')),
  created_at timestamptz not null default now(),
  primary key (profile_id, group_id)
);

create index group_memberships_group_idx on public.group_memberships (group_id);

alter table public.group_memberships enable row level security;

-- Your own memberships, plus anyone's that they chose to show on profile.
create policy "memberships follow show_on_profile"
  on public.group_memberships for select
  to authenticated
  using (profile_id = (select auth.uid()) or show_on_profile);

create policy "users add their own memberships"
  on public.group_memberships for insert
  to authenticated
  with check (profile_id = (select auth.uid()));

create policy "users update their own memberships"
  on public.group_memberships for update
  to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

create policy "users remove their own memberships"
  on public.group_memberships for delete
  to authenticated
  using (profile_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- auto_follow_rules: which groups each student follows automatically.
-- Loaded by seed.sql from lib/data/auto_follow.dart (the app uses the same
-- rules in the offline demo).
-- ---------------------------------------------------------------------------

create table public.auto_follow_rules (
  group_slug text primary key
    references public.groups (slug) on update cascade on delete cascade,
  -- Null = any faculty / any degree level.
  faculties text[],
  degree_levels public.degree_level[],
  -- First-Year Councils: only Froshies (U0, or U1 in their first year).
  froshie_only boolean not null default false,
  -- Also add a private membership (campus society, faculty association).
  enroll boolean not null default false
);

alter table public.auto_follow_rules enable row level security;

create policy "auto-follow rules are readable"
  on public.auto_follow_rules for select
  to authenticated
  using (true);
-- No client writes.

-- Applies the rules to one profile. Never removes anything, and skips groups
-- already followed (so a student who unfollowed isn't re-followed unless
-- their faculty or year changes).
create or replace function public.apply_auto_follows_to(p public.profiles)
returns void
language sql
security definer
set search_path = ''
as $$
  with matching as (
    select g.id as group_id, r.enroll
    from public.auto_follow_rules r
    join public.groups g on g.slug = r.group_slug
    where p.onboarding_completed
      and (r.faculties is null or p.faculty = any (r.faculties))
      and (r.degree_levels is null or p.degree_level = any (r.degree_levels))
      and (not r.froshie_only or p.is_froshie)
  ),
  follows as (
    insert into public.group_follows (profile_id, group_id, source)
    select p.id, group_id, 'auto' from matching
    on conflict do nothing
  )
  insert into public.group_memberships (profile_id, group_id, source)
  select p.id, group_id, 'auto' from matching where enroll
  on conflict do nothing;
$$;

revoke all on function public.apply_auto_follows_to(public.profiles) from public;

create or replace function public.on_profile_auto_follow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Only when onboarding finishes, or faculty / degree / Froshie status
  -- changes afterwards.
  if new.onboarding_completed and (
    tg_op = 'INSERT'
    or not old.onboarding_completed
    or old.faculty is distinct from new.faculty
    or old.degree_level is distinct from new.degree_level
    or old.is_froshie is distinct from new.is_froshie
  ) then
    perform public.apply_auto_follows_to(new);
  end if;
  return new;
end;
$$;

create trigger profiles_auto_follow
  after insert or update on public.profiles
  for each row execute function public.on_profile_auto_follow();

-- Backfill for students who finished onboarding before this migration.
-- seed.sql calls it again after loading the rules.
create or replace function public.backfill_auto_follows()
returns void
language sql
security definer
set search_path = ''
as $$
  select public.apply_auto_follows_to(p)
  from public.profiles p
  where p.onboarding_completed;
$$;

revoke all on function public.backfill_auto_follows() from public;
