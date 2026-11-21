import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/welcome_back_page.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supabaseUrl.isNotEmpty && _supabasePublishableKey.isNotEmpty) {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
    );
  }

  runApp(const McMapApp());
}

class McMapApp extends StatelessWidget {
  const McMapApp({super.key});

  bool get _isConfigured =>
      _supabaseUrl.isNotEmpty && _supabasePublishableKey.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'McMap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F5A75)),
      ),
      home: _isConfigured ? const AuthGate() : const ConfigurationPage(),
      onGenerateRoute: (settings) {
        if (settings.name == '/welcome-back') {
          final email = settings.arguments is String
              ? settings.arguments as String
              : null;
          if (email == null || email.isEmpty) {
            return MaterialPageRoute<void>(
              builder: (_) => const LoginPage(),
              settings: const RouteSettings(name: '/login'),
            );
          }
          return MaterialPageRoute<void>(
            builder: (_) => WelcomeBackPage(email: email),
            settings: settings,
          );
        }

        if (settings.name == '/onboarding') {
          final email = settings.arguments is String
              ? settings.arguments as String
              : null;
          if (email == null || email.isEmpty) {
            return MaterialPageRoute<void>(
              builder: (_) => const LoginPage(),
              settings: const RouteSettings(name: '/login'),
            );
          }
          return MaterialPageRoute<void>(
            builder: (_) => OnboardingPage(email: email),
            settings: settings,
          );
        }

        if (settings.name == '/login') {
          return MaterialPageRoute<void>(
            builder: (_) => const LoginPage(),
            settings: settings,
          );
        }

        return null;
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSubscription;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = Supabase.instance.client.auth.currentUser;
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (mounted) {
        setState(() => _user = state.session?.user);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) return const LoginPage();
    return HomePage(user: user);
  }
}

class ConfigurationPage extends StatelessWidget {
  const ConfigurationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Supabase configuration required',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Run the app with SUPABASE_URL and '
                      'SUPABASE_PUBLISHABLE_KEY passed using --dart-define.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
