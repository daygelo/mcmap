-- Run on a disposable local DB with migrations through 20261121000400 only.
\set ON_ERROR_STOP on
begin;

insert into auth.users (id, email) values
  ('e0000000-0000-4000-8000-000000000001', 'follows-a@mcgill.ca'),
  ('e0000000-0000-4000-8000-000000000002', 'follows-b@mcgill.ca');

insert into public.profile_club_memberships (profile_id, memberships)
values ('e0000000-0000-4000-8000-000000000001', '{
  "mcgill-robotics": {"show_on_profile": true, "auto_rsvp_enabled_at": "2026-11-21T15:00:00Z"},
  "csus-first-year-council": {"show_on_profile": false}
}');

\ir ../migrations/20261121000500_organization_follows.sql

set local role authenticated;
set local request.jwt.claim.sub = 'e0000000-0000-4000-8000-000000000001';

do $$
begin
  if (select follows from public.profile_organization_follows) is distinct from
    '{"mcgill-robotics": {"auto_rsvp_enabled_at": "2026-11-21T15:00:00Z"},
      "csus-first-year-council": {}}'::jsonb then
    raise exception 'Legacy IDs and explicit opt-ins were not migrated correctly';
  end if;
  perform public.change_organization_follows(
    array['mcgill-robotics', 'mcgill-robotics', 'buss-first-year-council']
  );
  perform public.change_organization_follows(array[]::text[], 'csus-first-year-council');
  if (select follows from public.profile_organization_follows) is distinct from
    '{"mcgill-robotics": {"auto_rsvp_enabled_at": "2026-11-21T15:00:00Z"},
      "buss-first-year-council": {}}'::jsonb then
    raise exception 'Follow/unfollow did not preserve existing consent or deduplicate IDs';
  end if;
end;
$$;

set local request.jwt.claim.sub = 'e0000000-0000-4000-8000-000000000002';

do $$
begin
  if exists (select 1 from public.profile_organization_follows) then
    raise exception 'Another account can read migrated follows';
  end if;
  update public.profile_organization_follows set follows = '{}'
    where profile_id = 'e0000000-0000-4000-8000-000000000001';
  if found then
    raise exception 'Another account can modify migrated follows';
  end if;
  perform public.change_organization_follows(array['csus-first-year-council']);
  if (select follows from public.profile_organization_follows) is distinct from
    '{"csus-first-year-council": {}}'::jsonb then
    raise exception 'The second account did not receive its own follow';
  end if;
end;
$$;

rollback;
