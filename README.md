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
3. Optionally load demo groups and events: run `supabase/seed.sql` in the SQL
   editor. It's generated from the in-app club catalog
   (`dart run tool/generate_seed.dart > supabase/seed.sql`), so group slugs
   match the app's club IDs. Event dates are relative to when you run it.
4. Enable email/password authentication in **Authentication → Providers**.
5. In **Authentication → URL Configuration**, configure the Site URL and redirect URLs if email confirmation is enabled.
6. Optionally disable email confirmation for immediate account login during development.

### What happens after login

`AuthGate` (in `lib/main.dart`) loads the user's `profiles` row:

- `onboarding_completed = false` → academic profile → interests (skippable)
  → clubs, then saves everything to `profiles` and opens the app.
- `onboarding_completed = true` → straight into the McMap app.

Saved in Supabase: academic profile and interests, name/bio/photo edits
(photos go to the `avatars` bucket under `<user id>/`), RSVPs, and
McGillians (follow requests to private profiles stay `requested`).
Still on-device only: club memberships, followed clubs, notification
opt-ins and the privacy settings. Those need tables of their own.

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

Onboarding and club management share `UserProfile`. Memberships are
self-reported and keyed by catalog ID. They start private with auto-RSVP off.
Hiding keeps the selection and opt-in. Removing drops both preferences for that club
and keeps prior event decisions. In the offline demo, profile data and
RSVPs are session-only; when signed in they're stored in Supabase (see above).

For authenticated integration, persist the profile and per-club preferences
under the verified user ID. The server must enforce profile and membership
visibility. Preserve explicit RSVP decisions, including cancellations, and
key RSVP writes uniquely by user and event. Keep automatic RSVPs private
unless server-side consent and authorization explicitly permit another audience.

The organizer publication contract needs stable event and catalog club IDs,
publication and start timestamps, cancellation state, and a server-verified
in-app RSVP eligibility signal. Trigger automation on new publications after
opt-in. Recheck membership, timing, restrictions, and existing decisions in the
same backend operation before creating a Going RSVP. The in-memory
`HomePage.publications` input demonstrates this behavior in tests. Demo
sample events are unlinked and there is no live publication source.

### Following, event updates, and profile previews

Following is independent of self-reported membership and uses the same
catalog IDs. The Following filter matches event club IDs and composes with
text search. The sample feed has no verified club IDs. Club details require
a published event with a future start timestamp for the upcoming list. Feed,
club details, and Profile share the same local RSVP decisions.

The owner-only Following page links to the in-app Event updates inbox.
(Unfollowing clears the club's notification opt-in.) Opt-ins default to off and
record their enable time. The inbox uses `HomePage.publications` and
deduplicates by event ID for the session. It is independent of auto-RSVP.
Production delivery needs persisted follow/opt-in records keyed by authenticated
user and catalog club IDs, an organizer publication source, recipient
authorization, and idempotent delivery keyed by user and event.

The private management list retains all memberships. The owner's Profile
presentation derives its displayed memberships from `showOnProfile`.
The read-only preview additionally gates that presentation on Profile privacy.
It omits RSVP history, private management controls, and the Following list.
The backend must independently authorize profile access and return only
memberships visible to the requesting user. The preview supplies no friend
authorization or public endpoint.

### Integrated student profile

Academic onboarding keeps Gabby's degree level, nullable major, year, and
Froshie rules. The optional club picker updates the same `UserProfile`
without changing those fields. Home keeps club relationships in that model
and keeps editable presentation fields, including image bytes, in Gabby's
`StudentProfile`. Suggestions read the live edited academic labels and
interests from the presentation. Friend requests and connections remain in
`SocialGraph` and are separate from follows. The original profile statistics
remain in place, with membership and following counts on a secondary row.
