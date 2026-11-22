import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mcmap/backend/mcmap_backend.dart';
import 'package:mcmap/backend/supabase_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;
import 'package:mcmap/data/academics.dart';
import 'package:mcmap/data/auto_follow.dart';
import 'package:mcmap/data/clubs.dart';
import 'package:mcmap/main.dart';
import 'package:mcmap/models/club_event.dart';
import 'package:mcmap/models/student_visibility.dart';
import 'package:mcmap/models/user_profile.dart';
import 'package:mcmap/pages/home_page.dart';
import 'package:mcmap/pages/login_page.dart';
import 'package:mcmap/pages/onboarding/interests_page.dart';
import 'package:mcmap/pages/student/club_discovery.dart';
import 'package:mcmap/pages/student/student_profile.dart';
import 'package:mcmap/social/mcgillian_widgets.dart';
import 'package:mcmap/social/social_graph.dart';
import 'package:mcmap/theme/app_theme.dart';
import 'package:mcmap/widgets/mcmap_logo.dart';

/// In-memory stand-in for Supabase that records what the app saved.
class FakeBackend implements McMapBackend {
  final _revision = ValueNotifier(0);
  UserProfile? savedOnboarding;
  final rsvpCalls = <(String, StudentVisibility?)>[];
  final added = <String>[];
  final removed = <String>[];
  bool failRsvp = false;

  final events = [
    ClubEvent(
      'e1',
      'Server Trivia Night',
      'Students’ Society of McGill University (SSMU)',
      '',
      'SSMU Ballroom',
      clubId: 'mcgill-ssmu',
      startsAt: DateTime.now().add(const Duration(days: 2)),
      publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      synopsis: 'Teams of four, six rounds, prizes for the top three.',
      supportsUnrestrictedRsvp: true,
    ),
  ];

  static const priya = McGillian(
    id: 'p-priya',
    name: 'Priya Server',
    handle: 'priya.s',
    faculty: 'Science',
    major: 'Computer Science',
    year: 'U2',
    mcgilliansCount: 40,
  );
  static const sam = McGillian(
    id: 'p-sam',
    name: 'Sam Private',
    handle: 'sam.p',
    faculty: 'Arts',
    major: 'History',
    year: 'U3',
    isPrivate: true,
    mcgilliansCount: 8,
  );

  @override
  ValueListenable<int> get profileRevision => _revision;

  @override
  Future<AccountProfile> loadMyProfile() async =>
      const AccountProfile(id: 'me', handle: 'me', fullName: 'Me');

  @override
  Future<void> completeOnboarding(UserProfile profile) async {
    savedOnboarding = profile;
    _revision.value++;
  }

  @override
  Future<void> updateProfile(StudentProfile profile) async {}

  @override
  Future<String> uploadAvatar(Uint8List bytes) async => 'https://x/a.png';

  @override
  Future<void> removeAvatar() async {}

  @override
  Future<List<ClubEvent>> fetchEvents() async => events;

  @override
  Future<Map<String, StudentVisibility>> fetchMyRsvps() async => {};

  @override
  Future<void> setRsvp(String eventId, StudentVisibility? visibility) async {
    rsvpCalls.add((eventId, visibility));
    if (failRsvp) throw Exception('offline');
  }

  @override
  Future<List<McGillian>> searchMcGillians(String query) async => [
    for (final s in [priya, sam])
      if (s.matches(query)) s,
  ];

  @override
  Future<List<(McGillian, FriendStatus)>> fetchMyConnections() async => [
    (priya, FriendStatus.following),
  ];

  @override
  Future<FriendStatus> addMcGillian(String profileId) async {
    added.add(profileId);
    return profileId == sam.id
        ? FriendStatus.requested
        : FriendStatus.following;
  }

  @override
  Future<void> removeMcGillian(String profileId) async =>
      removed.add(profileId);

  final clubCalls = <String>[];

  @override
  Future<void> setClubFollow(String clubId, {required bool following}) async =>
      clubCalls.add('${following ? 'follow' : 'unfollow'} $clubId');

  @override
  Future<void> setClubNotifications(String clubId, DateTime? enabledAt) async =>
      clubCalls.add('notify ${enabledAt != null} $clubId');

  @override
  Future<void> saveClubMembership(
    String clubId,
    ClubMembership? membership,
  ) async =>
      clubCalls.add('${membership == null ? 'leave' : 'member'} $clubId');

  @override
  Future<void> signOut() async {}
}

const _profile = UserProfile(
  degreeLevel: DegreeLevel.undergraduate,
  year: 'U1',
  firstYearAtMcGill: true,
  faculty: 'Science',
  major: 'Biology',
);

Future<FakeBackend> _pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final backend = FakeBackend();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildMcMapTheme(),
      home: HomePage(
        profile: _profile,
        backend: backend,
        account: const AccountProfile(
          id: 'me',
          handle: 'gab.a',
          fullName: 'Gab A',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return backend;
}

void main() {
  group('main auth (restyled)', () {
    testWidgets('shows configuration guidance without credentials', (
      tester,
    ) async {
      await tester.pumpWidget(const McMapApp());
      expect(find.text('Supabase configuration required'), findsOneWidget);
      expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
    });

    testWidgets('login starts with only the McGill email field', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: buildMcMapTheme(), home: const LoginPage()),
      );
      expect(find.text('Welcome to McMap'), findsOneWidget);
      expect(find.byType(McMapLogo), findsOneWidget);
      expect(find.byKey(const Key('email-field')), findsOneWidget);
      expect(
        find.byKey(const Key('email-confirmation-checkbox')),
        findsNothing,
      );
    });

    testWidgets('rejects non-McGill emails before calling Supabase', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: buildMcMapTheme(), home: const LoginPage()),
      );
      await tester.enterText(
        find.byKey(const Key('email-field')),
        'someone@gmail.com',
      );
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.textContaining('@mcgill.ca'), findsOneWidget);
    });

    test('accepts McGill email domains', () {
      expect(isMcGillEmail('student@mcgill.ca'), isTrue);
      expect(isMcGillEmail('student@mail.mcgill.ca'), isTrue);
      expect(isMcGillEmail('student@example.com'), isFalse);
    });

    test('creates a default name from a McGill email', () {
      expect(
        defaultNameFromEmail('angela.morin@mail.mcgill.ca'),
        'Angela Morin',
      );
    });
  });

  test('every catalog club id is a valid groups.slug', () {
    // Must match groups_slug_check, or supabase/seed.sql fails to load.
    final slug = RegExp(r'^[a-z0-9%-]+$');
    expect(
      clubCatalog.where((c) => !slug.hasMatch(c.id)).map((c) => c.id),
      isEmpty,
    );
  });

  group('automatic follows', () {
    Set<String> follows(UserProfile p) => applyAutoFollows(p).followedClubIds;
    Set<String> members(UserProfile p) =>
        applyAutoFollows(p).memberships.keys.toSet();

    test('every rule points at a catalog club', () {
      expect(
        autoFollowRules
            .map((r) => r.clubId)
            .where((id) => !clubsById.containsKey(id)),
        isEmpty,
      );
      expect(
        {
          ...campusSocietyIds,
          ...facultyAssociationIds,
        }.where((id) => !clubsById.containsKey(id)),
        isEmpty,
      );
    });

    test('U0 Engineering: SSMU, EUS and both First-Year Councils', () {
      const p = UserProfile(
        degreeLevel: DegreeLevel.undergraduate,
        year: 'U0',
        faculty: 'Engineering',
        major: undeclaredMajor,
      );
      expect(follows(p), {
        'mcgill-ssmu',
        'engineering-engineering-undergraduate-society-eus',
        'ssmu-first-year-council',
        'eus-junior-council',
      });
      // Councils are followed, not joined.
      expect(members(p), {
        'mcgill-ssmu',
        'engineering-engineering-undergraduate-society-eus',
      });
    });

    test('first-year U1 gets the council; returning U1 does not', () {
      const firstYear = UserProfile(
        degreeLevel: DegreeLevel.undergraduate,
        year: 'U1',
        firstYearAtMcGill: true,
        faculty: 'Arts',
        major: 'History',
      );
      expect(follows(firstYear), {
        'mcgill-ssmu',
        'mcgill-aus',
        'ssmu-first-year-council',
        'aus-fearc',
      });
      const returning = UserProfile(
        degreeLevel: DegreeLevel.undergraduate,
        year: 'U1',
        faculty: 'Arts',
        major: 'History',
      );
      expect(follows(returning), {'mcgill-ssmu', 'mcgill-aus'});
    });

    test('campus society depends on campus and degree', () {
      expect(
        follows(
          const UserProfile(
            degreeLevel: DegreeLevel.masters,
            faculty: 'Science',
            major: 'Biology',
          ),
        ),
        {'mcgill-pgss'},
      );
      expect(
        follows(
          const UserProfile(
            degreeLevel: DegreeLevel.undergraduate,
            year: 'U2',
            faculty: 'Agricultural & Environmental Sciences',
            major: 'Animal Science',
          ),
        ),
        {'mcgill-mcss'},
      );
      expect(
        follows(
          const UserProfile(
            degreeLevel: DegreeLevel.exchangeOrContinuing,
            faculty: 'Continuing Studies',
          ),
        ),
        {'mcgill-maces'},
      );
      expect(
        follows(
          const UserProfile(
            degreeLevel: DegreeLevel.professional,
            faculty: 'Law',
            major: 'BCL/JD',
          ),
        ),
        {'mcgill-ssmu', 'mcgill-lsa'},
      );
    });

    test('keeps clubs picked during onboarding', () {
      final p = const UserProfile(
        degreeLevel: DegreeLevel.undergraduate,
        year: 'U3',
        faculty: 'Science',
        major: 'Biology',
      ).withClubIds({'ssmu-mcgill-e-sports-students-society'});
      expect(members(p), {
        'ssmu-mcgill-e-sports-students-society',
        'mcgill-ssmu',
        'mcgill-sus',
      });
    });
  });

  group('profile load errors', () {
    ProfileLoadProblem kind(Object e) =>
        SupabaseBackend.describeLoadError(e).problem;

    test('missing tables, functions or rules mean setup, not network', () {
      for (final code in ['PGRST205', '42P01', 'PGRST202', '42883', '42501']) {
        expect(
          kind(PostgrestException(message: 'x', code: code)),
          ProfileLoadProblem.databaseSetup,
          reason: code,
        );
      }
    });

    test('expired sessions and auth errors mean signed out', () {
      expect(
        kind(
          const PostgrestException(message: 'JWT expired', code: 'PGRST303'),
        ),
        ProfileLoadProblem.signedOut,
      );
      expect(kind(const AuthException('nope')), ProfileLoadProblem.signedOut);
    });

    test('only real connection failures blame the connection', () {
      expect(
        kind(Exception('ClientException: Failed to fetch')),
        ProfileLoadProblem.network,
      );
      expect(
        kind(const PostgrestException(message: 'boom', code: 'XX000')),
        ProfileLoadProblem.unknown,
      );
    });
  });

  group('database value mapping', () {
    test('U4+ and degree levels round-trip', () {
      expect(uYearToDb('U4+'), 'U4_plus');
      expect(uYearFromDb('U4_plus'), 'U4+');
      expect(uYearFromDb('U1'), 'U1');
      for (final level in DegreeLevel.values) {
        expect(degreeLevelFromDb(degreeLevelDbValues[level]), level);
      }
      expect(
        degreeLevelDbValues[DegreeLevel.exchangeOrContinuing],
        'exchange_continuing',
      );
    });

    test('Edit Profile standing maps back to degree + U-year', () {
      expect(standingToDb('U2'), (DegreeLevel.undergraduate, 'U2'));
      expect(standingToDb('Ph.D.'), (DegreeLevel.doctorate, null));
      expect(standingToDb("Master's"), (DegreeLevel.masters, null));
    });
  });

  group('with a backend', () {
    testWidgets('finishing onboarding saves to the backend', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final backend = FakeBackend();
      await tester.pumpWidget(
        BackendScope(
          backend: backend,
          child: MaterialApp(
            theme: buildMcMapTheme(),
            home: const Scaffold(body: Text('gate')),
          ),
        ),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const InterestsPage(profile: _profile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      // Club picker (step 3): skip it too.
      await tester.tap(find.textContaining('Skip').last);
      await tester.pumpAndSettle();

      expect(backend.savedOnboarding, isNotNull);
      expect(backend.savedOnboarding!.year, 'U1');
      expect(backend.savedOnboarding!.isFroshie, isTrue);
      expect(backend.savedOnboarding!.interests, isEmpty);
      // Back to the gate, which reloads the profile and opens the app.
      expect(find.text('gate'), findsOneWidget);
      expect(backend.profileRevision.value, 1);
    });

    testWidgets('following a club is saved to the backend', (tester) async {
      final backend = await _pumpHome(tester);
      await tester.enterText(find.byType(SearchBar), 'esports');
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(ClubRow),
              matching: find.byType(FollowClubButton),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(backend.clubCalls, [
        'follow ssmu-mcgill-e-sports-students-society',
      ]);
    });

    testWidgets('auto-followed clubs from the server show on Profile', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMcMapTheme(),
          home: HomePage(
            backend: FakeBackend(),
            profile: applyAutoFollows(_profile),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // SSMU is auto-followed, so its event sits in the followed section,
      // above the suggestions.
      expect(
        tester.getTopLeft(find.text('Server Trivia Night')).dy,
        lessThan(tester.getTopLeft(find.text('Suggested events')).dy),
      );
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      // U1 first-year Science: SSMU, SUS, SSMU FYC, FUSS.
      expect(find.text('4 Following'), findsOneWidget);
      expect(find.text('2 Club Memberships'), findsOneWidget);
    });

    testWidgets('feed shows server events, not sample ones', (tester) async {
      await _pumpHome(tester);
      expect(find.text('Server Trivia Night'), findsOneWidget);
      expect(find.text('Board Game Night'), findsNothing);
      expect(find.text('Sample events'), findsNothing);
      expect(find.text('AI SUMMARY'), findsOneWidget);
    });

    testWidgets('RSVPs are saved and rolled back on failure', (tester) async {
      final backend = await _pumpHome(tester);
      await tester.tap(find.text('RSVP'));
      await tester.pumpAndSettle();
      expect(backend.rsvpCalls.single, ('e1', StudentVisibility.private));
      expect(find.text('Cancel RSVP'), findsOneWidget);

      backend.failRsvp = true;
      await tester.tap(find.text('Cancel RSVP'));
      await tester.pumpAndSettle();
      expect(backend.rsvpCalls.last, ('e1', null));
      // Failed to save, so it's still RSVPed.
      expect(find.text('Cancel RSVP'), findsOneWidget);
      expect(find.textContaining("Couldn't save your RSVP"), findsOneWidget);
    });

    testWidgets('McGillians come from the server and sync changes', (
      tester,
    ) async {
      final backend = await _pumpHome(tester);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('@gab.a'), findsOneWidget);
      expect(find.text('Gab A'), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(SearchBar), 'sam');
      await tester.pump(); // build starts the debounced server search
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Sam Private'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(McGillianTile, 'Sam Private'),
          matching: find.text('Add Friend'),
        ),
      );
      await tester.pumpAndSettle();
      expect(backend.added, ['p-sam']);
      expect(
        find.descendant(
          of: find.widgetWithText(McGillianTile, 'Sam Private'),
          matching: find.text('Requested'),
        ),
        findsOneWidget,
      );
    });
  });
}
