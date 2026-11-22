-- Makes sure every signed-in user has a profiles row, so the app never fails
-- to load a profile just because the row is missing (e.g. accounts created
-- before the schema migration, or a signup while the trigger was missing).
-- Safe to run more than once.

-- Signup trigger: create the row, never fail if it already exists.
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
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Users may create their own row (the app normally uses
-- ensure_my_profile() below, which also picks a free handle).
drop policy if exists "users create their own profile" on public.profiles;
create policy "users create their own profile"
  on public.profiles for insert
  to authenticated
  with check ((select auth.uid()) = id);

-- Returns the caller's profile, creating a starter row
-- (onboarding_completed = false) if there isn't one yet.
create or replace function public.ensure_my_profile()
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  result public.profiles;
begin
  if uid is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;

  insert into public.profiles (id, full_name, handle)
  select
    u.id,
    coalesce(nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''), ''),
    public.unique_handle(u.email)
  from auth.users u
  where u.id = uid
  on conflict (id) do nothing;

  select * into result from public.profiles where id = uid;
  return result;
end;
$$;

revoke all on function public.ensure_my_profile() from public;
grant execute on function public.ensure_my_profile() to authenticated;

-- Backfill anyone still missing a row (one at a time, so two users with the
-- same email prefix get different handles).
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
    )
    on conflict (id) do nothing;
  end loop;
end;
$$;
