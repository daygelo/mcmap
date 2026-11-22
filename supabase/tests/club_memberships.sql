-- Run as postgres against a local Supabase database with migrations applied.
\set ON_ERROR_STOP on
begin;

insert into auth.users (id, email) values
  ('d0000000-0000-4000-8000-000000000001', 'membership-student-a@mcgill.ca'),
  ('d0000000-0000-4000-8000-000000000002', 'membership-student-b@mcgill.ca');

set local role authenticated;
set local request.jwt.claim.sub = 'd0000000-0000-4000-8000-000000000001';

-- Exercise the same upsert used during onboarding.
insert into public.profile_club_memberships (profile_id, memberships)
values (auth.uid(), '{"mcgill-robotics": {"show_on_profile": false}}')
on conflict (profile_id) do update set memberships = excluded.memberships;

do $$
declare
  robotics constant jsonb :=
    '{"show_on_profile": true, "auto_rsvp_enabled_at": "2026-11-21T15:00:00Z"}';
  current_memberships jsonb;
begin
  perform public.change_club_memberships(jsonb_build_object('mcgill-robotics', robotics));
  current_memberships := public.change_club_memberships(
    '{"csus-first-year-council": {"show_on_profile": false}}'
  );
  if (current_memberships->'mcgill-robotics') is distinct from robotics
    or not (current_memberships ? 'csus-first-year-council') then
    raise exception 'Adding a club lost an existing membership or its preferences';
  end if;

  if public.change_club_memberships('{"csus-first-year-council": null}') is distinct from
    jsonb_build_object('mcgill-robotics', robotics) then
    raise exception 'Removing a club changed the retained memberships';
  end if;
end;
$$;

set local request.jwt.claim.sub = 'd0000000-0000-4000-8000-000000000002';

do $$
begin
  if exists (select 1 from public.profile_club_memberships) then
    raise exception 'A student can read another account''s memberships';
  end if;

  update public.profile_club_memberships set memberships = '{}'
    where profile_id = 'd0000000-0000-4000-8000-000000000001';
  if found then
    raise exception 'A student can update another account''s memberships';
  end if;

  begin
    insert into public.profile_club_memberships (profile_id, memberships)
    values ('d0000000-0000-4000-8000-000000000001', '{}');
    raise exception 'A student can insert another account''s memberships';
  exception when insufficient_privilege then null;
  end;

  perform public.change_club_memberships('{"buss-first-year-council": {"show_on_profile": false}}');
end;
$$;

set local request.jwt.claim.sub = 'd0000000-0000-4000-8000-000000000001';

do $$
begin
  if (select memberships from public.profile_club_memberships) is distinct from
    '{"mcgill-robotics": {"show_on_profile": true,
      "auto_rsvp_enabled_at": "2026-11-21T15:00:00Z"}}'::jsonb then
    raise exception 'Reload returned the wrong memberships or preferences';
  end if;
end;
$$;

rollback;
