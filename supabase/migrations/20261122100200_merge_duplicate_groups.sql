-- SSMU, PGSS, EUS and MUS each existed twice: once from the app's club
-- catalog and once hand-written in the first seed. Keep the catalog group and
-- move everything from the duplicate onto it: events (with their RSVPs),
-- publishers, follows and memberships. Run after 20261122100100, then run the
-- current supabase/seed.sql. All or nothing, and safe to run more than once.

do $$
declare
  pair record;
  ref record;
  old_group public.groups;
  new_id uuid;
  left_behind boolean;
begin
  for pair in
    select * from (values
      ('ssmu', 'mcgill-ssmu'),
      ('pgss', 'mcgill-pgss'),
      ('eus', 'engineering-engineering-undergraduate-society-eus'),
      ('mus', 'desautels-mus')
    ) as t(old_slug, new_slug)
  loop
    -- Follows are keyed by slug. If a student follows both, the catalog
    -- group's own auto-RSVP choice wins: merging never turns auto-RSVP on
    -- for a group where it was off.
    update public.profile_organization_follows
    set follows = case
      when follows ? pair.new_slug then follows - pair.old_slug
      else (follows - pair.old_slug)
        || jsonb_build_object(pair.new_slug, follows -> pair.old_slug)
    end
    where follows ? pair.old_slug;

    select * into old_group from public.groups where slug = pair.old_slug for update;
    continue when not found;

    select id into new_id from public.groups where slug = pair.new_slug for update;
    if not found then
      -- The catalog isn't loaded yet: the duplicate simply becomes it.
      update public.groups set slug = pair.new_slug where id = old_group.id;
      continue;
    end if;

    update public.events set group_id = new_id where group_id = old_group.id;

    -- Tables with one row per (profile, group): skip rows the student already
    -- has on the catalog group. The last two only exist on some databases.
    for ref in
      select t.name from (values
        ('public.group_publishers'),
        ('public.group_follows'),
        ('public.group_memberships')
      ) as t(name)
      where to_regclass(t.name) is not null
    loop
      execute format(
        'update %s as moved set group_id = $1 where group_id = $2
           and not exists (select 1 from %s kept
             where kept.profile_id = moved.profile_id and kept.group_id = $1)',
        ref.name, ref.name
      ) using new_id, old_group.id;
      execute format('delete from %s where group_id = $1', ref.name)
        using old_group.id;
    end loop;

    -- Deleting a group cascades, so stop if anything still points at it.
    for ref in
      select c.conrelid::regclass as tbl, a.attname as col
      from pg_catalog.pg_constraint c
      join pg_catalog.pg_attribute a
        on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
      join pg_catalog.pg_attribute target
        on target.attrelid = c.confrelid and target.attnum = c.confkey[1]
      where c.contype = 'f'
        and c.confrelid = 'public.groups'::regclass
        and target.attname = 'id'
    loop
      execute format('select exists (select 1 from %s where %I = $1)', ref.tbl, ref.col)
        into left_behind using old_group.id;
      if left_behind then
        raise exception 'Not merging %: % still refers to it', pair.old_slug, ref.tbl;
      end if;
    end loop;

    delete from public.groups where id = old_group.id;

    -- Keep anything filled in only on the duplicate.
    update public.groups g set
      description = coalesce(g.description, old_group.description),
      avatar_url = coalesce(g.avatar_url, old_group.avatar_url),
      website_url = coalesce(g.website_url, old_group.website_url),
      short_name = coalesce(g.short_name, old_group.short_name),
      handle = coalesce(g.handle, old_group.handle),
      faculty_affiliation = coalesce(g.faculty_affiliation, old_group.faculty_affiliation),
      is_placeholder = g.is_placeholder and old_group.is_placeholder,
      metadata = old_group.metadata || g.metadata
    where g.id = new_id;
  end loop;
end;
$$;
