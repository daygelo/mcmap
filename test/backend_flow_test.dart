import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
// Supabase's injected test transport uses its transitive HTTP dependency.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mcmap/backend/mcmap_backend.dart';
import 'package:mcmap/backend/supabase_backend.dart';
import 'package:mcmap/data/academics.dart';
import 'package:mcmap/data/clubs.dart';
import 'package:mcmap/main.dart';
import 'package:mcmap/models/club_event.dart';
import 'package:mcmap/models/student_visibility.dart';
import 'package:mcmap/models/user_profile.dart';
import 'package:mcmap/pages/event_details_page.dart';
import 'package:mcmap/pages/home_page.dart';
import 'package:mcmap/pages/login_page.dart';
import 'package:mcmap/pages/onboarding/interests_page.dart';
import 'package:mcmap/pages/student/student_profile.dart';
import 'package:mcmap/social/mcgillian_widgets.dart';
import 'package:mcmap/social/social_graph.dart';
import 'package:mcmap/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-memory stand-in for Supabase that records what the app saved.
class FakeBackend implements McMapBackend {
  final _revision = ValueNotifier(0);
  UserProfile? savedOnboarding;
  StudentProfile? savedProfile;
  final rsvpCalls = <(String, StudentVisibility?)>[];
  final added = <String>[];
  final removed = <String>[];
  bool failRsvp = false;
  bool failFollowSave = false;
  Exception? followLoadError;
  Future<Map<String, DateTime?>> Function()? followLoader;
  int followWrites = 0;
  int autoRsvpWrites = 0;
  final follows = <String, DateTime?>{};
  List<PublishingGroup> publishingGroups = [];
  Completer<void>? publicationPending;
  int publicationCalls = 0;

  final events = [
    ClubEvent(
      'e1',
      'Server Trivia Night',
      'Students’ Society of McGill University (SSMU)',
      '',
      'SSMU Ballroom',
      clubId: 'ssmu',
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
    for (final id in profile.followedClubIds) {
      follows.putIfAbsent(id, () => null);
    }
    _revision.value++;
  }

  @override
  Future<Map<String, DateTime?>> fetchOrganizationFollows() async {
    if (followLoadError case final error?) throw error;
    return followLoader?.call() ?? {...follows};
  }

  @override
  Future<void> setOrganizationFollow(String id, bool following) async {
    followWrites++;
    if (failFollowSave) throw StateError('offline');
    if (following) {
      follows.putIfAbsent(id, () => null);
    } else {
      follows.remove(id);
    }
  }

  @override
  Future<Map<String, String>> fetchOrganizationNames() async => {
    'faculty-of-science': 'Faculty of Science',
  };

  @override
  Future<DateTime?> setOrganizationAutoRsvp(String id, bool enabled) async {
    autoRsvpWrites++;
    if (failFollowSave || !follows.containsKey(id)) {
      throw StateError('Cannot save preference');
    }
    return follows[id] = enabled ? DateTime.now() : null;
  }

  @override
  Future<void> updateProfile(StudentProfile profile) async {
    savedProfile = profile;
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes) async => 'https://x/a.png';

  @override
  Future<void> removeAvatar() async {}

  @override
  Future<List<ClubEvent>> fetchEvents() async => events;

  @override
  Future<List<PublishingGroup>> fetchPublishingGroups() async =>
      publishingGroups;

  @override
  Future<ClubEvent> publishEvent({
    required String eventId,
    required String groupId,
    required String title,
    required String description,
    required DateTime startsAt,
    DateTime? endsAt,
    required String location,
  }) async {
    publicationCalls++;
    final group = publishingGroups.singleWhere((group) => group.id == groupId);
    await publicationPending?.future;
    final event = ClubEvent(
      eventId,
      title,
      group.name,
      '',
      location,
      clubId: group.id,
      startsAt: startsAt,
      endsAt: endsAt,
      description: description,
    );
    events.add(event);
    return event;
  }

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

Future<FakeBackend> _pumpHome(
  WidgetTester tester, {
  List<PublishingGroup> publishingGroups = const [],
  FakeBackend? existingBackend,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final backend = (existingBackend ?? FakeBackend())
    ..publishingGroups = publishingGroups;
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

const _followingProfileId = '00000000-0000-4000-8000-000000000001';
const _missingFollowing = {
  'code': 'PGRST205',
  'message': "Could not find the table 'public.profile_organization_follows' in the schema cache",
  'details': null,
  'hint': null,
};

http.Response _jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Future<SupabaseBackend> _supabaseFollowing(
  http.Response Function() response,
) async {
  final client = SupabaseClient(
    'https://mcmap.test',
    'test-publishable-key',
    httpClient: MockClient((request) async {
      if (request.url.path == '/auth/v1/token') {
        return _jsonResponse({
          'access_token': 'eyJhbGciOiJub25lIn0.e30.fake',
          'refresh_token': 'test-refresh-token',
          'token_type': 'bearer',
          'user': {
            'id': _followingProfileId,
            'aud': 'authenticated',
            'created_at': '2026-11-21T00:00:00Z',
          },
        });
      }
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/profile_organization_follows');
      expect(request.url.queryParameters, {
        'select': 'follows',
        'profile_id': 'eq.$_followingProfileId',
      });
      final result = response();
      return http.Response(
        result.body,
        result.statusCode,
        headers: result.headers,
        request: request,
      );
    }),
  );
  addTearDown(client.dispose);
  await client.auth.signInWithPassword(
    email: 'student@mcgill.ca',
    password: 'test-password',
  );
  return SupabaseBackend(client);
}

void main() {
  test('only a missing Following table matches the Supabase fallback', () {
    const schemaCache = PostgrestException(
      code: 'PGRST205',
      message: "Could not find the table 'public.profile_organization_follows' in the schema cache",
    );
    const undefinedRelation = PostgrestException(
      code: '42P01',
      message: 'relation "public.profile_organization_follows" does not exist',
    );
    final matches = SupabaseBackend.isMissingOrganizationFollowsTable;
    expect(matches(schemaCache), isTrue);
    expect(matches(undefinedRelation), isTrue);
    for (final error in [
      const PostgrestException(
        code: 'PGRST205',
        message: "Could not find the table 'public.groups' in the schema cache",
      ),
      const PostgrestException(
        code: '42501',
        message: 'permission denied for table profile_organization_follows',
      ),
      const PostgrestException(code: 'PGRST301', message: 'JWT expired'),
      const PostgrestException(code: '503', message: 'network unavailable'),
    ]) {
      expect(matches(error), isFalse);
    }
  });

  test('Supabase Following maps a stored row and an empty result', () async {
    var payload = <Object>[
      {
        'follows': {
          'faculty-of-science': {
            'auto_rsvp_enabled_at': '2026-11-21T12:00:00Z',
          },
          'engineering-mcgill-robotics': <String, Object>{},
        },
      },
    ];
    final backend = await _supabaseFollowing(() => _jsonResponse(payload));
    expect(await backend.fetchOrganizationFollows(), {
      'faculty-of-science': DateTime.utc(2026, 11, 21, 12),
      'engineering-mcgill-robotics': null,
    });
    payload = [];
    expect(await backend.fetchOrganizationFollows(), isEmpty);
  });

  test(
    'Supabase Following preserves permission, auth and unrelated 404 errors',
    () async {
      var error = _missingFollowing;
      var status = 404;
      final backend = await _supabaseFollowing(
        () => _jsonResponse(error, status),
      );
      for (final (code, message, httpStatus) in [
        (
          '42501',
          'permission denied for table profile_organization_follows',
          403,
        ),
        ('PGRST301', 'JWT expired', 401),
        (
          'PGRST205',
          "Could not find the table 'public.groups' in the schema cache",
          404,
        ),
      ]) {
        error = {'code': code, 'message': message};
        status = httpStatus;
        await expectLater(
          backend.fetchOrganizationFollows(),
          throwsA(
            isA<PostgrestException>().having(
              (error) => error.code,
              'code',
              code,
            ),
          ),
        );
      }
    },
  );

  testWidgets(
    'missing Following storage keeps all organization edits session-only',
    (tester) async {
      var followReads = 0;
      final supabase = (await tester.runAsync(
        () => _supabaseFollowing(() {
          followReads++;
          return _jsonResponse(_missingFollowing, 404);
        }),
      ))!;
      final backend = FakeBackend()
        ..followLoader = supabase.fetchOrganizationFollows;
      await _pumpHome(tester, existingBackend: backend);

      Future<void> tap(String label) async {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      const notice =
          'Following and event preferences are temporary for this session.';
      final auto = find.widgetWithText(SwitchListTile, 'Auto-RSVP to events');
      final notifications = find.widgetWithText(
        SwitchListTile,
        'Notify me about new events',
      );
      await tap('Profile');
      await tap('0 Following');
      expect(find.text(notice), findsOneWidget);
      await tap('Browse Clubs');
      await tester.enterText(find.byType(SearchBar), 'robotics');
      await tester.pumpAndSettle();
      await tap('McGill Robotics');
      await tap('Follow');
      expect(find.widgetWithText(OutlinedButton, 'Following'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(auto).value, isFalse);
      expect(tester.widget<SwitchListTile>(notifications).value, isFalse);
      await tap('Auto-RSVP to events');
      await tap('Notify me about new events');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(auto).value, isTrue);
      expect(find.textContaining('Updates on'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap('1 Following');
      await tap('Unfollow');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap('0 Following');
      expect(find.text("You're not following any clubs yet."), findsOneWidget);
      expect(followReads, 1);
      expect(backend.followWrites, 0);
      expect(backend.autoRsvpWrites, 0);
      expect(backend.follows, isEmpty);
      // A new session uses Supabase again when the table is available.
      backend.followLoader = null;
      backend.follows['faculty-of-science'] = null;
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpHome(tester, existingBackend: backend);
      await tap('Profile');
      await tap('1 Following');
      expect(find.text('Faculty of Science'), findsOneWidget);
      expect(find.text(notice), findsNothing);
      await tap('Auto-RSVP to events');
      expect(backend.autoRsvpWrites, 1);
    },
  );

  testWidgets('a permission failure does not enable local organization edits', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..followLoadError = const PostgrestException(
        code: '42501',
        message: 'permission denied',
      );
    await _pumpHome(tester, existingBackend: backend);
    expect(
      find.textContaining("Couldn't load followed organizations"),
      findsOneWidget,
    );
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0 Following'));
    await tester.pumpAndSettle();
    expect(find.textContaining('temporary for this session'), findsNothing);
    await tester.tap(find.text('Browse Clubs'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchBar), 'robotics');
    await tester.pumpAndSettle();
    final row = find.widgetWithText(ListTile, 'McGill Robotics');
    final follow = find.descendant(of: row, matching: find.text('Follow'));
    await tester.tap(follow);
    await tester.pumpAndSettle();
    expect(follow, findsOneWidget);
    expect(backend.followWrites, 0);
  });

  testWidgets('students have Home, Map and Profile navigation', (tester) async {
    await _pumpHome(tester);
    expect(find.text('Create'), findsNothing);
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.text('Campus map is coming soon.'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Your profile'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchBar).hitTestable(), findsOneWidget);
  });

  testWidgets('organizers publish once for an assigned group', (tester) async {
    final backend = await _pumpHome(
      tester,
      publishingGroups: const [
        PublishingGroup(id: 'assigned-a', name: 'Assigned Organization A'),
        PublishingGroup(id: 'assigned-b', name: 'Assigned Organization B'),
      ],
    );
    backend.publicationPending = Completer<void>();
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(
      navigation.destinations.cast<NavigationDestination>().map(
        (item) => item.label,
      ),
      ['Home', 'Map', 'Create', 'Profile'],
    );

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    final publish = find.text('Publish event');
    await tester.tap(publish);
    await tester.pumpAndSettle();
    for (final error in [
      'Choose an authorized organization.',
      'Enter an event title.',
      'Enter a description.',
      'Choose a start date and time.',
      'Enter a location.',
    ]) {
      expect(find.text(error), findsOneWidget);
    }
    expect(backend.publicationCalls, 0);

    final organizations = find.byType(DropdownButtonFormField<String>);
    final selector = tester.widget<DropdownButtonFormField<String>>(
      organizations,
    );
    expect(
      tester
          .widget<DropdownButton<String>>(
            find.descendant(
              of: organizations,
              matching: find.byType(DropdownButton<String>),
            ),
          )
          .items!
          .map((item) => item.value),
      ['assigned-a', 'assigned-b'],
    );
    expect(selector.initialValue, isNull);
    await tester.tap(organizations);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assigned Organization B').last);
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '  Publisher Workshop  ');
    await tester.enterText(fields.at(1), 'A full workshop description.');
    await tester.enterText(fields.at(2), 'Leacock 132');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.tap(find.text('Choose start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Choose start'), findsNothing);

    await tester.tap(find.text('Choose end'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(publish);
    await tester.tap(publish);
    await tester.pump();
    expect(backend.publicationCalls, 1);
    expect(find.text('Publishing…'), findsOneWidget);

    backend.publicationPending!.complete();
    await tester.pumpAndSettle();
    final event = (await backend.fetchEvents()).last;
    expect(backend.events, hasLength(2));
    expect(event.clubId, 'assigned-b');
    expect(event.startsAt, isNotNull);
    expect(event.endsAt, event.startsAt);
    expect(event.title, 'Publisher Workshop');
    expect(
      tester.widget<EventDetailsPage>(find.byType(EventDetailsPage)).event.id,
      event.id,
    );
    expect(find.text('A full workshop description.'), findsOneWidget);
    expect(find.text('Event published.'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    final search = find.descendant(
      of: find.byType(SearchBar),
      matching: find.byType(EditableText),
    );
    await tester.enterText(search, 'Publisher Work');
    await tester.pumpAndSettle();
    expect(find.text('Publisher Workshop'), findsOneWidget);
  });

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
      await tester.enterText(find.byType(SearchBar), 'CSUS FYC');
      await tester.pumpAndSettle();
      await tester.tap(find.text('CSUS First-Year Council'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(backend.savedOnboarding, isNotNull);
      expect(backend.savedOnboarding!.year, 'U1');
      expect(backend.savedOnboarding!.isFroshie, isTrue);
      expect(backend.savedOnboarding!.interests, isEmpty);
      expect(backend.follows, {'csus-first-year-council': null});
      // Back to the gate, which reloads the profile and opens the app.
      expect(find.text('gate'), findsOneWidget);
      expect(backend.profileRevision.value, 1);
    });

    testWidgets(
      'persisted Following loads, preserves opt-ins and rolls back failed edits',
      (tester) async {
        final enabledAt = DateTime.utc(2026, 11, 20);
        final backend = FakeBackend()
          ..follows['csus-first-year-council'] = enabledAt;
        await _pumpHome(tester, existingBackend: backend);

        Future<void> tap(String label) async {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }

        await tap('Profile');
        await tap('1 Following');
        expect(find.text('CSUS First-Year Council'), findsOneWidget);
        await tap('Browse Clubs');
        await tester.enterText(find.byType(SearchBar), 'robotics');
        await tester.pumpAndSettle();
        final row = find.widgetWithText(ListTile, 'McGill Robotics');
        final follow = find.descendant(of: row, matching: find.text('Follow'));
        backend.failFollowSave = true;
        await tester.tap(follow);
        await tester.pumpAndSettle();
        expect(
          find.text("Couldn't update Following. Try again."),
          findsOneWidget,
        );
        expect(follow, findsOneWidget);
        expect(backend.follows, {'csus-first-year-council': enabledAt});

        backend.failFollowSave = false;
        await tester.tap(follow);
        await tester.pumpAndSettle();
        expect(backend.follows['csus-first-year-council'], enabledAt);
        expect(backend.follows, hasLength(2));

        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpHome(tester, existingBackend: backend);
        await tap('Profile');
        await tap('2 Following');
        expect(find.text('McGill Robotics'), findsOneWidget);
        expect(find.text('CSUS First-Year Council'), findsOneWidget);
      },
    );

    testWidgets('a followed faculty reloads its saved auto-RSVP preference', (
      tester,
    ) async {
      final backend = FakeBackend()..follows['faculty-of-science'] = null;
      await _pumpHome(tester, existingBackend: backend);

      Future<void> tap(String label) async {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      final autoRsvp = find.widgetWithText(
        SwitchListTile,
        'Auto-RSVP to events',
      );
      await tap('Profile');
      await tap('1 Following');
      expect(find.text('Faculty of Science'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(autoRsvp).value, isFalse);
      backend.failFollowSave = true;
      await tap('Auto-RSVP to events');
      expect(tester.widget<SwitchListTile>(autoRsvp).value, isFalse);
      expect(
        find.text("Couldn't save your auto-RSVP preference. Try again."),
        findsOneWidget,
      );
      backend.failFollowSave = false;
      await tap('Auto-RSVP to events');
      expect(backend.follows['faculty-of-science'], isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpHome(tester, existingBackend: backend);
      await tap('Profile');
      await tap('1 Following');
      expect(tester.widget<SwitchListTile>(autoRsvp).value, isTrue);
      await tap('Auto-RSVP to events');
      expect(backend.follows, {'faculty-of-science': null});
    });

    testWidgets('feed shows server events, not sample ones', (tester) async {
      await _pumpHome(tester);
      expect(find.text('Server Trivia Night'), findsOneWidget);
      expect(find.text('Board Game Night'), findsNothing);
      expect(find.text('Sample events'), findsNothing);
      expect(
        find.text('Teams of four, six rounds, prizes for the top three.'),
        findsOneWidget,
      );
      expect(find.text('AI SUMMARY'), findsNothing);
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
      expect(find.text('@gab.a'), findsNothing);
      expect(find.text('Gab A'), findsOneWidget);
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();
      final name = find.widgetWithText(TextFormField, 'Display name');
      await tester.enterText(name, '  Gabby A  ');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(backend.savedProfile?.name, 'Gabby A');
      expect(find.text('Gabby A'), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(SearchBar), 'sam');
      await tester.pump(); // build starts the debounced server search
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Sam Private'), findsOneWidget);
      expect(find.textContaining('@sam.p'), findsNothing);

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
