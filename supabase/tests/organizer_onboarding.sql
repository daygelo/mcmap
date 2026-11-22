-- Run as postgres against a local Supabase database with migrations applied.
\set ON_ERROR_STOP on
begin;

insert into auth.users (id, email) values
  ('a1000000-0000-4000-8000-000000000001', 'staff-test@mcgill.ca'),
  ('a1000000-0000-4000-8000-000000000002', 'student-test@mcgill.ca'),
  ('a1000000-0000-4000-8000-000000000003', 'admin-test@mcgill.ca');
insert into public.groups (id, slug, name, type) values
  ('b1000000-0000-4000-8000-000000000001', 'organizer-test-faculty', 'Test Faculty', 'faculty'),
  ('b1000000-0000-4000-8000-000000000002', 'organizer-test-club', 'Test Club', 'club');

insert into public.organizer_administrators values ('a1000000-0000-4000-8000-000000000003');
insert into public.organizer_approved_contacts values
  ('b1000000-0000-4000-8000-000000000001', 'office@example.org');

update public.profiles set account_purpose = 'organizer', onboarding_completed = true
  where id = 'a1000000-0000-4000-8000-000000000001';
update public.profiles set onboarding_completed = true, faculty = 'Science',
  major = 'Biology', degree_level = 'undergraduate', u_year = 'U2'
  where id = 'a1000000-0000-4000-8000-000000000002';

do $$
declare
  staff constant uuid := 'a1000000-0000-4000-8000-000000000001';
  student constant uuid := 'a1000000-0000-4000-8000-000000000002';
  faculty_group constant uuid := 'b1000000-0000-4000-8000-000000000001';
  club constant uuid := 'b1000000-0000-4000-8000-000000000002';
  correct constant text := repeat('a', 64);
  wrong constant text := repeat('b', 64);
  result jsonb;
  application uuid;
begin
  result := public.organizer_reserve_code(
    staff, faculty_group, 'Staff Member', 'faculty_representative', ' OFFICE@Example.ORG ', correct
  );
  if result->>'status' is distinct from 'code_sent' then
    raise exception 'Could not initiate verification';
  end if;
  application := (result->>'id')::uuid;
  if public.organizer_verify_code(student, application, correct) <> 'unavailable' then
    raise exception 'An application could be verified by another user';
  end if;
  if public.organizer_verify_code(staff, application, wrong) <> 'invalid_code' then
    raise exception 'An incorrect code was accepted';
  end if;
  if public.organizer_reserve_code(staff, faculty_group, 'Staff Member',
    'faculty_representative', 'office@example.org', correct)->>'status' <> 'rate_limited' then
    raise exception 'Resend cooldown missing';
  end if;

  for i in 2..5 loop
    if public.organizer_verify_code(staff, application, wrong) <>
      (case when i = 5 then 'attempts_exhausted' else 'invalid_code' end) then
      raise exception 'Incorrect attempt handling failed';
    end if;
  end loop;
  if public.organizer_verify_code(staff, application, correct) <> 'attempts_exhausted' then
    raise exception 'Retry limit was bypassed';
  end if;
  update public.organizer_email_challenges set expires_at = now() - interval '1 second'
    where application_id = application;
  if public.organizer_verify_code(staff, application, correct) <> 'expired' then
    raise exception 'An expired code was accepted';
  end if;

  update public.organizer_email_deliveries set sent_at = now() - interval '2 minutes'
    where profile_id = staff;
  result := public.organizer_reserve_code(
    staff, faculty_group, 'Staff Member', 'faculty_representative', 'office@example.org', wrong
  );
  if (result->>'id')::uuid is distinct from application then
    raise exception 'Resending changed the active application';
  end if;
  if public.organizer_verify_code(staff, application, correct) <> 'invalid_code' then
    raise exception 'Resending left the old digest active';
  end if;
  if public.organizer_verify_code(staff, application, wrong) <> 'approved' then
    raise exception 'The exact organization and normalized email match failed';
  end if;
  if public.organizer_verify_code(staff, application, wrong) <> 'unavailable' then
    raise exception 'A code could be reused';
  end if;

  result := public.organizer_reserve_code(
    student, club, 'Student Member', 'president', 'office@example.org', correct
  );
  if public.organizer_verify_code(student, (result->>'id')::uuid, correct) <> 'pending_review' then
    raise exception 'An address preapproved for a different organization was granted access';
  end if;

  update public.organizer_email_deliveries set sent_at = now() - interval '2 minutes'
    where profile_id = student;
  result := public.organizer_reserve_code(
    student, faculty_group, 'Student Member', 'coordinator', 'unknown@example.org', correct
  );
  if public.organizer_verify_code(student, (result->>'id')::uuid, correct) <> 'pending_review' then
    raise exception 'An unknown address was auto-approved';
  end if;

  if exists (select 1 from public.group_publishers where profile_id = student)
    or (select count(*) from public.organizer_applications where profile_id = student
      and status = 'pending_review' and email_verified_at is not null) <> 2 then
    raise exception 'Email control incorrectly granted publishing access';
  end if;
  if not exists (select 1 from public.profiles where id = staff and onboarding_completed
      and faculty is null and degree_level is null and major is null)
    or not exists (select 1 from public.profiles where id = student and onboarding_completed
      and faculty = 'Science' and major = 'Biology' and account_purpose = 'student') then
    raise exception 'Organizer flow damaged academic profile state';
  end if;
end;
$$;

set local role authenticated;
set local request.jwt.claim.sub = 'a1000000-0000-4000-8000-000000000002';
do $$
declare
  application uuid := (select id from public.organizer_applications
    where status = 'pending_review' limit 1);
begin
  if (select count(id) from public.organizer_applications) <> 2 then
    raise exception 'Application RLS does not isolate applicants';
  end if;
  begin
    perform public.organizer_review_application(application, 'approved');
    raise exception 'An applicant approved their own request';
  exception when insufficient_privilege then null;
  end;
  begin
    perform * from public.organizer_review_queue();
    raise exception 'An applicant read the admin queue';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.organizer_verify_code(auth.uid(), application, repeat('a', 64));
    raise exception 'An applicant reached the service-only verification function';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.organizer_reserve_code(auth.uid(),
      'b1000000-0000-4000-8000-000000000001', 'Student Member',
      'president', 'office@example.org', repeat('a', 64));
    raise exception 'An applicant could set their own verification digest';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.organizer_approved_contacts values
      ('b1000000-0000-4000-8000-000000000001', 'student@example.org');
    raise exception 'An applicant could write to the organization allowlist';
  exception when insufficient_privilege then null;
  end;
  begin
    perform code_hash from public.organizer_email_challenges;
    raise exception 'An applicant read verification hashes';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.organizer_applications set status = 'approved' where id = application;
    raise exception 'An applicant edited application status';
  exception when insufficient_privilege then null;
  end;
  perform public.organizer_request_directory_review('Missing Faculty', 'faculty');
  perform public.organizer_request_directory_review('Missing Faculty', 'faculty');
end;
$$;

set local request.jwt.claim.sub = 'a1000000-0000-4000-8000-000000000001';
do $$
declare
  faculty_group constant uuid := 'b1000000-0000-4000-8000-000000000001';
  club constant uuid := 'b1000000-0000-4000-8000-000000000002';
begin
  perform public.publish_event(gen_random_uuid(), faculty_group, 'Faculty event', 'Description',
    now() + interval '1 day', null, 'Room');
  begin
    perform public.publish_event(gen_random_uuid(), club, 'Club event', 'Description',
      now() + interval '1 day', null, 'Room');
    raise exception 'Organizer could publish for a different organization';
  exception when insufficient_privilege then null;
  end;
end;
$$;

set local request.jwt.claim.sub = 'a1000000-0000-4000-8000-000000000003';
do $$
declare
  faculty_group constant uuid := 'b1000000-0000-4000-8000-000000000001';
  club constant uuid := 'b1000000-0000-4000-8000-000000000002';
begin
  perform public.organizer_review_application(
    (select id from public.organizer_review_queue('approved') where group_id = faculty_group),
    'revoked', 'Term ended'
  );
  perform public.organizer_review_application(
    (select id from public.organizer_review_queue() where group_id = club), 'approved'
  );
  perform public.organizer_review_application(
    (select id from public.organizer_review_queue() where group_id = faculty_group), 'rejected'
  );
end;
$$;

set local request.jwt.claim.sub = 'a1000000-0000-4000-8000-000000000001';
do $$
begin
  if exists (select 1 from public.group_publishers) then
    raise exception 'Revocation left a publishing assignment';
  end if;
  begin
    perform public.publish_event(gen_random_uuid(), 'b1000000-0000-4000-8000-000000000001',
      'Revoked event', 'Description', now() + interval '1 day', null, 'Room');
    raise exception 'A revoked applicant could publish';
  exception when insufficient_privilege then null;
  end;
end;
$$;

reset role;
do $$
declare
  staff constant uuid := 'a1000000-0000-4000-8000-000000000001';
  student constant uuid := 'a1000000-0000-4000-8000-000000000002';
  reviewer constant uuid := 'a1000000-0000-4000-8000-000000000003';
  faculty_group constant uuid := 'b1000000-0000-4000-8000-000000000001';
  club constant uuid := 'b1000000-0000-4000-8000-000000000002';
  digest constant text := repeat('c', 64);
  result jsonb;
begin
  if not exists (select 1 from public.organizer_applications
    where profile_id = staff and status = 'revoked'
      and revoked_by = reviewer and revoked_at is not null)
    or not exists (select 1 from public.organizer_applications
      where profile_id = student and group_id = faculty_group and status = 'rejected'
        and decided_by = reviewer)
    or not exists (select 1 from public.group_publishers
      where profile_id = student and group_id = club and role = 'president') then
    raise exception 'Admin decisions or audit metadata were not saved';
  end if;
  if (select count(*) from public.organizer_directory_requests where profile_id = student) <> 1
    or exists (select 1 from public.groups where name = 'Missing Faculty') then
    raise exception 'Directory request was duplicated or created an organization';
  end if;

  update public.organizer_email_deliveries set sent_at = now() - interval '2 minutes'
    where profile_id = staff;
  result := public.organizer_reserve_code(
    staff, faculty_group, 'Staff Member', 'faculty_representative', 'office@example.org', digest
  );
  if public.organizer_verify_code(staff, (result->>'id')::uuid, digest) <> 'pending_review' then
    raise exception 'A revoked applicant bypassed fresh approval or could not resubmit';
  end if;

  -- Even an app administrator must use another administrator for their own application.
  result := public.organizer_reserve_code(
    reviewer, club, 'Administrator', 'coordinator', 'admin-office@example.org', digest
  );
  perform public.organizer_verify_code(reviewer, (result->>'id')::uuid, digest);
  begin
    perform public.organizer_review_application((result->>'id')::uuid, 'approved');
    raise exception 'An administrator approved their own application';
  exception when insufficient_privilege then null;
  end;
end;
$$;

rollback;
