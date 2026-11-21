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
