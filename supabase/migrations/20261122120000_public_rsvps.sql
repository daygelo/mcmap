-- Preserve the integration migration version. RSVP visibility is account-wide
-- and defaults to Private. The earlier migration owns the RPC, insert trigger
-- and row-level access rules. These defaults do not rewrite any saved choices.
alter table public.profiles alter column rsvp_visibility set default 'private';
alter table public.event_rsvps alter column visibility set default 'private';

notify pgrst, 'reload schema';
