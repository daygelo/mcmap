-- Run as postgres against a local Supabase database with migrations applied.
\set ON_ERROR_STOP on
begin;

insert into auth.users (id, email) values
  ('a0000000-0000-4000-8000-000000000001', 'publishing-student@mcgill.ca'),
  ('a0000000-0000-4000-8000-000000000002', 'publishing-organizer@mcgill.ca');
insert into public.groups (id, slug, name) values
  ('b0000000-0000-4000-8000-000000000001', 'publishing-test-assigned', 'Assigned group'),
  ('b0000000-0000-4000-8000-000000000002', 'publishing-test-other', 'Other group');
insert into public.group_publishers (profile_id, group_id, role) values
  ('a0000000-0000-4000-8000-000000000002',
   'b0000000-0000-4000-8000-000000000001', 'president');

set local role authenticated;
set local request.jwt.claim.sub = 'a0000000-0000-4000-8000-000000000001';

do $$
begin
  if exists (select 1 from public.group_publishers) then
    raise exception 'A student can see another user''s publisher assignments';
  end if;

  begin
    insert into public.group_publishers (profile_id, group_id, role) values
      (auth.uid(), 'b0000000-0000-4000-8000-000000000001', 'president');
    raise exception 'A student can grant themselves publishing authority';
  exception when insufficient_privilege then null;
  end;

  begin
    perform public.publish_event(
      'c0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
      'Blocked event', 'Description', now() + interval '1 day', null, 'Room 1'
    );
    raise exception 'A student can publish using the RPC';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.events (group_id, title, created_by) values
      ('b0000000-0000-4000-8000-000000000001', 'Blocked event', auth.uid());
    raise exception 'A student can insert directly into events';
  exception when insufficient_privilege then null;
  end;
end;
$$;

set local request.jwt.claim.sub = 'a0000000-0000-4000-8000-000000000002';

do $$
declare
  event_id constant uuid := 'c0000000-0000-4000-8000-000000000001';
  assigned_group constant uuid := 'b0000000-0000-4000-8000-000000000001';
  other_group constant uuid := 'b0000000-0000-4000-8000-000000000002';
  starts_at constant timestamptz := now() + interval '1 day';
  ends_at constant timestamptz := starts_at + interval '2 hours';
  published jsonb;
begin
  if (select array_agg(group_id) from public.group_publishers) is distinct from array[assigned_group] then
    raise exception 'Publisher does not see exactly their own assigned group';
  end if;

  begin
    perform public.publish_event(
      event_id, other_group, 'Blocked event', 'Description', starts_at, null, 'Room 1'
    );
    raise exception 'An organizer can publish for an unassigned group';
  exception when insufficient_privilege then null;
  end;

  begin
    perform public.publish_event(
      event_id, assigned_group, E' \t ', 'Description', starts_at, null, 'Room 1'
    );
    raise exception 'A whitespace-only title was accepted';
  exception when invalid_parameter_value then null;
  end;

  begin
    perform public.publish_event(
      event_id, assigned_group, 'Missing start', 'Description', null, null, 'Room 1'
    );
    raise exception 'A missing start was accepted';
  exception when invalid_parameter_value then null;
  end;

  begin
    perform public.publish_event(
      event_id, assigned_group, 'Invalid end', 'Description', ends_at, starts_at, 'Room 1'
    );
    raise exception 'An end before the start was accepted';
  exception when invalid_parameter_value then null;
  end;

  published := public.publish_event(
    event_id, assigned_group, 'Test event', 'Description', starts_at, ends_at, 'Room 1'
  );
  if (published->>'id')::uuid is distinct from event_id
    or (published->>'group_id')::uuid is distinct from assigned_group
    or (published->>'created_by')::uuid is distinct from auth.uid()
    or published #>> '{groups,name}' is distinct from 'Assigned group'
    or (published->>'starts_at')::timestamptz is distinct from starts_at
    or (published->>'ends_at')::timestamptz is distinct from ends_at
  then
    raise exception 'Published event returned incorrect details: %', published;
  end if;

  if public.publish_event(
    event_id, assigned_group, 'Test event', 'Description', starts_at, ends_at, 'Room 1'
  ) is distinct from published then
    raise exception 'Retry did not return the original event';
  end if;
end;
$$;

set local request.jwt.claim.sub = 'a0000000-0000-4000-8000-000000000001';

do $$
begin
  if (select count(*) from public.events where title = 'Test event'
      and group_id = 'b0000000-0000-4000-8000-000000000001') <> 1 then
    raise exception 'A student cannot discover exactly one published event';
  end if;
  begin
    update public.events set title = 'Tampered' where title = 'Test event';
    raise exception 'A student can modify an event directly';
  exception when insufficient_privilege then null;
  end;
end;
$$;

reset role;
delete from public.group_publishers
where profile_id = 'a0000000-0000-4000-8000-000000000002';

set local role authenticated;
set local request.jwt.claim.sub = 'a0000000-0000-4000-8000-000000000002';

do $$
begin
  begin
    perform public.publish_event(
      'c0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001',
      'Blocked after revocation', 'Description', now() + interval '1 day', null, 'Room 1'
    );
    raise exception 'A revoked organizer can still publish';
  exception when insufficient_privilege then null;
  end;
end;
$$;

rollback;
