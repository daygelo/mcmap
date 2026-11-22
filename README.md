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
opt-ins and the default RSVP audience remain session preferences.

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

The local publication stream demonstrates private automatic RSVPs. Production
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
