-- Only explicitly classified publications are eligible for automatic RSVPs.
alter table public.events alter column supports_unrestricted_rsvp set default false;

-- Preferences live on the owning user's follow row. An update never creates
-- a follow and PostgreSQL rechecks the followed key after concurrent writes.
create function public.set_organization_auto_rsvp(group_slug text, enabled boolean)
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
      'auto_rsvp_enabled_at',
      coalesce(owned.follows->group_slug->'auto_rsvp_enabled_at', to_jsonb(statement_timestamp()))
    ) else (owned.follows->group_slug) - 'auto_rsvp_enabled_at' end,
    false
  )
  where owned.profile_id = (select auth.uid()) and owned.follows ? group_slug
  returning (owned.follows->group_slug->>'auto_rsvp_enabled_at')::timestamptz into consent_at;

  if not found then
    raise exception 'Follow the organization before changing auto-RSVP'
      using errcode = '42501';
  end if;

  return consent_at;
end;
$$;

revoke all on function public.set_organization_auto_rsvp(text, boolean) from public, anon, authenticated;
grant execute on function public.set_organization_auto_rsvp(text, boolean) to authenticated;
