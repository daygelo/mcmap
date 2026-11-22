-- Run as postgres against a local Supabase database with migrations applied.
\set ON_ERROR_STOP on
begin;

insert into auth.users (id, email) values
  ('f0000000-0000-4000-8000-000000000001', 'auto-rsvp-student-a@mcgill.ca'),
  ('f0000000-0000-4000-8000-000000000002', 'auto-rsvp-student-b@mcgill.ca');
insert into public.groups (id, slug, name, type)
values ('f1000000-0000-4000-8000-000000000001', 'auto-rsvp-test-faculty', 'Test Faculty', 'faculty');

do $$
declare
  unrestricted boolean;
begin
  insert into public.events (group_id, title)
  values ('f1000000-0000-4000-8000-000000000001', 'Unclassified event')
  returning supports_unrestricted_rsvp into unrestricted;
  if unrestricted is distinct from false then
    raise exception 'Unclassified publications must be ineligible';
  end if;
end;
$$;

set local role authenticated;
set local request.jwt.claim.sub = 'f0000000-0000-4000-8000-000000000001';

do $$
declare
  consent_at timestamptz;
  faculty constant text := 'auto-rsvp-test-faculty';
begin
  begin
    perform public.set_organization_auto_rsvp(faculty, true);
    raise exception 'An unfollowed organization accepted an auto-RSVP opt-in';
  exception when insufficient_privilege then null;
  end;

  perform public.change_organization_follows(array[faculty, 'mcgill-robotics']);
  consent_at := public.set_organization_auto_rsvp(faculty, true);
  if consent_at is null
    or (select (follows->faculty->>'auto_rsvp_enabled_at')::timestamptz
       from public.profile_organization_follows) is distinct from consent_at
    or public.set_organization_auto_rsvp(faculty, true) is distinct from consent_at
  then
    raise exception 'Enabling did not store or preserve the consent timestamp';
  end if;

  set local request.jwt.claim.sub = 'f0000000-0000-4000-8000-000000000002';
  begin
    perform public.set_organization_auto_rsvp(faculty, false);
    raise exception 'A second account modified the first account opt-in';
  exception when insufficient_privilege then null;
  end;
  set local request.jwt.claim.sub = 'f0000000-0000-4000-8000-000000000001';

  consent_at := public.set_organization_auto_rsvp(faculty, false);
  if consent_at is not null
    or (select follows from public.profile_organization_follows) is distinct from
      '{"auto-rsvp-test-faculty": {}, "mcgill-robotics": {}}'::jsonb
  then
    raise exception 'Disabling did not preserve both follows';
  end if;

  perform public.set_organization_auto_rsvp(faculty, true);
  perform public.change_organization_follows(array[]::text[], faculty);
  perform public.change_organization_follows(array[faculty]);
  if (select follows->faculty from public.profile_organization_follows) is distinct from '{}'::jsonb then
    raise exception 'Unfollowing did not clear consent';
  end if;
end;
$$;

rollback;
