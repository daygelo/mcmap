create table public.group_publishers (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  group_id uuid not null references public.groups (id) on delete cascade,
  role text not null check (
    role in ('president', 'coordinator', 'faculty_representative', 'delegated_publisher')
  ),
  primary key (profile_id, group_id)
);

create index group_publishers_group_idx on public.group_publishers (group_id);

alter table public.group_publishers enable row level security;
revoke all on public.group_publishers from public, anon, authenticated;
grant select on public.group_publishers to authenticated;
grant select, insert, update, delete on public.group_publishers to service_role;

create policy "publishers read their own assignments"
  on public.group_publishers for select to authenticated
  using (profile_id = (select auth.uid()));

-- The publishing function controls the creator, publication time and fields
-- that are writable. Existing event read policies still govern discovery.
revoke insert, update, delete, truncate on public.events from public, anon, authenticated;

create function public.publish_event(
  event_id uuid,
  organization_id uuid,
  event_title text,
  event_description text,
  event_start timestamptz,
  event_end timestamptz,
  event_location text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  publisher_id uuid := auth.uid();
  published public.events%rowtype;
  organization jsonb;
begin
  -- Lock the assignment through publication so a concurrent revocation
  -- and publication have a definite order.
  perform 1 from public.group_publishers p
    where p.profile_id = publisher_id and p.group_id = organization_id
    for share;
  if not found then
    raise exception 'Publishing permission required for this organization'
      using errcode = '42501';
  end if;

  if event_id is null
    or event_title is null or event_title !~ '[^[:space:]]'
    or event_description is null or event_description !~ '[^[:space:]]'
    or event_location is null or event_location !~ '[^[:space:]]'
    or event_start is null or not isfinite(event_start)
    or (event_end is not null and (not isfinite(event_end) or event_end < event_start))
  then
    raise exception 'Invalid event details' using errcode = '22023';
  end if;

  insert into public.events (
    id, group_id, created_by, title, full_description, starts_at, ends_at, location_name
  ) values (
    event_id, organization_id, publisher_id, btrim(event_title),
    btrim(event_description), event_start, event_end, btrim(event_location)
  )
  on conflict (id) do nothing
  returning * into published;

  if not found then
    select * into published from public.events e
      where e.id = event_id and e.created_by = publisher_id
        and e.group_id = organization_id and e.published_at <= now();
    if not found then
      raise exception 'Event ID is unavailable' using errcode = '23505';
    end if;
  end if;

  select jsonb_build_object('slug', g.slug, 'name', g.name, 'avatar_url', g.avatar_url)
    into organization from public.groups g where g.id = published.group_id;
  return to_jsonb(published) || jsonb_build_object('groups', organization);
end;
$$;

revoke all on function public.publish_event(uuid, uuid, text, text, timestamptz, timestamptz, text)
  from public, anon, authenticated;
grant execute on function public.publish_event(uuid, uuid, text, text, timestamptz, timestamptz, text)
  to authenticated;
