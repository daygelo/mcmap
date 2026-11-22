-- Short names, handles and faculty affiliation for groups, and the right
-- type for student governance. Run after 20261122100000, then (re)run
-- supabase/seed.sql. Safe to run more than once.

alter table public.groups add column if not exists short_name text;
alter table public.groups add column if not exists handle text;
alter table public.groups add column if not exists faculty_affiliation text;

comment on column public.groups.handle is 'Social handle without the @.';

alter table public.groups drop constraint if exists groups_handle_check;
alter table public.groups add constraint groups_handle_check
  check (handle ~ '^[a-z0-9._]{2,30}$');

create unique index if not exists groups_handle_key
  on public.groups (handle) where handle is not null;
create index if not exists groups_type_idx on public.groups (type);

-- Governance keeps its ids (follows and events point at them); only the
-- type changes. First-year councils already have their own types.
update public.groups set type = 'campus_society'
where slug in (
  'ssmu', 'pgss',
  'mcgill-ssmu', 'mcgill-pgss', 'mcgill-mcss', 'mcgill-mcgss', 'mcgill-maces'
);

update public.groups set type = 'faculty_association'
where slug in (
  'aus', 'sus', 'eus', 'mus',
  'engineering-engineering-undergraduate-society-eus', 'desautels-mus'
);
