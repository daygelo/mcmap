# McMap

A Flutter app with Microsoft authentication powered by Supabase.

## Supabase setup

1. Create a Supabase project.
2. Enable the Microsoft/Azure auth provider and enter the Microsoft Entra application client ID and secret.
3. In Supabase, open **Authentication → URL Configuration**.
4. Add `io.mcmap.app://login-callback` to **Additional Redirect URLs**.
5. Add your web local and production origins. For example:
   - `http://localhost:3000/**`
   - `https://your-domain.example/**`

Then run the app with compile-time credentials:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Use the same options for Android, iOS, or Linux:

```bash
flutter run -d linux \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Never use or commit a Supabase service-role key. The publishable/anon key is intended for client applications.

## Microsoft setup

In Microsoft Entra ID, register a web application and add the Supabase callback URL supplied by the Supabase Microsoft provider settings. Add any required Microsoft redirect URLs to Supabase after the provider is enabled.

Native Android and iOS builds use `io.mcmap.app://login-callback`. The schemes are registered in:

- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

Web authentication uses the current web origin and should therefore be allowlisted in Supabase URL configuration.

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
and keeps prior event decisions. Profile data and RSVPs are session-only.

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
