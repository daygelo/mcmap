-- Keep the legacy data and RPC intact for rollback. Apply this migration
-- after club_memberships and retire legacy writers before the backfill.
create table public.profile_organization_follows (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  follows jsonb not null default '{}'::jsonb check (jsonb_typeof(follows) = 'object')
);

alter table public.profile_organization_follows enable row level security;
revoke all on public.profile_organization_follows from public, anon, authenticated;
grant select, insert, update on public.profile_organization_follows to authenticated;

create policy "students manage their own organization follows"
  on public.profile_organization_follows for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

insert into public.profile_organization_follows (profile_id, follows)
select legacy.profile_id, jsonb_object_agg(
  item.key,
  jsonb_strip_nulls(jsonb_build_object(
    'auto_rsvp_enabled_at', item.value->'auto_rsvp_enabled_at'
  ))
)
from public.profile_club_memberships legacy
cross join lateral jsonb_each(legacy.memberships) item
group by legacy.profile_id;

-- Keys are canonical catalog IDs. Adding an existing key keeps its opt-ins.
create function public.change_organization_follows(
  follow_ids text[],
  unfollow_id text default null
)
returns void
language sql
security invoker
set search_path = ''
as $$
  insert into public.profile_organization_follows as owned (profile_id, follows)
  values (
    (select auth.uid()),
    coalesce((select jsonb_object_agg(id, '{}'::jsonb)
      from unnest(follow_ids) as ids(id)), '{}'::jsonb)
  )
  on conflict (profile_id) do update set follows = case
    when unfollow_id is null then excluded.follows || owned.follows
    else (excluded.follows || owned.follows) - unfollow_id
  end;
$$;

revoke all on function public.change_organization_follows(text[], text) from public, anon, authenticated;
grant execute on function public.change_organization_follows(text[], text) to authenticated;
