import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mcmap/backend/mcmap_backend.dart';
import 'package:mcmap/data/academics.dart';
import 'package:mcmap/models/club_event.dart';
import 'package:mcmap/models/friend_rsvps.dart';
import 'package:mcmap/models/student_visibility.dart';
import 'package:mcmap/models/user_profile.dart';
import 'package:mcmap/pages/all_events_page.dart';
import 'package:mcmap/pages/home_page.dart';
import 'package:mcmap/theme/app_theme.dart';
import 'package:mcmap/widgets/pull_to_refresh.dart';

import 'backend_flow_test.dart' show FakeBackend;

ClubEvent _event(String id, String title, {int days = 2}) => ClubEvent(
  id,
  title,
  'Test Society',
  '',
  'Leacock',
  clubId: 'test-$id',
  startsAt: DateTime.now().add(Duration(days: days)),
  publishedAt: DateTime.now().subtract(const Duration(days: 1)),
);

/// Can hold a load open, or fail it.
class _Backend extends FakeBackend {
  Completer<void>? gate;
  Completer<void>? saveGate;
  bool failEvents = false;
  int loads = 0;
  Map<String, StudentVisibility> rsvps = {};

  @override
  Future<List<ClubEvent>> fetchEvents() async {
    loads++;
    final snapshot = [...events];
    await gate?.future;
    if (failEvents) throw Exception('offline');
    return snapshot;
  }

  @override
  Future<Map<String, StudentVisibility>> fetchMyRsvps() async {
    final snapshot = {...rsvps};
    await gate?.future;
    return snapshot;
  }

  @override
  Future<void> setRsvp(String eventId, StudentVisibility? visibility) async {
    await saveGate?.future;
    await super.setRsvp(eventId, visibility);
    if (visibility == null) {
      rsvps.remove(eventId);
    } else {
      rsvps[eventId] = visibility;
    }
  }
}

Future<void> _pumpHome(WidgetTester tester, McMapBackend? backend) async {
  tester.view.physicalSize = const Size(500, 900);
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

Finder get _feed => find.byType(ListView).first;

Future<void> _pullDown(WidgetTester tester) async {
  await tester.fling(_feed, const Offset(0, 500), 1200);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('PullToRefresh', () {
    var refreshes = 0;
    Completer<void>? gate;

    Future<void> pump(
      WidgetTester tester, {
      int items = 40,
      ScrollPhysics physics = const ClampingScrollPhysics(),
    }) async {
      refreshes = 0;
      gate = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PullToRefresh(
              onRefresh: () async {
                refreshes++;
                await gate?.future;
              },
              child: ListView(
                physics: AlwaysScrollableScrollPhysics(parent: physics),
                children: [
                  for (var i = 0; i < items; i++)
                    SizedBox(height: 60, child: Text('Item $i')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Future<void> drag(
      WidgetTester tester,
      double dy, {
      PointerDeviceKind kind = PointerDeviceKind.touch,
    }) async {
      await tester.timedDrag(
        find.byType(ListView),
        Offset(0, dy),
        const Duration(milliseconds: 400),
        buttons: kPrimaryButton,
      );
      await tester.pumpAndSettle();
    }

    Future<void> toBottom(WidgetTester tester) async {
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
    }

    for (final physics in const [
      ClampingScrollPhysics(),
      BouncingScrollPhysics(),
    ]) {
      testWidgets('both ends, with ${physics.runtimeType}', (tester) async {
        await pump(tester, physics: physics);
        await drag(tester, 400);
        expect(refreshes, 1, reason: 'pulled down at the top');

        await drag(tester, -300);
        expect(refreshes, 1, reason: 'ordinary scrolling');

        await toBottom(tester);
        await drag(tester, 200);
        expect(refreshes, 1, reason: 'away from the bottom');

        await toBottom(tester);
        await drag(tester, -300);
        expect(refreshes, 2, reason: 'pulled up at the bottom');
      });

      testWidgets('small pulls do nothing, with ${physics.runtimeType}', (
        tester,
      ) async {
        await pump(tester, physics: physics);
        await drag(tester, 40);
        await toBottom(tester);
        await drag(tester, -40);
        expect(refreshes, 0);
      });

      testWidgets('a long drag that ends past the edge, with '
          '${physics.runtimeType}', (tester) async {
        await pump(tester, physics: physics);
        await drag(tester, -200);
        await drag(tester, 900);
        expect(refreshes, 1);
      });

      testWidgets('short lists, with ${physics.runtimeType}', (tester) async {
        await pump(tester, items: 2, physics: physics);
        await drag(tester, 400);
        expect(refreshes, 1);
        await drag(tester, -400);
        expect(refreshes, 2);
      });
    }

    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.windows,
    ]) {
      testWidgets('a comfortable pull is enough on ${platform.name}', (
        tester,
      ) async {
        var refreshes = 0;
        tester.view.physicalSize = const Size(390, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: PullToRefresh(
              onRefresh: () async => refreshes++,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < 40; i++)
                    SizedBox(height: 60, child: Text('Item $i')),
                ],
              ),
            ),
          ),
        );
        await drag(tester, 330);
        expect(refreshes, 1);
        await toBottom(tester);
        await drag(tester, -250);
        expect(refreshes, 2);
      });
    }

    testWidgets('changing your mind at the bottom', (tester) async {
      await pump(tester);
      await toBottom(tester);
      final gesture = await tester.startGesture(const Offset(400, 400));
      for (var i = 0; i < 15; i++) {
        await gesture.moveBy(const Offset(0, -12));
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (var i = 0; i < 15; i++) {
        await gesture.moveBy(const Offset(0, 12));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(refreshes, 0);
    });

    testWidgets('the mouse can drag too', (tester) async {
      await pump(tester);
      final mouse = await tester.startGesture(
        const Offset(400, 200),
        kind: PointerDeviceKind.mouse,
      );
      for (var i = 0; i < 20; i++) {
        await mouse.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await mouse.up();
      await tester.pumpAndSettle();
      expect(refreshes, 1);
    });

    Future<void> wheel(
      WidgetTester tester,
      double dy, {
      int events = 10,
      Duration start = Duration.zero,
    }) async {
      final pointer = TestPointer(1, PointerDeviceKind.trackpad);
      final at = tester.getCenter(find.byType(ListView));
      for (var i = 0; i < events; i++) {
        await tester.sendEventToBinding(
          pointer.hover(at).copyWith(kind: PointerDeviceKind.mouse),
        );
        await tester.sendEventToBinding(
          PointerScrollEvent(
            timeStamp: start + Duration(milliseconds: 16 * i),
            position: at,
            scrollDelta: Offset(0, dy),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets('a web trackpad, at either end', (tester) async {
      await pump(tester);
      await wheel(tester, -40, start: const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(refreshes, 1);

      await toBottom(tester);
      await wheel(tester, 40, start: const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(refreshes, 2);
    });

    testWidgets('not from momentum that only just reached the end', (
      tester,
    ) async {
      await pump(tester);
      await drag(tester, -150);
      await wheel(tester, -60, events: 30, start: const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(refreshes, 0);
    });

    testWidgets('one at a time, showing progress until it is done', (
      tester,
    ) async {
      await pump(tester);
      gate = Completer();
      await toBottom(tester);
      await tester.timedDrag(
        find.byType(ListView),
        const Offset(0, -300),
        const Duration(milliseconds: 400),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(refreshes, 1);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);

      await tester.timedDrag(
        find.byType(ListView),
        const Offset(0, -300),
        const Duration(milliseconds: 400),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(refreshes, 1);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);

      gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(RefreshProgressIndicator), findsNothing);
    });
  });

  group('the feed', () {
    testWidgets('picks up new, changed and removed events', (tester) async {
      final backend = _Backend();
      await _pumpHome(tester, backend);
      expect(find.text('Server Trivia Night'), findsOneWidget);
      final notificationLoads = backend.notificationRefreshes;
      final friendLoads = backend.friendRsvpLoads;

      backend.events
        ..clear()
        ..add(_event('e1', 'Server Trivia Night (moved)'))
        ..add(_event('e2', 'Pop-up Skating', days: 1));
      backend.friendRsvps = const {
        'e2': FriendRsvps(count: 2, friends: [RsvpFriend(name: 'Ana Lee')]),
      };
      await _pullDown(tester);
      await tester.pumpAndSettle();

      expect(find.text('Server Trivia Night'), findsNothing);
      expect(
        find.text('Server Trivia Night (moved)', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Pop-up Skating', skipOffstage: false), findsOneWidget);
      expect(
        find.text('2 McGillians going', skipOffstage: false),
        findsOneWidget,
      );
      expect(backend.friendRsvpLoads, friendLoads + 1);
      expect(backend.notificationRefreshes, greaterThan(notificationLoads));

      backend.events.clear();
      await _pullDown(tester);
      await tester.pumpAndSettle();
      expect(find.text('Pop-up Skating', skipOffstage: false), findsNothing);
    });

    testWidgets('stays on screen while refreshing', (tester) async {
      final backend = _Backend();
      await _pumpHome(tester, backend);
      backend.gate = Completer();
      await _pullDown(tester);
      expect(backend.loads, 2);
      expect(find.text('Server Trivia Night'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Pulling again doesn't start another.
      await _pullDown(tester);
      expect(backend.loads, 2);
      backend.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('stays on screen if it fails, and says so', (tester) async {
      final backend = _Backend();
      await _pumpHome(tester, backend);
      backend.failEvents = true;
      await _pullDown(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Server Trivia Night'), findsOneWidget);
      expect(
        find.text("Couldn't refresh. Check your connection and try again."),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      backend.failEvents = false;
      backend.events.add(_event('e2', 'Pop-up Skating', days: 1));
      await _pullDown(tester);
      await tester.pumpAndSettle();
      expect(find.text('Pop-up Skating', skipOffstage: false), findsOneWidget);
    });

    testWidgets('waits for the first load', (tester) async {
      final backend = _Backend()..gate = Completer();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMcMapTheme(),
          home: HomePage(backend: backend),
        ),
      );
      await tester.pump();
      await _pullDown(tester);
      expect(backend.loads, 1);
      backend.gate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Server Trivia Night', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('recovers when the first load failed', (tester) async {
      final backend = _Backend()..failEvents = true;
      await _pumpHome(tester, backend);
      expect(find.text('Server Trivia Night'), findsNothing);
      backend.failEvents = false;
      await _pullDown(tester);
      await tester.pumpAndSettle();
      expect(find.text('Server Trivia Night'), findsOneWidget);
    });

    testWidgets('keeps an RSVP made while refreshing', (tester) async {
      final backend = _Backend();
      await _pumpHome(tester, backend);
      backend.gate = Completer();
      await _pullDown(tester);
      await tester.ensureVisible(find.text('RSVP'));
      await tester.pump();
      await tester.tap(find.text('RSVP'));
      await tester.pump();
      expect(find.text('Cancel RSVP'), findsOneWidget);
      backend.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Cancel RSVP'), findsOneWidget);
    });

    testWidgets('keeps an RSVP whose save is still on its way', (tester) async {
      final backend = _Backend()..saveGate = Completer();
      await _pumpHome(tester, backend);
      await tester.ensureVisible(find.text('RSVP'));
      await tester.pump();
      await tester.tap(find.text('RSVP'));
      await tester.pump();
      await _pullDown(tester);
      await tester.pumpAndSettle();
      expect(backend.loads, 2);
      expect(find.text('Cancel RSVP', skipOffstage: false), findsWidgets);
      backend.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Cancel RSVP', skipOffstage: false), findsWidgets);
    });

    testWidgets('picks up an RSVP made on another device', (tester) async {
      final backend = _Backend();
      await _pumpHome(tester, backend);
      backend.rsvps['e1'] = StudentVisibility.public;
      // One whose event isn't listed anymore must not break the profile.
      backend.rsvps['gone'] = StudentVisibility.public;
      await _pullDown(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Going · Public', skipOffstage: false), findsOneWidget);
    });

    testWidgets('All campus events and Profile refresh too', (tester) async {
      final backend = _Backend();
      await _pumpHome(tester, backend);
      await tester.scrollUntilVisible(
        find.text('View All Events'),
        200,
        scrollable: find
            .descendant(of: _feed, matching: find.byType(Scrollable))
            .first,
      );
      await tester.tap(find.text('View All Events'));
      await tester.pumpAndSettle();
      backend.events.add(_event('e2', 'Pop-up Skating', days: 1));
      final page = find.byType(AllEventsPage);
      await tester.fling(
        find.descendant(of: page, matching: find.byType(ListView)),
        const Offset(0, 500),
        1200,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: page, matching: find.text('Pop-up Skating')),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      final loads = backend.loads;
      await tester.fling(
        find.byType(ListView).hitTestable(),
        const Offset(0, 500),
        1200,
      );
      await tester.pumpAndSettle();
      expect(backend.loads, loads + 1);
    });

    testWidgets('works in the offline demo', (tester) async {
      await _pumpHome(tester, null);
      await _pullDown(tester);
      await tester.pumpAndSettle();
      expect(find.text('Sample events'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
