-- Store generic reminders. Resolve attendance when the recipient opens the
-- inbox so changed RSVP visibility and removed follows take effect immediately.
create or replace function public.clear_notification_attendance()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  select format(
    'RSVP deadline for %s hosted by %s ends soon.',
    e.title, coalesce(nullif(g.short_name, ''), g.name)
  )
  into new.body
  from public.events e
  join public.groups g on g.id = e.group_id
  where e.id = new.event_id;

  new.friend_rsvp_count := 0;
  return new;
end;
$$;

revoke all on function public.clear_notification_attendance()
  from public, anon, authenticated;

create trigger notifications_clear_attendance
  before insert or update of friend_rsvp_count on public.notifications
  for each row
  when (new.type = 'event_deadline_soon' and new.friend_rsvp_count > 0)
  execute function public.clear_notification_attendance();

-- Fire the same redaction for reminders written before this migration.
update public.notifications
set friend_rsvp_count = friend_rsvp_count
where type = 'event_deadline_soon' and friend_rsvp_count > 0;

create view public.notification_inbox
with (security_invoker = true)
as
select
  n.id, n.user_id, n.type, n.event_id, n.group_id, n.title,
  case when friends.friend_rsvp_count > 0 then format(
    'RSVP deadline for %s ends soon — %s of your McGillians RSVPed!',
    e.title, friends.friend_rsvp_count
  ) else n.body end as body,
  coalesce(friends.friend_rsvp_count, 0) as friend_rsvp_count,
  n.is_read, n.created_at,
  g.name as group_name, g.avatar_url as group_avatar_url
from public.notifications n
left join public.groups g on g.id = n.group_id
left join public.events e on n.type = 'event_deadline_soon' and e.id = n.event_id
left join lateral public.friend_rsvps(array[e.id]) friends on e.id is not null;

revoke all on public.notification_inbox from public, anon, authenticated;
grant select on public.notification_inbox to authenticated;

notify pgrst, 'reload schema';
