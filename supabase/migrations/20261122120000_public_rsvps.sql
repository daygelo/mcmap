-- RSVPs are public unless the student chooses otherwise.
-- Run after 20261122110000. Safe to run more than once.
--
-- RSVPs already saved keep their audience: they were made while the app's
-- default was private.

alter table public.event_rsvps alter column visibility set default 'public';

-- The student's choice for their next RSVPs. It has to outlive a restart, or
-- someone who picked private would quietly go back to public.
alter table public.profiles
  add column if not exists rsvp_visibility public.rsvp_visibility
  not null default 'public';

-- Lets the API see the new column.
notify pgrst, 'reload schema';
