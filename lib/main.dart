import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend/mcmap_backend.dart';
import 'backend/supabase_backend.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/onboarding/academic_info_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/welcome_back_page.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_scaffold.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  McMapBackend? backend;
  if (_supabaseUrl.isNotEmpty && _supabasePublishableKey.isNotEmpty) {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
    );
    backend = SupabaseBackend(Supabase.instance.client);
  }

  runApp(McMapApp(backend: backend));
}

/// With a [backend]: Supabase auth → onboarding (if incomplete) → McMap.
/// Without one: a setup notice with a way into the offline demo.
class McMapApp extends StatelessWidget {
  const McMapApp({super.key, this.backend});

  final McMapBackend? backend;

  @override
  Widget build(BuildContext context) {
    final backend = this.backend;
    final app = MaterialApp(
      title: 'McMap',
      debugShowCheckedModeBanner: false,
      theme: buildMcMapTheme(),
      home: backend == null
          ? const ConfigurationPage()
          : AuthGate(backend: backend),
      onGenerateRoute: (settings) {
        final email = settings.arguments is String
            ? settings.arguments as String
            : null;
        Route<void> login() => MaterialPageRoute<void>(
          builder: (_) => const LoginPage(),
          settings: const RouteSettings(name: '/login'),
        );

        switch (settings.name) {
          case '/welcome-back':
            if (email == null || email.isEmpty) return login();
            return MaterialPageRoute<void>(
              builder: (_) => WelcomeBackPage(email: email),
              settings: settings,
            );
          case '/onboarding':
            if (email == null || email.isEmpty) return login();
            return MaterialPageRoute<void>(
              builder: (_) => OnboardingPage(email: email),
              settings: settings,
            );
          case '/login':
            return login();
        }
        return null;
      },
    );
    return backend == null ? app : BackendScope(backend: backend, child: app);
  }
}

/// Signed out → login. Signed in → loads `profiles`, then onboarding if it
/// isn't finished, otherwise the McMap app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.backend});

  final McMapBackend backend;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSubscription;
  User? _user;
  Future<AccountProfile>? _account;

  @override
  void initState() {
    super.initState();
    _setUser(Supabase.instance.client.auth.currentUser);
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      final user = state.session?.user;
      if (mounted && user?.id != _user?.id) setState(() => _setUser(user));
    });
    widget.backend.profileRevision.addListener(_reload);
  }

  void _setUser(User? user) {
    _user = user;
    _account = user == null ? null : widget.backend.loadMyProfile();
  }

  void _reload() {
    if (mounted) setState(() => _setUser(_user));
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    widget.backend.profileRevision.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const LoginPage();
    return FutureBuilder(
      future: _account,
      builder: (context, snapshot) {
        if (snapshot.error case final error?) {
          return _ProfileError(
            error: error is ProfileLoadException
                ? error
                : ProfileLoadException(
                    ProfileLoadProblem.unknown,
                    error.toString(),
                  ),
            onRetry: _reload,
            onSignOut: widget.backend.signOut,
          );
        }
        final account = snapshot.data;
        if (account == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final academics = account.academics;
        if (academics == null) {
          return AcademicInfoPage(onSignOut: widget.backend.signOut);
        }
        return HomePage(
          key: ValueKey(account.id),
          profile: academics,
          account: account,
          backend: widget.backend,
        );
      },
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({
    required this.error,
    required this.onRetry,
    required this.onSignOut,
  });

  final ProfileLoadException error;
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (error.problem) {
      ProfileLoadProblem.network => (
        Icons.cloud_off_rounded,
        "Couldn't reach McMap",
        'Check your connection and try again.',
      ),
      ProfileLoadProblem.signedOut => (
        Icons.lock_clock_outlined,
        'Your session expired',
        'Sign in again to continue.',
      ),
      ProfileLoadProblem.databaseSetup => (
        Icons.build_circle_outlined,
        "McMap's database isn't fully set up",
        'Some tables or functions are missing. Run every file in '
            'supabase/migrations (in order) in the Supabase SQL editor, '
            'then try again.',
      ),
      ProfileLoadProblem.unknown => (
        Icons.error_outline_rounded,
        "Couldn't load your profile",
        'Something went wrong on our side. Try again in a moment.',
      ),
    };
    return AuthScaffold(
      icon: icon,
      title: title,
      subtitle: subtitle,
      children: [
        if (error.problem != ProfileLoadProblem.signedOut) ...[
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
          const SizedBox(height: 8),
        ],
        TextButton(
          onPressed: onSignOut,
          child: Text(
            error.problem == ProfileLoadProblem.signedOut
                ? 'Sign in again'
                : 'Sign out',
          ),
        ),
        // The real error, for whoever is running a debug build.
        if (kDebugMode) ...[
          const SizedBox(height: 16),
          SelectableText(
            error.detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: McMapColors.slate),
          ),
        ],
      ],
    );
  }
}

class ConfigurationPage extends StatelessWidget {
  const ConfigurationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      icon: Icons.warning_amber_rounded,
      title: 'Supabase configuration required',
      subtitle:
          'Run the app with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY '
          'passed using --dart-define.',
      children: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AcademicInfoPage()),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Explore the offline demo'),
        ),
        const SizedBox(height: 8),
        Text(
          'Demo data stays on this device and resets when the app restarts.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: McMapColors.slate),
        ),
      ],
    );
  }
}
