-- Some catalog club ids keep the URL-encoded accents from their SSMU page
-- (e.g. 'ssmu-friends-of-m%c3%a9decins-sans-fronti%c3%a8res-ssmu'), and the
-- app's ids must stay stable, so slugs may contain '%' too.

alter table public.groups drop constraint groups_slug_check;
alter table public.groups
  add constraint groups_slug_check check (slug ~ '^[a-z0-9%-]+$');
