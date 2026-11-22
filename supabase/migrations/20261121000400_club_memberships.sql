-- Catalog slugs are the same identifiers used by the bundled club picker.
-- Keep this owner-only data separate from the publicly readable profiles.
create table public.profile_club_memberships (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  memberships jsonb not null default '{}'::jsonb
    check (jsonb_typeof(memberships) = 'object')
);

alter table public.profile_club_memberships enable row level security;
revoke all on public.profile_club_memberships from public, anon, authenticated;
grant select, insert, update on public.profile_club_memberships to authenticated;

create policy "students read their own club memberships"
  on public.profile_club_memberships for select to authenticated
  using (profile_id = (select auth.uid()));

create policy "students insert their own club memberships"
  on public.profile_club_memberships for insert to authenticated
  with check (profile_id = (select auth.uid()));

create policy "students update their own club memberships"
  on public.profile_club_memberships for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

-- Merge changes by catalog slug so independent edits from two sessions do
-- not replace one another. Null values remove a membership.
create function public.change_club_memberships(changes jsonb)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  insert into public.profile_club_memberships as owned (profile_id, memberships)
  values ((select auth.uid()), jsonb_strip_nulls(changes))
  on conflict (profile_id) do update
    set memberships = jsonb_strip_nulls(owned.memberships || changes)
  returning memberships;
$$;

revoke all on function public.change_club_memberships(jsonb) from public, anon, authenticated;
grant execute on function public.change_club_memberships(jsonb) to authenticated;
