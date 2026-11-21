# McMap

A Flutter app with McGill email/password authentication powered by Supabase.

## Authentication behavior

- Only addresses ending in `@mcgill.ca` or a subdomain such as `@mail.mcgill.ca` are accepted.
- The app first asks for the McGill email on a separate scene.
- Existing accounts show a login password scene.
- New addresses show an account-creation onboarding scene.
- Supabase email confirmation settings determine whether the user can enter immediately or must confirm the address first.

The login checkbox selects whether the app presents confirmation-required behavior for the new account flow. Supabase itself controls whether email confirmation is enforced in Authentication → Providers → Email: Enable email confirmations. Disabling that server setting allows new sign-ups to receive an immediate session.

## Supabase setup

1. Create a Supabase project.
2. Apply `supabase/migrations/20261121000000_create_account_lookup.sql` through the Supabase SQL editor or migrations CLI.
3. Enable email/password authentication in **Authentication → Providers**.
4. In **Authentication → URL Configuration**, configure the Site URL and redirect URLs if email confirmation is enabled.
5. Optionally disable email confirmation for immediate account login during development.

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
