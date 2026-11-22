# McMap

A Flutter app with McGill email/password authentication powered by Supabase.

## Authentication behavior

- Only addresses ending in `@mcgill.ca` or a subdomain such as `@mail.mcgill.ca` are accepted.
- The app first asks for the McGill email on a separate scene.
- Existing accounts show a login password scene.
- New addresses show an account-creation onboarding scene.
- Supabase email confirmation settings determine whether a newly created user can enter immediately or must confirm the address first.

## Supabase setup

1. Create a Supabase project.
2. Apply the migrations in order, with `supabase db push` or by pasting each
   file into the SQL editor:
   - `supabase/migrations/20261121000000_create_account_lookup.sql`: the
     `mcgill_account_exists` check used by the login page.
   - `supabase/migrations/20261121000100_mcmap_schema.sql`: `profiles`,
     `mcgillians`, `groups`, `events`, `event_rsvps`, Row Level Security,
     the `search_mcgillians` function, and the `avatars` / `group-images`
     storage buckets. It also creates a profile row for any existing accounts.
   - `supabase/migrations/20261121000200_allow_encoded_group_slugs.sql`:
     lets group slugs contain `%` (one catalog ID keeps URL-encoded accents).
   - `supabase/migrations/20261122100000_more_group_types.sql`: adds the
     `campus_society`, `faculty_association` and `research_group` types. Run
     it on its own, after the migrations described further down.
   - `supabase/migrations/20261122100100_group_details.sql`: adds
     `short_name`, `handle` and `faculty_affiliation` to `groups` and sets the
     right types for student governance.
   - `supabase/migrations/20261122100200_merge_duplicate_groups.sql`: merges
     the first seed's SSMU, PGSS, EUS and MUS into their catalog groups, moving
     events, RSVPs, publishers and follows. Running an older `seed.sql`
     afterwards would add the duplicates back.
   - `supabase/migrations/20261122110000_notifications.sql`: adds
     `events.rsvp_deadline`, friend RSVP counts and `notifications`; see
     [Notifications](#notifications).
   - `supabase/migrations/20261122120000_public_rsvps.sql`: makes new RSVPs
     public by default and adds `profiles.rsvp_visibility`. Run it last; see
     [RSVP privacy](#rsvp-privacy).
3. Optionally load demo groups and events: run `supabase/seed.sql` in the SQL
   editor. It's generated from the in-app club catalog
   (`dart run tool/generate_seed.dart > supabase/seed.sql`), so group slugs
   match the app's club IDs. Event dates are relative to when you run it. It
   needs every migration, and is safe to run again. Groups outside the catalog
   live in `lib/data/campus_groups.dart`; `metadata.verified` is false for the
   ones without a confirming public page.
4. Enable email/password authentication in **Authentication → Providers**.
5. In **Authentication → URL Configuration**, configure the Site URL and redirect URLs if email confirmation is enabled.
6. Optionally disable email confirmation for immediate account login during development.

### What happens after login

`AuthGate` (in `lib/main.dart`) loads the user's `profiles` row:

- `onboarding_completed = false` → academic profile → interests (skippable)
  → organizations to follow (skippable), then saves the selections and profile.
- `onboarding_completed = true` → straight into the McMap app.

Saved in Supabase: academic profile and interests, name/bio/photo edits
(photos go to the `avatars` bucket under `<user id>/`), RSVPs, and
McGillians (follow requests to private profiles stay `requested`).
Organization follows are also saved after the migration below. Event notification
opt-ins remain session preferences.

### Offline demo

Without `--dart-define` keys the app shows a setup notice with an
**Explore the offline demo** button. It runs the whole app on sample data
(this is also what the tests use).

Run the app with compile-time credentials:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Never use or commit a Supabase service-role key. The publishable/anon key is intended for client applications.

## Campus map

The Map tab needs `MAPBOX_TOKEN` (`flutter run --dart-define-from-file=.env`).
Camera limits are in `lib/data/campus_map.dart`.

Highlighted buildings and the offices and lounges inside them are in
`lib/data/campus_buildings.dart`. Every space records the page its details
came from; leave a room out rather than guess. To add a building, add it there
and to `WAYS` in `tool/build_campus_shapes.py` (its OpenStreetMap way id), then
run that script to regenerate `lib/data/campus_building_shapes.dart`. Shapes
are the surveyed roofs in Montréal's 3D building model (CC BY 4.0), divided
along © OpenStreetMap outlines (ODbL), with ground level from Natural Resources
Canada's HRDEM (Open Government Licence - Canada). The map key credits them.

The basemap's greens (parks, lawns, street trees) and pale buildings are set in
`campusBasemap` in `lib/data/campus_map.dart`. A test keeps the highlighted
buildings and pins standing out from them.

Mapbox reports every building along the line of sight, so `SightLine` works out
whether a tapped building is hidden behind another one.

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

## Club catalog and RSVP prototype

The app bundles the dated directory snapshot in
`lib/data/club_catalog_data.dart`. Each row contains an internal ID, the
published display name, source keys, organization type, and optional aliases.
To refresh it, review the linked source pages, reconcile cross-listings,
and update the verification date. Add new IDs for new organizations and
preserve existing IDs across corrections or renames. Keep rows sorted by
display name and run the catalog and onboarding tests. The snapshot excludes
SSMU services and independent groups, seasonal recreation listings, and
groups outside the listed sources.

Organization follows use canonical catalog IDs in `UserProfile.followedClubIds`.
The Following filter composes with text search. Club details, Home, and Profile
share RSVP decisions.

The owner-only Following page links to the Event updates inbox. Notification
opt-ins start off and unfollowing clears them. The inbox deduplicates events
by ID for the session. The `HomePage.publications` input also exercises
existing explicit auto-RSVP consent. An opt-in applies only to eligible
publications after its timestamp and does not override prior RSVP decisions.
Students can manage this preference both in **Profile → Following**
and on an organization's details page.

### Academic follows in onboarding

The organization picker preselects researched student associations from
`lib/data/academic_auto_follows.dart`. Each rule carries its catalog ID,
eligibility, and source. The picker lets students deselect defaults or skip
optional groups while retaining the academic selections they approved. Signup
only covers downtown: it doesn't ask for a campus, and Macdonald Campus
programs and societies (`macdonaldOrganizationIds`) aren't offered or suggested.
Those societies stay in the directory for students who already follow them.

The final choices use the same Following records as manual follows. Defaults
run only in onboarding, so later sign-ins and profile edits never re-add an
unfollowed association. New follows leave both event preferences off.

When the Following table or its write RPC is specifically unavailable,
signed-in students can finish onboarding and see their choices for the current
session. The Following page displays the temporary-storage notice. Permission
or network failures still surface as save errors. The updated seed provides
the verified catalog rows for local development. Existing deployments may
have short legacy group slugs alongside canonical catalog slugs. Coordinate
event and publisher links before reconciling those rows.

### Organization Following migration

Apply all Supabase migrations through
`20261121000500_organization_follows.sql` in order before deploying the new
client. Stop legacy membership writers before the cutover so their final
saved selections are included. The migration copies each saved organization
once per account and keeps explicit auto-RSVP timestamps, leaving the old
records available for rollback. It does not modify profile or RSVP rows.
There was no persisted store for the previous Following list, so older
session-only follows and memberships cannot be recovered after a restart.

To verify the actual backfill and row-level security, use a disposable local
Supabase database with migrations applied through
`20261121000400_club_memberships.sql` only. The test seeds legacy data, runs
the new migration, verifies the result, and rolls everything back.

```bash
psql 'postgresql://postgres:postgres@127.0.0.1:54322/postgres' \
  -f supabase/tests/organization_follows.sql
```

### Organization auto-RSVP

Apply `20261121000600_organization_auto_rsvp.sql` after the Following
migration. The authenticated preference is stored on the owner's organization
follow row and keyed by the same stable group slug used in events. Enabling
records the server timestamp. Disabling or unfollowing removes it without
changing RSVP history. Offline preferences are session-only.

The local publication stream demonstrates automatic RSVPs, with the audience
chosen in Settings. Production
background automation is pending. A server-side publication worker needs to
process newly visible events, check exact group identity and consent time,
require explicit unrestricted eligibility, and atomically preserve manual
RSVP and cancellation decisions with one durable record per user and event.
Persist cancellations so a replay cannot recreate an RSVP. The migration
defaults new events to ineligible until the publication source explicitly
marks them unrestricted. Existing eligibility flags should be audited before
a live worker consumes them.

With the migrations applied to a local Supabase instance, run the preference
and authorization test:

```bash
psql 'postgresql://postgres:postgres@127.0.0.1:54322/postgres' \
  -f supabase/tests/organization_auto_rsvp.sql
```

### Integrated student profile

Academic onboarding keeps Gabby's degree level, nullable major, year, and
Froshie rules. The optional club picker updates the same `UserProfile`
without changing those fields. Home keeps club relationships in that model
and keeps editable presentation fields, including image bytes, in Gabby's
`StudentProfile`. Suggestions read the live edited academic labels and
interests from the presentation. Friend requests and connections remain in
`SocialGraph` and are separate from follows. The original profile statistics
remain in place, with the organization Following count below the profile header.

## Notifications

The bell in the app bar lists `public.notifications`, one per student, kind and
event. Until the migration is run the bell stays empty and event cards show no
friend counts.

- **New events.** A trigger on `events` notifies everyone following the group
  (`profile_organization_follows`) except the organizer. Scheduled publications
  are announced once they become visible.
- **Deadlines.** `generate_ending_soon_notifications()` reminds followers who
  haven't RSVPed when `coalesce(rsvp_deadline, starts_at)` is within 24 hours.
  The migration schedules it every 15 minutes if `pg_cron` is available. The app
  also calls `refresh_my_notifications()`, which covers only the caller, on
  load, on resume and when the bell is opened.
- **Live updates** use Supabase Realtime. The migration adds the table to the
  `supabase_realtime` publication.

Friend counts (`friend_rsvps()`) include McGillians the student follows whose
RSVP is visible to **Friends** or **Public**. Private ones never count. `publish_event` does not set `rsvp_deadline` yet, so
RSVPs close at the start time unless a deadline is set in the database.

With the migrations applied to a local Supabase instance:

```bash
psql 'postgresql://postgres:postgres@127.0.0.1:54322/postgres' \
  -f supabase/tests/notifications.sql
```

## RSVP privacy

RSVPs are public unless the student picks **Friends** or **Private** in
Settings. The choice is saved in `profiles.rsvp_visibility` and used for new
RSVPs; existing ones keep their audience, including those made while the default
was private. A McGillian's profile lists the upcoming events they're going to,
as far as row level security allows. Until the migration is run the choice lasts
for the session.

```bash
psql 'postgresql://postgres:postgres@127.0.0.1:54322/postgres' \
  -f supabase/tests/public_rsvps.sql
```

## Refreshing

Home, All campus events and Profile refresh when dragged past the top or bottom
(`lib/widgets/pull_to_refresh.dart`). Web trackpads can't scroll past the end of
a list, so scrolling on from an end counts there. RSVPs that are being saved, or
that change during a refresh, win over the server's copy.

## Event publishing

Signed-in accounts with a verified publisher assignment see **Create** between
**Map** and **Profile**. The organization selector lists their assigned groups.
The schedule picker uses the device's local time zone and sends UTC timestamps.
A successful publication opens the event details and adds the event to Home
discovery. The offline demo has no publishing access.

Apply `supabase/migrations/20261121000300_event_publishing.sql` to the target
database before enabling publishing. A database administrator should verify the
organizer's authority and manage `public.group_publishers` through the
Supabase SQL editor or a trusted server workflow. For example, replace the
profile UUID and group slug below with the verified account and organization.

```sql
insert into public.group_publishers (profile_id, group_id, role)
select 'VERIFIED_PROFILE_UUID'::uuid, id, 'president'
from public.groups
where slug = 'VERIFIED_GROUP_SLUG'
on conflict (profile_id, group_id) do update set role = excluded.role;
```

Available roles are `president`, `coordinator`, `faculty_representative` and
`delegated_publisher`. Delete the corresponding assignment to revoke access.
Signed-in users can read their own assignments. The publishing function verifies
the assignment, sets the creator from the signed-in account and records the
publication time in the existing events table.

### Local database authorization test

With the repository migrations applied to a local Supabase instance, use a local
Postgres administrator connection. The script switches to the authenticated role
with fixture identities and rolls back its data at the end.

```bash
psql 'postgresql://postgres:postgres@127.0.0.1:54322/postgres' \
  -f supabase/tests/event_publishing.sql
```
