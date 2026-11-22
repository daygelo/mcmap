alter table public.profiles
  add column account_purpose text not null default 'student'
    check (account_purpose in ('student', 'organizer')),
  drop constraint onboarding_has_academics,
  add constraint onboarding_has_academics check (
    not onboarding_completed or (
      degree_level is not null and faculty is not null
      and (degree_level <> 'undergraduate' or u_year is not null)
      and (degree_level = 'exchange_continuing' or major is not null)
    ) or (
      account_purpose = 'organizer'
      and degree_level is null and faculty is null and major is null
      and u_year is null and not is_first_year_u1
    )
  );

create table public.organizer_applications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles on delete cascade,
  group_id uuid not null references public.groups on delete cascade,
  full_name text not null,
  executive_email text not null,
  role text not null check (role in (
    'president', 'coordinator', 'faculty_representative', 'delegated_publisher'
  )),
  status text not null default 'verify_email' check (status in (
    'verify_email', 'pending_review', 'approved', 'rejected', 'revoked'
  )),
  created_at timestamptz not null default now(),
  email_verified_at timestamptz,
  decided_at timestamptz,
  decided_by uuid references auth.users on delete set null,
  decision_source text check (decision_source in ('administrator', 'allowlist')),
  revoked_at timestamptz,
  revoked_by uuid references auth.users on delete set null,
  review_note text
);

create unique index organizer_active_application
  on public.organizer_applications (profile_id, group_id)
  where status in ('verify_email', 'pending_review', 'approved');

create index organizer_applications_by_profile
  on public.organizer_applications (profile_id, created_at desc);
create index organizer_applications_for_review
  on public.organizer_applications (status, created_at desc, id desc)
  where email_verified_at is not null;

create table public.organizer_approved_contacts (
  group_id uuid not null references public.groups on delete cascade,
  executive_email text not null check (
    executive_email = lower(btrim(executive_email))
    and length(executive_email) <= 254
    and executive_email ~ '^[a-z0-9.!#$%&''*+/=?^_`{|}~-]+@[a-z0-9]([a-z0-9-]*[a-z0-9])?([.][a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'
  ),
  primary key (group_id, executive_email)
);

create table public.organizer_administrators (
  profile_id uuid primary key references auth.users on delete cascade
);

create table public.organizer_email_challenges (
  application_id uuid primary key references public.organizer_applications on delete cascade,
  code_hash text not null check (code_hash ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz not null,
  attempts integer not null default 0
);

create table public.organizer_email_deliveries (
  profile_id uuid not null references public.profiles on delete cascade,
  executive_email text not null,
  sent_at timestamptz not null default now()
);
create index organizer_delivery_profile
  on public.organizer_email_deliveries (profile_id, sent_at);
create index organizer_delivery_recipient
  on public.organizer_email_deliveries (executive_email, sent_at);

create table public.organizer_directory_requests (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles on delete cascade,
  organization_name text not null,
  organization_type text not null,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users on delete set null
);

create index organizer_directory_requests_by_profile
  on public.organizer_directory_requests (profile_id, created_at desc);

alter table public.organizer_applications enable row level security;
alter table public.organizer_approved_contacts enable row level security;
alter table public.organizer_administrators enable row level security;
alter table public.organizer_email_challenges enable row level security;
alter table public.organizer_email_deliveries enable row level security;
alter table public.organizer_directory_requests enable row level security;

revoke all on public.organizer_applications, public.organizer_approved_contacts,
  public.organizer_administrators, public.organizer_email_challenges,
  public.organizer_email_deliveries, public.organizer_directory_requests
  from public, anon, authenticated, service_role;

grant select (id, profile_id, group_id, full_name, executive_email, role, status, created_at, review_note)
  on public.organizer_applications to authenticated;
create policy organizer_read_own_application on public.organizer_applications
  for select to authenticated using (profile_id = (select auth.uid()));

grant select, insert, delete on public.organizer_administrators,
  public.organizer_approved_contacts to service_role;
grant select on public.organizer_applications to service_role;
grant select, update (reviewed_at, reviewed_by) on public.organizer_directory_requests to service_role;
grant select (sent_at), delete on public.organizer_email_deliveries to service_role;
grant select (expires_at), delete on public.organizer_email_challenges to service_role;

-- Only the Edge Function can reserve a delivery. It supplies the identity
-- verified by Auth and a keyed digest, then sends the code after this commits.
create function public.organizer_reserve_code(
  applicant uuid, organization uuid, applicant_name text,
  official_role text, recipient text, digest text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  application public.organizer_applications%rowtype;
begin
  recipient := lower(btrim(recipient));
  applicant_name := btrim(applicant_name);
  if recipient is null or length(recipient) > 254
    or recipient !~ '^[a-z0-9.!#$%&''*+/=?^_`{|}~-]+@[a-z0-9]([a-z0-9-]*[a-z0-9])?([.][a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'
    or applicant_name is null or length(applicant_name) not between 1 and 120
    or official_role is null or official_role not in (
      'president', 'coordinator', 'faculty_representative', 'delegated_publisher'
    )
    or not exists (select 1 from public.groups where id = organization)
  then
    return jsonb_build_object('status', 'invalid_details');
  end if;

  perform pg_advisory_xact_lock(47101, hashtext(applicant::text));
  perform pg_advisory_xact_lock(47102, hashtext(recipient));
  select * into application from public.organizer_applications
    where profile_id = applicant and group_id = organization
      and status in ('verify_email', 'pending_review', 'approved')
    for update;
  if application.status in ('pending_review', 'approved') then
    return jsonb_build_object('status', 'already_submitted');
  end if;

  if exists (
    select 1 from public.organizer_email_deliveries
    where profile_id = applicant and sent_at > now() - interval '1 minute'
  ) or (
    select count(*) from public.organizer_email_deliveries
    where profile_id = applicant and sent_at > now() - interval '1 day'
  ) >= 5 or (
    select count(*) from public.organizer_email_deliveries
    where executive_email = recipient and sent_at > now() - interval '1 day'
  ) >= 10 then
    return jsonb_build_object('status', 'rate_limited');
  end if;

  if application.id is null then
    insert into public.organizer_applications
      (profile_id, group_id, full_name, executive_email, role)
    values (applicant, organization, applicant_name, recipient, official_role)
    returning * into application;
  else
    update public.organizer_applications set
      full_name = applicant_name, executive_email = recipient, role = official_role
      where id = application.id;
  end if;

  insert into public.organizer_email_challenges (application_id, code_hash, expires_at)
    values (application.id, digest, now() + interval '10 minutes')
    on conflict (application_id) do update set
      code_hash = excluded.code_hash, expires_at = excluded.expires_at, attempts = 0;
  insert into public.organizer_email_deliveries (profile_id, executive_email)
    values (applicant, recipient);
  return jsonb_build_object('status', 'code_sent', 'id', application.id);
end;
$$;

create function public.organizer_verify_code(
  applicant uuid, application_id uuid, digest text
) returns text language plpgsql security definer set search_path = '' as $$
declare
  application public.organizer_applications%rowtype;
  challenge public.organizer_email_challenges%rowtype;
begin
  select * into application from public.organizer_applications
    where id = application_id and profile_id = applicant for update;
  if not found or application.status <> 'verify_email' then
    return 'unavailable';
  end if;

  select * into challenge from public.organizer_email_challenges c
    where c.application_id = application.id for update;
  if not found or challenge.expires_at <= now() then
    return 'expired';
  end if;
  if challenge.attempts >= 5 then
    return 'attempts_exhausted';
  end if;
  if digest is distinct from challenge.code_hash then
    update public.organizer_email_challenges c set attempts = attempts + 1
      where c.application_id = application.id;
    if challenge.attempts = 4 then return 'attempts_exhausted'; end if;
    return 'invalid_code';
  end if;

  delete from public.organizer_email_challenges c where c.application_id = application.id;
  perform 1 from public.organizer_approved_contacts c
    where c.group_id = application.group_id and c.executive_email = application.executive_email
    for share;
  if found and not exists (
    select 1 from public.organizer_applications past
    where past.profile_id = applicant and past.group_id = application.group_id
      and past.status in ('rejected', 'revoked')
  ) then
    insert into public.group_publishers (profile_id, group_id, role)
      values (applicant, application.group_id, application.role)
      on conflict (profile_id, group_id) do update set role = excluded.role;
    update public.organizer_applications set status = 'approved',
      email_verified_at = now(), decided_at = now(), decision_source = 'allowlist'
      where id = application.id;
    return 'approved';
  end if;

  update public.organizer_applications set status = 'pending_review',
    email_verified_at = now() where id = application.id;
  return 'pending_review';
end;
$$;

create function public.organizer_review_queue(
  application_status text default 'pending_review',
  before_created_at timestamptz default 'infinity',
  before_id uuid default 'ffffffff-ffff-ffff-ffff-ffffffffffff'
) returns table (
  id uuid, applicant uuid, group_id uuid, organization text, group_slug text,
  full_name text, executive_email text, role text, status text,
  created_at timestamptz, email_verified_at timestamptz
) language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.organizer_administrators where profile_id = auth.uid()) then
    raise exception 'Administrator required' using errcode = '42501';
  end if;

  return query
    select a.id, a.profile_id, a.group_id, g.name, g.slug, a.full_name,
      a.executive_email, a.role, a.status, a.created_at, a.email_verified_at
    from public.organizer_applications a
    join public.groups g on g.id = a.group_id
    where a.status = application_status and a.profile_id <> auth.uid()
      and (a.created_at, a.id) < (before_created_at, before_id) and a.email_verified_at is not null
    order by a.created_at desc, a.id desc
    limit 100;
end;
$$;

create function public.organizer_review_application(
  application_id uuid, decision text, note text default null
) returns void language plpgsql security definer set search_path = '' as $$
declare
  reviewer uuid := auth.uid();
  application public.organizer_applications%rowtype;
begin
  perform 1 from public.organizer_administrators where profile_id = reviewer for share;
  if not found then raise exception 'Administrator required' using errcode = '42501'; end if;

  select * into application from public.organizer_applications
    where id = application_id for update;
  if not found or application.profile_id = reviewer then
    raise exception 'Application unavailable for review' using errcode = '42501';
  end if;
  if length(note) > 500 then
    raise exception 'Review note is too long' using errcode = '22023';
  end if;

  if application.status = 'pending_review' and application.email_verified_at is not null
    and decision in ('approved', 'rejected') then
    if decision = 'approved' then
      insert into public.group_publishers (profile_id, group_id, role)
        values (application.profile_id, application.group_id, application.role)
        on conflict (profile_id, group_id) do update set role = excluded.role;
    end if;
    update public.organizer_applications set status = decision,
      decided_at = now(), decided_by = reviewer, decision_source = 'administrator',
      review_note = note where id = application.id;
  elsif application.status = 'approved' and decision = 'revoked' then
    delete from public.group_publishers
      where profile_id = application.profile_id and group_id = application.group_id;
    update public.organizer_applications set status = 'revoked',
      revoked_at = now(), revoked_by = reviewer, review_note = note where id = application.id;
  else
    raise exception 'Invalid application transition' using errcode = '22023';
  end if;
end;
$$;

create function public.organizer_request_directory_review(
  requested_name text, requested_type text
) returns void language plpgsql security definer set search_path = '' as $$
declare
  applicant uuid := auth.uid();
begin
  if applicant is null then raise exception 'Sign in required' using errcode = '42501'; end if;
  requested_name := btrim(requested_name);
  if requested_name is null or length(requested_name) not between 1 and 150
    or requested_type is null or requested_type not in ('faculty', 'association', 'club', 'other')
  then raise exception 'Invalid directory request' using errcode = '22023'; end if;

  perform pg_advisory_xact_lock(47101, hashtext(applicant::text));
  if exists (select 1 from public.organizer_directory_requests where profile_id = applicant
    and lower(organization_name) = lower(requested_name)
    and organization_type = requested_type and reviewed_at is null) then
    return;
  end if;
  if (select count(*) from public.organizer_directory_requests
    where profile_id = applicant and created_at > now() - interval '1 day') >= 3
  then raise exception 'Directory request limit reached' using errcode = '22023'; end if;
  insert into public.organizer_directory_requests (profile_id, organization_name, organization_type)
    values (applicant, requested_name, requested_type);
end;
$$;

revoke all on function public.organizer_reserve_code(uuid, uuid, text, text, text, text),
  public.organizer_verify_code(uuid, uuid, text),
  public.organizer_review_application(uuid, text, text),
  public.organizer_review_queue(text, timestamptz, uuid),
  public.organizer_request_directory_review(text, text) from public, anon, authenticated;

grant execute on function public.organizer_reserve_code(uuid, uuid, text, text, text, text),
  public.organizer_verify_code(uuid, uuid, text) to service_role;
grant execute on function public.organizer_review_application(uuid, text, text),
  public.organizer_review_queue(text, timestamptz, uuid),
  public.organizer_request_directory_review(text, text) to authenticated;
