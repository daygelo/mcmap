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
   - Apply organizer onboarding, then the notifications, notification privacy,
     and global RSVP privacy migrations in timestamp order.
     See [Notifications and RSVP privacy](#notifications-and-rsvp-privacy).
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
Organization follows, event notification opt-ins, and account-wide RSVP privacy
are saved in Supabase after the migrations below.

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
optional groups while retaining the academic selections they approved. Campus
is an optional onboarding input. Confirmed program-campus mappings may fill
a blank, and an uncertain or other campus leaves campus-specific defaults off.

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

The app processes opted-in auto-RSVPs on sign-in and attendance refresh.
The server checks that the event was published after consent, is upcoming and
open for RSVPs, and is explicitly eligible for unrestricted RSVPs. Auto-RSVPs
use the account-wide RSVP preference. A durable record keeps manual cancellations
from being recreated on refresh. Offline demo decisions last for the session.

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
`SocialGraph` and are separate from organization follows. Other students’ profiles
show upcoming RSVP events visible to the signed-in viewer.

## Notifications and RSVP privacy

The bell in the app bar reads `public.notification_inbox`, backed by one
notification per student, kind, and event. Apply
`20261122110000_notifications.sql`, `20261122110100_notification_rsvp_privacy.sql`,
and `20261122110200_global_rsvp_privacy.sql` after organizer onboarding.
Deadline reminders calculate friend counts as the recipient reads them.

- **New events.** A trigger on `events` notifies followers who explicitly enabled
  event notifications before publication, excluding the organizer. Scheduled
  publications are announced once they become visible.
- **Deadlines.** `generate_ending_soon_notifications()` reminds opted-in followers
  who haven't RSVPed when `coalesce(rsvp_deadline, starts_at)` is within 24 hours.
  The migration schedules it every 15 minutes if `pg_cron` is available. The app
  also calls `refresh_my_notifications()`, which covers only the caller, on
  load, on resume and when the bell is opened.
- **Live updates** use Supabase Realtime. The migration adds the table to the
  `supabase_realtime` publication.

RSVP privacy applies to all existing and future RSVPs, including auto-RSVPs.
Private RSVPs are visible to their owner. Friends RSVPs require confirmed
McGillian follows in both directions. Public RSVPs are visible to signed-in
users who can see the event. Friend counts include eligible mutual McGillians
only. Profile discoverability is separate and defaults to public for new
accounts. The migration initializes existing accounts’ RSVP preferences and rows
to Private because the app previously stored no durable account-wide choice.
Existing RSVP timestamps and profile visibility are preserved.

RSVPs close at the start time unless a deadline is set in the database.

With the migrations applied to a local Supabase instance:

```bash
psql 'postgresql://postgres:postgres@127.0.0.1:54322/postgres' \
  -f supabase/tests/notifications.sql -f supabase/tests/global_rsvp_privacy.sql
```

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

## Organizer onboarding and operations

After sign-in, new accounts can choose Student or Faculty / Club Executive.
Students can also apply from **Profile → Organizer settings**. Staff can enter
McMap without academic details and add an academic profile later if applicable.

Angelo needs to apply
[`20261122100300_organizer_onboarding.sql`](supabase/migrations/20261122100300_organizer_onboarding.sql)
after the existing migrations, then deploy the `organizer-verification` Edge
Function using the settings in `supabase/config.toml`. The function validates
the signed-in user's access token with Supabase Auth. It uses the runtime's
`SUPABASE_URL` and default publishable and secret keys, with legacy key
fallbacks for older environments.

Set these secrets in the Edge Function environment:

- `ORGANIZER_CODE_SECRET` is a dedicated random secret of at least 32
  characters. For example, generate it with `openssl rand -hex 32`. Rotating
  it requires users with outstanding codes to request a new one.
- `ORGANIZER_SES_REGION` selects an Amazon SES region with production sending
  access and a verified sender identity.
- `ORGANIZER_SES_ACCESS_KEY_ID` and `ORGANIZER_SES_SECRET_ACCESS_KEY` are AWS
  IAM credentials scoped to `ses:SendEmail` for that sender identity. Set
  `ORGANIZER_SES_SESSION_TOKEN` if the credentials include a session token.
- `ORGANIZER_FROM_EMAIL` is the address for the verified SES sender identity.

The function avoids logging verification requests, provider payloads, and
provider errors. SES redacts the message body in its CloudTrail send records.
See the [AWS SES logging documentation](https://docs.aws.amazon.com/ses/latest/dg/logging-using-cloudtrail.html).

A trusted database operator adds reviewer account UUIDs to
`public.organizer_administrators` and exact normalized email/group UUID pairs
to `public.organizer_approved_contacts`. Verify each contact's authority with
the organization before adding it. Removing an allowlist entry stops future
automatic approvals. Revoke an existing approval separately.

Reviewers call the Supabase RPCs with their own signed-in sessions:

- `organizer_review_queue()` lists verified requests awaiting review.
  Supply `application_status: 'approved'` to find approvals eligible for
  revocation. For the next page, pass the last row's `created_at` and `id`
  as `before_created_at` and `before_id`.
- `organizer_review_application` takes `application_id`, `decision`
  (`approved`, `rejected`, or `revoked`) and an optional `note` visible
  to the applicant. Reviewers must independently confirm publishing authority.
  A reviewer cannot manually decide their own application. Approval and
  revocation update the organization assignment in the same transaction.
  Reapplications after rejection or revocation go through manual review.
- Trusted directory operators review `public.organizer_directory_requests`
  in the database. Check for an existing group first. If the organization is
  recognized and missing, add it through the existing directory process and
  record `reviewed_at` and `reviewed_by`. Applicants then use the directory
  to submit a separate publishing request.

Codes expire after ten minutes and allow five verification attempts. Delivery
is limited to one request per minute and five per day per account, and ten per
day per normalized recipient. A delivery failure still consumes that send
attempt. An operator can periodically delete delivery-rate entries older than
one day and expired challenges. Keep application decisions for audit history.

Run the backend regression suite against a migrated local Supabase instance:

```sh
psql 'postgresql://postgres:postgres@127.0.0.1:54322/postgres' \
  -f supabase/tests/organizer_onboarding.sql
```

The Edge Function regression test uses mocked Auth, database, and email
responses. It sends no email and can run without a Supabase project.

```sh
deno check supabase/functions/organizer-verification/index.ts
deno test --allow-env=SUPABASE_URL,SUPABASE_PUBLISHABLE_KEYS,SUPABASE_SECRET_KEYS,SUPABASE_ANON_KEY,SUPABASE_SERVICE_ROLE_KEY,ORGANIZER_CODE_SECRET \
  supabase/functions/organizer-verification/handler_test.ts
```
