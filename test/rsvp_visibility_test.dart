import 'dart:async';
import 'dart:convert';

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
import 'package:mcmap/models/club_event.dart';
import 'package:mcmap/models/student_visibility.dart';
import 'package:mcmap/models/user_profile.dart';
import 'package:mcmap/pages/event_details_page.dart';
import 'package:mcmap/pages/home_page.dart';
import 'package:mcmap/pages/student/settings_page.dart';
import 'package:mcmap/social/mcgillian_widgets.dart';
import 'package:mcmap/social/social_graph.dart';
import 'package:mcmap/theme/app_theme.dart';
import 'package:mcmap/widgets/profile_stats.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_flow_test.dart' show FakeBackend;

ClubEvent _event(String id, String title, {int days = 2, bool off = false}) =>
    ClubEvent(
      id,
      title,
      'Test Society',
      '',
      'Leacock 132',
      startsAt: DateTime.now().add(Duration(days: days)),
      publishedAt: DateTime.now().subtract(const Duration(days: 9)),
      cancelled: off,
    );

class _Backend extends FakeBackend {
  int signOuts = 0;
  bool failSignOut = false;
  Completer<void>? visibilityGate;
  Completer<void>? addGate;

  @override
  Future<void> signOut() async {
    signOuts++;
    if (failSignOut) throw Exception('offline');
  }

  @override
  Future<void> setRsvpVisibility(StudentVisibility visibility) async {
    // Only the first save is slow.
    final gate = visibilityGate;
    visibilityGate = null;
    await gate?.future;
    await super.setRsvpVisibility(visibility);
  }

  @override
  Future<FriendStatus> addMcGillian(String profileId) async {
    await addGate?.future;
    return super.addMcGillian(profileId);
  }
}

Future<_Backend> _pumpHome(
  WidgetTester tester, {
  StudentVisibility? saved,
  _Backend? backend,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final used = backend ?? _Backend();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildMcMapTheme(),
      home: HomePage(
        profile: const UserProfile(
          degreeLevel: DegreeLevel.undergraduate,
          year: 'U1',
          faculty: 'Science',
          major: 'Biology',
        ),
        backend: used,
        account: saved == null
            ? const AccountProfile(id: 'me', handle: 'gab.a', fullName: 'Gab')
            : AccountProfile(
                id: 'me',
                handle: 'gab.a',
                fullName: 'Gab',
                rsvpVisibility: saved,
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return used;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

StudentVisibility? _selected(WidgetTester tester) => tester
    .widget<RadioGroup<StudentVisibility>>(
      find.byType(RadioGroup<StudentVisibility>),
    )
    .groupValue;

void main() {
  group('RSVP privacy', () {
    testWidgets('is public by default', (tester) async {
      final backend = await _pumpHome(tester);
      await _tap(tester, find.text('RSVP'));
      expect(backend.rsvpCalls.single, ('e1', StudentVisibility.public));
      await _tap(tester, find.byTooltip('Settings'));
      expect(_selected(tester), StudentVisibility.public);
      // Nothing was chosen, so there's nothing to save.
      expect(backend.visibilitySaves, isEmpty);
    });

    testWidgets("keeps the account's own choice", (tester) async {
      final backend = await _pumpHome(tester, saved: StudentVisibility.private);
      await _tap(tester, find.text('RSVP'));
      expect(backend.rsvpCalls.single, ('e1', StudentVisibility.private));
      await _tap(tester, find.byTooltip('Settings'));
      expect(_selected(tester), StudentVisibility.private);
    });

    testWidgets('is saved when changed, in order', (tester) async {
      final backend = await _pumpHome(tester);
      await _tap(tester, find.byTooltip('Settings'));
      final slow = backend.visibilityGate = Completer<void>();
      await _tap(tester, find.text('Private'));
      await _tap(tester, find.text('Friends'));
      expect(backend.visibilitySaves, isEmpty);
      slow.complete();
      await tester.pumpAndSettle();
      expect(backend.visibilitySaves, [
        StudentVisibility.private,
        StudentVisibility.friends,
      ]);
    });

    testWidgets('still applies this session if saving fails', (tester) async {
      final backend = await _pumpHome(tester);
      backend.failVisibility = true;
      await _tap(tester, find.byTooltip('Settings'));
      await _tap(tester, find.text('Private'));
      expect(
        find.textContaining("Couldn't save your RSVP privacy"),
        findsOneWidget,
      );
      expect(_selected(tester), StudentVisibility.private);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, find.text('RSVP'));
      expect(backend.rsvpCalls.single, ('e1', StudentVisibility.private));

      // And the next change is saved as usual.
      backend.failVisibility = false;
      await _tap(tester, find.byTooltip('Settings'));
      await _tap(tester, find.text('Friends'));
      expect(backend.visibilitySaves.last, StudentVisibility.friends);
    });
  });

  group('sign out', () {
    testWidgets('lives in Settings, not the app bar', (tester) async {
      final backend = await _pumpHome(tester);
      expect(find.byTooltip('Sign out'), findsNothing);
      expect(find.byIcon(Icons.logout_rounded), findsNothing);
      await _tap(tester, find.byTooltip('Settings'));
      expect(find.text('Signed in as @gab.a'), findsOneWidget);
      await _tap(tester, find.text('Sign out'));
      expect(backend.signOuts, 1);
      expect(find.byType(SettingsPage), findsNothing);
    });

    testWidgets('says so if it fails', (tester) async {
      final backend = _Backend()..failSignOut = true;
      await _pumpHome(tester, backend: backend);
      await _tap(tester, find.byTooltip('Settings'));
      await _tap(tester, find.text('Sign out'));
      expect(find.text("Couldn't sign out. Try again."), findsOneWidget);
      expect(find.byType(SettingsPage), findsOneWidget);
      backend.failSignOut = false;
      await _tap(tester, find.text('Sign out'));
      expect(find.byType(SettingsPage), findsNothing);
    });

    testWidgets('closes Settings over the login page', (tester) async {
      // As AuthGate does: the home page is replaced while Settings is open.
      final signedIn = ValueNotifier(true);
      addTearDown(signedIn.dispose);
      final visibility = ValueNotifier(StudentVisibility.public);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: signedIn,
            builder: (context, value, _) => Scaffold(
              body: value
                  ? TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SettingsPage(
                            rsvpVisibility: visibility,
                            onSignOut: () async {
                              signedIn.value = false;
                              visibility.dispose();
                            },
                          ),
                        ),
                      ),
                      child: const Text('open'),
                    )
                  : const Text('Login'),
            ),
          ),
        ),
      );
      await _tap(tester, find.text('open'));
      await _tap(tester, find.text('Sign out'));
      expect(find.text('Login'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is absent from the offline demo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: buildMcMapTheme(), home: const HomePage()),
      );
      await _tap(tester, find.byTooltip('Settings'));
      expect(find.text('Sign out'), findsNothing);
      expect(
        find.text('Demo: your choice resets when the app restarts.'),
        findsOneWidget,
      );
    });
  });

  group("a McGillian's events", () {
    Future<void> openPriya(WidgetTester tester) async {
      await _tap(tester, find.text('Profile'));
      await _tap(tester, find.text('McGillians'));
      await _tap(tester, find.text('Priya Server'));
      expect(find.byType(McGillianProfilePage), findsOneWidget);
    }

    Finder onPage(Finder finder) => find.descendant(
      of: find.byType(McGillianProfilePage),
      matching: finder,
    );

    testWidgets('are listed soonest first and open', (tester) async {
      final backend = _Backend();
      backend.rsvpsOf['p-priya'] = [
        _event('later', 'Winter Gala', days: 9),
        _event('soon', 'Pop-up Skating', days: 1),
        _event('past', 'Last Week', days: -3),
        _event('off', 'Called Off', off: true),
      ];
      await _pumpHome(tester, backend: backend);
      await openPriya(tester);
      expect(onPage(find.text('Going to')), findsOneWidget);
      expect(onPage(find.byType(ListTile)), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('Pop-up Skating')).dy,
        lessThan(tester.getTopLeft(find.text('Winter Gala')).dy),
      );
      expect(find.text('Last Week'), findsNothing);
      expect(find.text('Called Off'), findsNothing);
      expect(backend.rsvpsOfLoads, 1, reason: 'loading stats is not a reason');

      await _tap(tester, find.text('Pop-up Skating'));
      expect(find.byType(EventDetailsPage), findsOneWidget);
      await _tap(tester, find.text('RSVP').hitTestable());
      expect(backend.rsvpCalls.single, ('soon', StudentVisibility.public));
      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('say when there are none, or they fail to load', (
      tester,
    ) async {
      final backend = _Backend()..failRsvpsOf = true;
      await _pumpHome(tester, backend: backend);
      await openPriya(tester);
      final retry = find.text("Couldn't load their events. Try again");
      expect(retry, findsOneWidget);
      backend.failRsvpsOf = false;
      await _tap(tester, retry);
      expect(retry, findsNothing);
      expect(find.text('No upcoming events to show.'), findsOneWidget);
    });

    testWidgets('of a private profile wait until they accept', (tester) async {
      final graph = SocialGraph(following: const {});
      var loads = 0;
      graph.loadGoing = (_) async {
        loads++;
        return [_event('x', 'Secret Show')];
      };
      final daniel = graph.directory.singleWhere(
        (s) => s.handle == 'dan.okafor',
      );
      Widget page() => MaterialApp(
        theme: buildMcMapTheme(),
        home: McGillianProfilePage(graph: graph, student: daniel),
      );
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('Going to'), findsNothing);
      await _tap(tester, find.text('Add Friend'));
      expect(find.text('Requested'), findsOneWidget);
      expect(find.text('Going to'), findsNothing);
      expect(loads, 0);

      final accepted = SocialGraph(following: const {'dan.okafor'})
        ..loadGoing = graph.loadGoing;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMcMapTheme(),
          home: McGillianProfilePage(
            key: UniqueKey(),
            graph: accepted,
            student: daniel,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Secret Show'), findsOneWidget);
    });

    testWidgets('reload once following is saved', (tester) async {
      final backend = _Backend();
      await _pumpHome(tester, backend: backend);
      await openPriya(tester);
      expect(find.text('No upcoming events to show.'), findsOneWidget);
      // Friends-only RSVPs appear when you follow them.
      await _tap(tester, onPage(find.text('Following')));
      await _tap(tester, find.widgetWithText(FilledButton, 'Remove'));
      backend.addGate = Completer();
      await _tap(tester, onPage(find.text('Add Friend')));
      expect(find.text('Friends Only Night'), findsNothing);
      backend.rsvpsOf['p-priya'] = [_event('f', 'Friends Only Night')];
      backend.addGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Friends Only Night'), findsOneWidget);
    });

    testWidgets('come with up-to-date stats', (tester) async {
      final backend = _StatsBackend();
      await _pumpHome(tester, backend: backend);
      await openPriya(tester);
      final stats = {
        for (final stat in tester.widgetList<ProfileStat>(
          onPage(find.byType(ProfileStat)),
        ))
          stat.label: stat.value,
      };
      expect(stats, {'McGillians': 40, 'Events': 7, 'Clubs': 3});
    });

    testWidgets('show in the offline demo', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: buildMcMapTheme(), home: const HomePage()),
      );
      await _tap(tester, find.text('Profile'));
      await _tap(tester, find.text('McGillians'));
      await _tap(tester, find.text('Sofia Rossi'));
      expect(onPage(find.text('Board Game Night')), findsOneWidget);
      expect(onPage(find.text('Frosh Week Kickoff')), findsOneWidget);
    });
  });

  group('SupabaseBackend', () {
    late List<http.Request> requests;
    late Object? Function(http.Request request) reply;

    Future<SupabaseBackend> backend() async {
      requests = [];
      final client = SupabaseClient(
        'https://mcmap.test',
        'test-publishable-key',
        httpClient: MockClient((request) async {
          final auth = request.url.path == '/auth/v1/token';
          if (!auth) requests.add(request);
          return http.Response(
            jsonEncode(
              auth
                  ? {
                      'access_token': 'eyJhbGciOiJub25lIn0.e30.fake',
                      'refresh_token': 'r',
                      'token_type': 'bearer',
                      'user': {
                        'id': 'me',
                        'aud': 'authenticated',
                        'created_at': '2026-11-21T00:00:00Z',
                      },
                    }
                  : reply(request),
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(email: 'a@mcgill.ca', password: 'x');
      return SupabaseBackend(client);
    }

    Map<String, Object?> profile(Object? visibility) => {
      'id': 'me',
      'handle': 'gab.a',
      'full_name': 'Gab',
      'onboarding_completed': false,
      'rsvp_visibility': ?visibility,
    };

    test('reads the saved choice, public when there is none', () async {
      final supabase = await backend();
      for (final (saved, expected) in [
        (null, StudentVisibility.public),
        ('public', StudentVisibility.public),
        ('friends', StudentVisibility.friends),
        ('private', StudentVisibility.private),
        // Newer than this app: don't show more than was asked for.
        ('close_friends', StudentVisibility.private),
      ]) {
        reply = (_) => profile(saved);
        final account = await supabase.loadMyProfile();
        expect(account.rsvpVisibility, expected, reason: '$saved');
      }
    });

    test('saves the choice on this account only', () async {
      final supabase = await backend();
      reply = (_) => null;
      await supabase.setRsvpVisibility(StudentVisibility.friends);
      final request = requests.single;
      expect(request.method, 'PATCH');
      expect(request.url.path, '/rest/v1/profiles');
      expect(request.url.queryParameters, {'id': 'eq.me'});
      expect(jsonDecode(request.body), {'rsvp_visibility': 'friends'});
    });

    test("reads another student's events", () async {
      final supabase = await backend();
      reply = (_) => [
        {
          'event': {
            'id': 'e9',
            'title': 'Pop-up Skating',
            'starts_at': '2026-12-01T18:00:00Z',
            'groups': {'slug': 'ssmu', 'name': 'SSMU', 'type': 'society'},
          },
        },
      ];
      final events = await supabase.fetchRsvpsOf('p-priya');
      expect(events.single.title, 'Pop-up Skating');
      expect(events.single.club, 'SSMU');
      final url = requests.single.url;
      expect(url.path, '/rest/v1/event_rsvps');
      expect(url.queryParameters['profile_id'], 'eq.p-priya');
      expect(
        url.queryParameters['select'],
        'event:events!inner(*,groups(slug,name,avatar_url,type))',
      );
    });
  });
}

/// Connections come without stats, search results with them.
class _StatsBackend extends _Backend {
  @override
  Future<List<(McGillian, FriendStatus)>> fetchMyConnections() async => [
    (
      const McGillian(
        id: 'p-priya',
        name: 'Priya Server',
        handle: 'priya.s',
        faculty: 'Science',
        major: 'Computer Science',
        year: 'U2',
        mcgilliansCount: 0,
      ),
      FriendStatus.following,
    ),
  ];

  @override
  Future<List<McGillian>> searchMcGillians(String query) async => [
    const McGillian(
      id: 'p-priya',
      name: 'Priya Server',
      handle: 'priya.s',
      faculty: 'Science',
      major: 'Computer Science',
      year: 'U2',
      mcgilliansCount: 40,
      eventsCount: 7,
      clubsCount: 3,
    ),
  ];
}
