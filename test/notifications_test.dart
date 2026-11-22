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
import 'package:mcmap/models/app_notification.dart';
import 'package:mcmap/models/club_event.dart';
import 'package:mcmap/models/friend_rsvps.dart';
import 'package:mcmap/models/student_visibility.dart';
import 'package:mcmap/models/user_profile.dart';
import 'package:mcmap/pages/event_details_page.dart';
import 'package:mcmap/pages/home_page.dart';
import 'package:mcmap/services/notification_center.dart';
import 'package:mcmap/social/mcgillian_widgets.dart';
import 'package:mcmap/theme/app_theme.dart';
import 'package:mcmap/widgets/friend_rsvp_pill.dart';
import 'package:mcmap/widgets/notifications_drawer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_flow_test.dart' show FakeBackend;

final _now = DateTime.now();

AppNotification _notification(
  String id, {
  AppNotificationType type = AppNotificationType.newFollowedEvent,
  String eventId = 'e1',
  int friends = 0,
  bool read = false,
  Duration age = const Duration(hours: 1),
}) => AppNotification(
  id: id,
  type: type,
  eventId: eventId,
  groupName: 'Engineering Undergraduate Society',
  title: 'Title $id',
  body: 'Body $id',
  friendRsvpCount: friends,
  isRead: read,
  createdAt: _now.subtract(age),
);

Future<void> _pumpHome(WidgetTester tester, FakeBackend? backend) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
        backend: backend,
        account: backend == null
            ? null
            : const AccountProfile(id: 'me', handle: 'me', fullName: 'Me'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openBell(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Notifications'));
  await tester.pumpAndSettle();
}

Finder _inDrawer(Finder finder) =>
    find.descendant(of: find.byType(NotificationsDrawer), matching: finder);

Finder _card(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(Card)).first;

/// The unread count on the bell, or null without one.
String? _badge(WidgetTester tester) {
  final count = find.descendant(
    of: find.byTooltip('Notifications'),
    matching: find.byType(Text),
  );
  return count.evaluate().isEmpty ? null : tester.widget<Text>(count).data;
}

void main() {
  group('friend RSVP pill', () {
    Future<void> pump(WidgetTester tester, FriendRsvps rsvps) =>
        tester.pumpWidget(
          MaterialApp(
            theme: buildMcMapTheme(),
            home: Center(child: FriendRsvpPill(rsvps)),
          ),
        );

    testWidgets('counts one, several and none', (tester) async {
      await pump(
        tester,
        const FriendRsvps(count: 1, friends: [RsvpFriend(name: 'Ana Lee')]),
      );
      expect(find.text("Ana Lee RSVP'd for this event"), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);

      await pump(
        tester,
        const FriendRsvps(
          count: 5,
          friends: [
            RsvpFriend(name: 'Ana Lee'),
            RsvpFriend(name: 'Ben Roy'),
            RsvpFriend(name: 'Cam Wu'),
          ],
        ),
      );
      expect(
        find.text("Ana Lee, Ben Roy and 3 others RSVP'd for this event"),
        findsOneWidget,
      );
      expect(find.byType(CircleAvatar), findsNWidgets(3));

      await pump(tester, FriendRsvps.none);
      expect(find.byType(Text), findsNothing);
      expect(tester.getSize(find.byType(FriendRsvpPill)), Size.zero);
    });
  });

  group('friend RSVPs on events', () {
    testWidgets('show on the card and the details page', (tester) async {
      final backend = FakeBackend()
        ..friendRsvps = const {
          'e1': FriendRsvps(
            count: 2,
            friends: [RsvpFriend(name: 'Priya Server')],
          ),
        };
      await _pumpHome(tester, backend);
      expect(
        find.descendant(
          of: _card('Server Trivia Night'),
          matching: find.text("Priya Server and 1 other RSVP'd for this event"),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Server Trivia Night').first);
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailsPage), findsOneWidget);
      expect(
        find.text("Priya Server and 1 other RSVP'd for this event"),
        findsOneWidget,
      );
    });

    testWidgets(
      'same named friend is linked from feeds to the profile and event',
      (tester) async {
        const friend = RsvpFriend(name: 'Priya Server', profileId: 'p-priya');
        final backend = FakeBackend()
          ..follows['ssmu'] = null
          ..friendRsvps = const {
            'e1': FriendRsvps(count: 1, friends: [friend]),
          };
        backend.visibleProfileEvents['p-priya'] = [backend.events.single];
        await _pumpHome(tester, backend);

        final title = find.text('Server Trivia Night');
        Finder namedFriend() => find.descendant(
          of: _card('Server Trivia Night'),
          matching: find.text('Priya Server'),
        );
        Future<void> tap(Finder finder) async {
          await tester.ensureVisible(finder.first);
          await tester.tap(finder.first);
          await tester.pumpAndSettle();
        }

        expect(namedFriend(), findsOneWidget);

        await tap(find.text('View All Events'));
        expect(namedFriend(), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();

        await tap(find.widgetWithText(ChoiceChip, 'Following'));
        expect(namedFriend(), findsOneWidget);
        await tester.enterText(find.byType(SearchBar), 'trivia');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(namedFriend(), findsOneWidget);

        await tap(title);
        expect(find.byType(EventDetailsPage), findsOneWidget);
        await tap(find.text('Priya Server'));
        expect(find.byType(McGillianProfilePage), findsOneWidget);
        expect(find.text("Events they're going to"), findsOneWidget);
        expect(find.text('Priya Server'), findsOneWidget);
        expect(find.textContaining('SSMU Ballroom'), findsOneWidget);
        await tap(title);
        expect(find.byType(EventDetailsPage), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();

        backend.visibleProfileEvents.clear();
        await tap(find.byTooltip('Refresh visible events'));
        expect(title, findsNothing);
        expect(
          find.text('No upcoming RSVP events are visible to you.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'visible non-friends appear in event details without a friend count',
      (tester) async {
        final backend = FakeBackend()
          ..visibleAttendees['e1'] = const [
            RsvpFriend(name: 'Sam Private', profileId: 'p-sam'),
          ];
        await _pumpHome(tester, backend);
        expect(find.byType(FriendRsvpPill), findsNothing);
        await tester.tap(find.text('Server Trivia Night'));
        await tester.pumpAndSettle();
        expect(find.text('Visible attendees'), findsOneWidget);
        expect(find.text('Sam Private'), findsOneWidget);
        expect(find.byType(FriendRsvpPill), findsNothing);
      },
    );

    testWidgets('are hidden at zero and for past and cancelled events', (
      tester,
    ) async {
      const going = FriendRsvps(count: 2);
      final backend = FakeBackend()
        ..friendRsvps = const {'past': going, 'off': going};
      backend.events.addAll([
        ClubEvent(
          'past',
          'Past Night',
          'Club',
          '',
          'Arts',
          startsAt: _now.subtract(const Duration(hours: 1)),
        ),
        ClubEvent(
          'off',
          'Cancelled Night',
          'Club',
          '',
          'Arts',
          cancelled: true,
          startsAt: _now.add(const Duration(days: 1)),
        ),
      ]);
      await _pumpHome(tester, backend);
      expect(find.byType(FriendRsvpPill), findsNothing);
    });

    testWidgets('reload once a connection is saved', (tester) async {
      final backend = FakeBackend();
      await _pumpHome(tester, backend);
      final before = backend.friendRsvpLoads;
      backend.friendRsvps = const {'e1': FriendRsvps(count: 1)};
      await tester.enterText(find.byType(SearchBar), 'sam');
      await tester.pump(); // build starts the debounced server search
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(McGillianTile, 'Sam Private'),
          matching: find.text('Add Friend'),
        ),
      );
      await tester.pumpAndSettle();
      expect(backend.added, isNotEmpty);
      expect(backend.friendRsvpLoads, before + 1);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text("1 McGillian RSVP'd for this event"), findsOneWidget);
    });

    testWidgets('follow your connections in the offline demo', (tester) async {
      await _pumpHome(tester, null);
      Finder pill(String title) => find.descendant(
        of: _card(title),
        matching: find.byType(FriendRsvpPill),
      );
      expect(pill('Board Game Night'), findsOneWidget);
      expect(find.text('Maya Tremblay'), findsWidgets);
      expect(pill('Photo Walk'), findsNothing);
    });
  });

  group('RSVP deadline', () {
    ClubEvent event({
      Duration? deadline,
      Duration starts = const Duration(days: 2),
    }) => ClubEvent(
      'd1',
      'Formal',
      'EUS',
      '',
      'Arts',
      startsAt: _now.add(starts),
      rsvpDeadline: deadline == null ? null : _now.add(deadline),
    );

    test('closes RSVPs before the start', () {
      expect(event().canRsvpAt(_now), isTrue);
      expect(event(deadline: const Duration(hours: 1)).canRsvpAt(_now), isTrue);
      expect(
        event(deadline: const Duration(hours: -1)).canRsvpAt(_now),
        isFalse,
      );
      // A deadline can't keep RSVPs open past the start.
      expect(
        event(
          deadline: const Duration(hours: 1),
          starts: const Duration(hours: -1),
        ).canRsvpAt(_now),
        isFalse,
      );
    });

    testWidgets('is shown, then says RSVPs closed', (tester) async {
      Future<void> pump(ClubEvent event) => tester.pumpWidget(
        MaterialApp(
          theme: buildMcMapTheme(),
          home: EventDetailsPage(
            event: event,
            isGoing: false,
            canRsvp: event.canRsvpAt(DateTime.now()),
            onRsvp: () {},
          ),
        ),
      );
      await pump(event());
      expect(find.textContaining('RSVP by'), findsNothing);
      await pump(event(deadline: const Duration(hours: 5)));
      expect(find.textContaining('RSVP by'), findsOneWidget);
      expect(find.text('RSVP'), findsOneWidget);
      await pump(event(deadline: const Duration(hours: -5)));
      expect(find.text('RSVPs closed'), findsOneWidget);
      expect(find.text('RSVP'), findsNothing);
    });
  });

  group('bell and drawer', () {
    testWidgets('list unread and read, with friends in reminders only', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..friendRsvps = const {
          'e1': FriendRsvps(
            count: 4,
            friends: [
              RsvpFriend(name: 'Ana'),
              RsvpFriend(name: 'Ben'),
            ],
          ),
        }
        ..notifications = [
          _notification('a', friends: 3),
          _notification(
            'b',
            type: AppNotificationType.eventDeadlineSoon,
            friends: 1,
          ),
          _notification('c', read: true, age: const Duration(days: 2)),
          _notification(
            'd',
            type: AppNotificationType.eventDeadlineSoon,
            read: true,
          ),
        ];
      await _pumpHome(tester, backend);
      expect(backend.notificationRefreshes, 1);
      expect(_badge(tester), '2');

      await _openBell(tester);
      expect(_inDrawer(find.text('2 unread')), findsOneWidget);
      double y(String label) =>
          tester.getTopLeft(_inDrawer(find.text(label))).dy;
      expect(y('New'), lessThan(y('Title a')));
      expect(y('Title b'), lessThan(y('Earlier')));
      expect(y('Earlier'), lessThan(y('Title c')));
      // The drawer uses the inbox message, free of stale avatar identities.
      expect(_inDrawer(find.byType(FriendRsvpPill)), findsNothing);
      expect(_inDrawer(find.text('2 d ago')), findsOneWidget);
    });

    testWidgets('a tap marks it read and opens the event', (tester) async {
      final backend = FakeBackend()..notifications = [_notification('a')];
      await _pumpHome(tester, backend);
      await _openBell(tester);
      await tester.tap(_inDrawer(find.text('Title a')));
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailsPage), findsOneWidget);
      expect(find.text('Server Trivia Night'), findsOneWidget);
      expect(backend.readCalls, ['a']);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsDrawer), findsNothing);
      expect(_badge(tester), isNull);
    });

    testWidgets('opens events posted after the feed loaded', (tester) async {
      final backend = FakeBackend()
        ..notifications = [
          _notification('a', eventId: 'later'),
          _notification('b', eventId: 'gone'),
        ];
      backend.unlistedEvents.add(
        ClubEvent(
          'later',
          'Just Posted',
          'EUS',
          '',
          'McConnell',
          startsAt: _now.add(const Duration(days: 1)),
        ),
      );
      await _pumpHome(tester, backend);
      await _openBell(tester);
      await tester.tap(_inDrawer(find.text('Title a')));
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailsPage), findsOneWidget);
      expect(find.text('Just Posted'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _openBell(tester);
      await tester.tap(_inDrawer(find.text('Title b')));
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailsPage), findsNothing);
      expect(find.text('That event is no longer available.'), findsOneWidget);
    });

    testWidgets('mark all as read', (tester) async {
      final backend = FakeBackend()
        ..notifications = [_notification('a'), _notification('b')];
      await _pumpHome(tester, backend);
      await _openBell(tester);
      await tester.tap(_inDrawer(find.text('Mark all as read')));
      await tester.pumpAndSettle();
      expect(backend.readCalls, [null]);
      expect(_badge(tester), isNull);
      expect(_inDrawer(find.text('New')), findsNothing);
      expect(_inDrawer(find.text('Earlier')), findsOneWidget);
      expect(_inDrawer(find.text("You're all caught up")), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              _inDrawer(find.widgetWithText(TextButton, 'Mark all as read')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('a failed save goes back to unread and says so', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..notifications = [_notification('a'), _notification('b', read: true)]
        ..failMarkRead = true;
      await _pumpHome(tester, backend);
      await _openBell(tester);
      await tester.tap(_inDrawer(find.text('Mark all as read')));
      await tester.pumpAndSettle();
      expect(_badge(tester), '1');
      expect(
        find.text("Couldn't mark that as read. Try again."),
        findsOneWidget,
      );
    });

    testWidgets('new notifications arrive live', (tester) async {
      final backend = FakeBackend();
      await _pumpHome(tester, backend);
      expect(_badge(tester), isNull);
      backend.notifications = [_notification('a')];
      backend.notificationChanges
        ..add(null)
        ..add(null);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(_badge(tester), '1');
      // Signing out stops listening.
      await tester.pumpWidget(const SizedBox());
      expect(backend.notificationChanges.hasListener, isFalse);
    });

    testWidgets('a failed load offers to try again', (tester) async {
      final backend = FakeBackend()..failNotifications = true;
      await _pumpHome(tester, backend);
      await _openBell(tester);
      expect(find.text("Couldn't load notifications."), findsOneWidget);
      expect(find.text('No notifications yet'), findsNothing);
      backend
        ..failNotifications = false
        ..notifications = [_notification('a')];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load notifications."), findsNothing);
      expect(_inDrawer(find.text('Title a')), findsOneWidget);
    });

    testWidgets('empty', (tester) async {
      await _pumpHome(tester, FakeBackend());
      await _openBell(tester);
      expect(find.text('No notifications yet'), findsOneWidget);
    });

    testWidgets('fit a small phone with large text', (tester) async {
      final backend = FakeBackend()
        ..notifications = [
          for (var i = 0; i < 12; i++)
            _notification(
              '$i',
              type: AppNotificationType.eventDeadlineSoon,
              friends: 12,
            ),
        ];
      await _pumpHome(tester, backend);
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(_badge(tester), '12');
      await _openBell(tester);
      expect(tester.takeException(), isNull);
    });
  });

  test('a slow load cannot bring back what was just read', () async {
    final backend = FakeBackend()..notifications = [_notification('a')];
    final center = NotificationCenter.remote(backend);
    addTearDown(center.dispose);
    await center.start();
    final stale = [...backend.notifications];
    center.markRead(center.unread.single);
    await Future<void>.delayed(Duration.zero);
    backend.notifications = stale;
    await center.refresh();
    expect(center.unreadCount, 0);
  });

  test('notification ages', () {
    String age(Duration age) => notificationAge(_now.subtract(age), _now);
    expect(age(const Duration(seconds: 20)), 'Just now');
    // A server clock slightly ahead of the phone's.
    expect(age(const Duration(seconds: -20)), 'Just now');
    expect(age(const Duration(minutes: 59)), '59 min ago');
    expect(age(const Duration(hours: 23)), '23 h ago');
    expect(age(const Duration(days: 6)), '6 d ago');
    expect(age(const Duration(days: 15)), '2 wk ago');
  });

  group('SupabaseBackend', () {
    const me = '00000000-0000-4000-8000-000000000001';

    Future<(SupabaseBackend, List<http.Request>)> connect(
      (Object?, int) Function(http.Request request) reply,
    ) async {
      final requests = <http.Request>[];
      http.Response json(Object? body, int status, http.Request request) =>
          http.Response(
            jsonEncode(body),
            status,
            headers: {'content-type': 'application/json'},
            request: request,
          );
      final client = SupabaseClient(
        'https://mcmap.test',
        'test-publishable-key',
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/v1/token') {
            return json(
              {
                'access_token': 'eyJhbGciOiJub25lIn0.e30.fake',
                'refresh_token': 'test-refresh-token',
                'token_type': 'bearer',
                'user': {
                  'id': me,
                  'aud': 'authenticated',
                  'created_at': '2026-11-21T00:00:00Z',
                },
              },
              200,
              request,
            );
          }
          requests.add(request);
          final (body, status) = reply(request);
          return json(body, status, request);
        }),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'student@mcgill.ca',
        password: 'test-password',
      );
      return (SupabaseBackend(client), requests);
    }

    test('sets account privacy without a client-supplied user ID', () async {
      final (backend, requests) = await connect((_) => ('friends', 200));
      expect(
        await backend.setRsvpVisibility(StudentVisibility.friends),
        StudentVisibility.friends,
      );
      expect(requests.single.url.path, '/rest/v1/rpc/set_my_rsvp_visibility');
      expect(jsonDecode(requests.single.body), {'preference': 'friends'});
    });

    test('creates an RSVP without supplying visibility', () async {
      final (backend, requests) = await connect(
        (_) => ({'visibility': 'public'}, 200),
      );
      expect(
        await backend.setRsvp('e1', going: true),
        StudentVisibility.public,
      );
      expect(requests.single.url.path, '/rest/v1/event_rsvps');
      expect(jsonDecode(requests.single.body), {
        'event_id': 'e1',
        'profile_id': me,
      });
      expect(
        requests.single.headers['prefer'],
        contains('resolution=ignore-duplicates'),
      );
    });

    test('reads friend RSVPs', () async {
      final (backend, requests) = await connect(
        (_) => (
          [
            {
              'event_id': 'e1',
              'friend_rsvp_count': 4,
              'friend_rsvps': [
                {
                  'profile_id': 'dee-id',
                  'full_name': 'Dee',
                  'avatar_url': 'https://x/d.png',
                },
                {'full_name': ' ', 'avatar_url': null},
              ],
            },
          ],
          200,
        ),
      );
      final rsvps = await backend.fetchFriendRsvps();
      expect(requests.single.url.path, '/rest/v1/rpc/friend_rsvps');
      expect(rsvps['e1']!.count, 4);
      expect(
        [
          for (final f in rsvps['e1']!.friends)
            (f.profileId, f.name, f.avatarUrl),
        ],
        [('dee-id', 'Dee', 'https://x/d.png'), (null, '', null)],
      );
    });

    test('reads notifications and skips kinds it does not know', () async {
      Map<String, Object?> row(String type) => {
        'id': type,
        'user_id': me,
        'type': type,
        'event_id': 'e1',
        'group_id': 'g1',
        'title': 'T',
        'body': 'B',
        'friend_rsvp_count': 2,
        'is_read': false,
        'created_at': '2026-11-22T10:00:00+00:00',
        'group_name': 'EUS',
        'group_avatar_url': 'https://x/eus.png',
      };
      final (backend, requests) = await connect(
        (_) => ([row('event_deadline_soon'), row('something_new')], 200),
      );
      final item = (await backend.fetchNotifications()).single;
      expect(item.type, AppNotificationType.eventDeadlineSoon);
      expect(item.groupName, 'EUS');
      expect(item.groupAvatarUrl, 'https://x/eus.png');
      expect(item.friendRsvpCount, 2);
      expect(item.createdAt, DateTime.utc(2026, 11, 22, 10));
      expect(requests.single.url.path, '/rest/v1/notification_inbox');
      expect(requests.single.url.queryParameters['user_id'], 'eq.$me');
    });

    test('marks one or all read, for this account only', () async {
      final (backend, requests) = await connect((_) => (null, 200));
      await backend.markNotificationsRead(id: 'n1');
      await backend.markNotificationsRead();
      for (final request in requests) {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/rest/v1/notifications');
        expect(jsonDecode(request.body), {'is_read': true});
        expect(request.url.queryParameters['user_id'], 'eq.$me');
      }
      expect(requests.first.url.queryParameters['id'], 'eq.n1');
      expect(requests.last.url.queryParameters['is_read'], 'eq.false');
      expect(requests.last.url.queryParameters.containsKey('id'), isFalse);
    });

    test('stays quiet until the migration is run, not for other errors', () async {
      var code = '';
      var message = '';
      final (backend, _) = await connect(
        (_) => ({'code': code, 'message': message}, 404),
      );
      code = 'PGRST202';
      message =
          'Could not find the function public.friend_rsvps without parameters '
          'in the schema cache';
      expect(await backend.fetchFriendRsvps(), isEmpty);
      code = 'PGRST205';
      message =
          "Could not find the table 'public.notifications' in the schema cache";
      expect(await backend.fetchNotifications(), isEmpty);

      code = '42501';
      message = 'permission denied for table notifications';
      await expectLater(
        backend.fetchNotifications(),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        backend.fetchFriendRsvps(),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
