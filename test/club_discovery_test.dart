import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mcmap/data/clubs.dart';
import 'package:mcmap/models/club_event.dart';
import 'package:mcmap/models/user_profile.dart';
import 'package:mcmap/models/student_visibility.dart';
import 'package:mcmap/pages/home_page.dart';
import 'package:mcmap/pages/student/club_discovery.dart';
import 'package:mcmap/pages/student/suggested_clubs.dart';
import 'package:mcmap/theme/app_theme.dart';

const _esportsId = 'ssmu-mcgill-e-sports-students-society';
const _boardGamesId = 'ssmu-mcgill-board-game-students-society';
String _name(String id) => clubsById[id]!.name;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder.hitTestable());
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String label) =>
    _tap(tester, find.text(label));

Future<void> _back(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(SearchBar).hitTestable(), query);
  await tester.pumpAndSettle();
}

Future<void> _start(
  WidgetTester tester, {
  Map<String, ClubMembership> memberships = const {},
  Set<String> followed = const {},
  Set<String> interests = const {},
  Stream<ClubEvent>? publications,
}) async {
  await tester.binding.setSurfaceSize(const Size(700, 1450));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildMcMapTheme(),
      home: HomePage(
        profile: UserProfile(
          faculty: 'Engineering',
          major: 'Software Engineering',
          year: 'U2',
          memberships: memberships,
          followedClubIds: followed,
          interests: interests,
        ),
        publications: publications,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ClubEvent _published(String id, String clubId, String title, {DateTime? at}) {
  final now = DateTime.now();
  return ClubEvent(
    id,
    title,
    _name(clubId),
    'Tomorrow',
    'Campus',
    clubId: clubId,
    publishedAt: at ?? now,
    startsAt: now.add(const Duration(days: 1)),
    supportsUnrestrictedRsvp: true,
  );
}

Finder _eventCard(String title) => find
    .ancestor(of: find.text(title), matching: find.byType(Card))
    .hitTestable();

void main() {
  testWidgets(
    'suggestions follow immediately and replace one row after a second',
    (tester) async {
      await _start(tester, interests: {'Robotics'});
      final section = find.byType(SuggestedClubs);
      final rows = find.descendant(of: section, matching: find.byType(ClubRow));
      List<String> names() =>
          tester.widgetList<ClubRow>(rows).map((row) => row.club.name).toList();
      final original = names();
      expect(original, hasLength(3));
      expect(original.first, 'McGill Robotics');
      expect(
        tester.getBottomLeft(find.byType(SearchBar)).dy,
        lessThan(tester.getTopLeft(section).dy),
      );
      expect(
        tester.getBottomLeft(section).dy,
        lessThan(tester.getTopLeft(find.text('Club events')).dy),
      );
      await _search(tester, 'photo');
      expect(names(), original);
      await _search(tester, '');
      await _tapText(tester, 'See all clubs');
      expect(find.byType(ClubDirectoryPage), findsOneWidget);
      await _back(tester);
      await _tapText(tester, 'McGill Robotics');
      expect(find.byType(ClubDetailPage), findsOneWidget);
      expect(find.text('McGill Robotics'), findsOneWidget);
      await _back(tester);

      final robotics = find.widgetWithText(ClubRow, 'McGill Robotics');
      final follow = find.descendant(
        of: robotics,
        matching: find.text('Follow'),
      );
      await tester.tap(follow);
      await tester.pump();
      final confirmation = find.descendant(
        of: robotics,
        matching: find.widgetWithText(OutlinedButton, 'Following'),
      );
      expect(confirmation, findsOneWidget);
      expect(tester.widget<OutlinedButton>(confirmation).onPressed, isNull);
      expect(
        find.descendant(of: robotics, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      await tester.tap(confirmation);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(names(), original);
      await tester.tap(find.text('Profile'));
      await tester.pump();
      expect(find.text('1 Following').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 299));
      expect(names(), original);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      final updated = names();
      expect(updated, hasLength(3));
      expect(updated.toSet(), hasLength(3));
      expect(updated, isNot(contains('McGill Robotics')));
      expect(updated.skip(1), original.skip(1));

      await tester.tap(
        find.descendant(of: rows.first, matching: find.text('Follow')),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('suggestions show an empty state when there is no replacement', (
    tester,
  ) async {
    await _start(
      tester,
      followed: {
        for (final club in clubCatalog)
          if (club.name != 'McGill Robotics') club.id,
      },
    );
    final rows = find.descendant(
      of: find.byType(SuggestedClubs),
      matching: find.byType(ClubRow),
    );
    expect(rows, findsOneWidget);
    await _tap(
      tester,
      find.descendant(of: rows, matching: find.text('Follow')),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(rows, findsNothing);
    expect(find.text('No more club suggestions right now.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home exposes a working Follow button without changing filters', (
    tester,
  ) async {
    await _start(tester);
    await tester.binding.setSurfaceSize(const Size(390, 820));
    await tester.pumpAndSettle();
    await _tapText(tester, 'Browse Clubs');
    await _search(tester, 'McGill Robotics');
    final robotics = find.widgetWithText(ListTile, 'McGill Robotics');
    Finder button(String label) => find.descendant(
      of: robotics,
      matching: find.widgetWithText(OutlinedButton, label),
    );
    expect(
      tester.widget<OutlinedButton>(button('Follow')).onPressed,
      isNotNull,
    );
    await _tap(tester, button('Follow'));
    expect(button('Following').hitTestable(), findsOneWidget);
    expect(
      find.descendant(of: robotics, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    await _back(tester);
    final allEvents = find.widgetWithText(ChoiceChip, 'All Events');
    await tester.scrollUntilVisible(
      allEvents,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<ChoiceChip>(allEvents).selected, isTrue);
    await _tapText(tester, 'Profile');
    expect(find.text('0 Club Memberships'), findsOneWidget);
    expect(find.text('No memberships are shown on Profile.'), findsOneWidget);
    await _tapText(tester, '1 Following');
    expect(robotics.hitTestable(), findsOneWidget);
    await _tapText(tester, 'Unfollow');
    expect(robotics, findsNothing);
    expect(find.text("You're not following any clubs yet."), findsOneWidget);
    await _back(tester);
    expect(find.text('0 Following'), findsOneWidget);
    await _tapText(tester, '0 Following');
    await _tapText(tester, 'Browse Clubs');
    await _search(tester, 'McGill Robotics');
    expect(button('Follow').hitTestable(), findsOneWidget);
    final followLabel = find.descendant(
      of: button('Follow'),
      matching: find.text('Follow'),
    );
    expect(
      tester.widget<Text>(followLabel).semanticsLabel,
      'Follow McGill Robotics',
    );
    Focus.of(tester.element(followLabel)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(button('Following').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shows only revealed memberships and previews profile audiences',
    (tester) async {
      await _start(
        tester,
        memberships: {
          _esportsId: const ClubMembership(),
          _boardGamesId: const ClubMembership(),
        },
      );
      await _tapText(tester, 'Profile');
      expect(find.text(_name(_esportsId)).hitTestable(), findsNothing);
      await _tapText(tester, '2 Club Memberships');
      final visibility = find.widgetWithText(
        SwitchListTile,
        'Show membership on profile',
      );
      await _tap(tester, visibility.first);
      await _back(tester);
      expect(find.text(_name(_esportsId)).hitTestable(), findsOneWidget);
      expect(find.text(_name(_boardGamesId)).hitTestable(), findsNothing);
      await _tapText(tester, 'Preview Public Profile');
      expect(find.textContaining('Your profile is private'), findsOneWidget);
      expect(find.text(_name(_esportsId)), findsNothing);
      await _back(tester);

      await _tap(tester, find.byTooltip('Settings'));
      await _tap(
        tester,
        find.widgetWithText(RadioListTile<StudentVisibility>, 'Friends').last,
      );
      await _back(tester);
      await _tapText(tester, 'Preview Public Profile');
      expect(find.textContaining('permitted friends'), findsOneWidget);
      expect(find.text(_name(_esportsId)), findsOneWidget);
      expect(find.text(_name(_boardGamesId)), findsNothing);
      expect(find.text('Your RSVPs'), findsNothing);
      expect(find.text('0 Following'), findsNothing);
      expect(find.text("Auto-RSVP to this club's events"), findsNothing);
      await _back(tester);

      await _tap(tester, find.byTooltip('Settings'));
      await _tap(
        tester,
        find.widgetWithText(RadioListTile<StudentVisibility>, 'Public').last,
      );
      await _back(tester);
      await _tapText(tester, 'Preview Public Profile');
      expect(
        find.textContaining('other McMap students would see'),
        findsOneWidget,
      );
      expect(find.text(_name(_esportsId)), findsOneWidget);
      expect(find.text(_name(_boardGamesId)), findsNothing);
      await _back(tester);

      await _tapText(tester, '2 Club Memberships');
      await _tap(tester, visibility.first);
      expect(find.text(_name(_esportsId)), findsOneWidget);
      await _back(tester);
      expect(find.text('2 Club Memberships'), findsOneWidget);
      expect(find.text(_name(_esportsId)).hitTestable(), findsNothing);
    },
  );

  testWidgets('following and joining are independent and list changes sync', (
    tester,
  ) async {
    await _start(tester);
    await _tapText(tester, 'Following');
    expect(find.text('Follow clubs to see their events here.'), findsOneWidget);
    await _tapText(tester, 'Browse Clubs');
    await _search(tester, 'MESA');
    await _tapText(tester, _name(_esportsId));
    await _tapText(tester, 'Follow');
    await _back(tester);
    expect(find.widgetWithText(OutlinedButton, 'Following'), findsOneWidget);
    await _search(tester, 'board game');
    await _tapText(tester, 'Follow');
    await _back(tester);

    await _tapText(tester, 'Map');
    expect(
      find.text('Campus map is coming soon.').hitTestable(),
      findsOneWidget,
    );
    await _tapText(tester, 'Home');
    await _tapText(tester, 'Browse Clubs');
    await _search(tester, 'board game');
    expect(find.widgetWithText(OutlinedButton, 'Following'), findsOneWidget);
    await _back(tester);
    await _tapText(tester, 'Profile');
    expect(find.text('0 Club Memberships'), findsOneWidget);
    await _tapText(tester, '2 Following');
    expect(find.text(_name(_esportsId)), findsOneWidget);
    expect(find.text(_name(_boardGamesId)), findsOneWidget);
    final boardRow = find.widgetWithText(ListTile, _name(_boardGamesId));
    await _tap(
      tester,
      find.descendant(
        of: boardRow,
        matching: find.widgetWithText(OutlinedButton, 'Unfollow'),
      ),
    );
    expect(find.text(_name(_boardGamesId)), findsNothing);
    await _back(tester);
    expect(find.text('1 Following'), findsOneWidget);

    await _tapText(tester, '0 Club Memberships');
    await _tapText(tester, 'Add Clubs');
    await _search(tester, 'board game');
    await _tapText(tester, _name(_boardGamesId));
    await _tapText(tester, 'Save Clubs');
    await _back(tester);
    expect(find.text('1 Club Memberships'), findsOneWidget);
    await _tapText(tester, '1 Club Memberships');
    final autoRsvp = find.widgetWithText(
      SwitchListTile,
      "Auto-RSVP to this club's events",
    );
    expect(tester.widget<SwitchListTile>(autoRsvp).value, isFalse);
    await _back(tester);
    await _tapText(tester, '1 Following');
    expect(find.text(_name(_esportsId)), findsOneWidget);
    expect(find.text(_name(_boardGamesId)), findsNothing);
  });

  testWidgets('combines following and search and shares RSVPs across pages', (
    tester,
  ) async {
    final stream = StreamController<ClubEvent>();
    addTearDown(stream.close);
    await _start(tester, publications: stream.stream);
    stream.add(_published('coding-1', _esportsId, 'Coding workshop'));
    stream.add(_published('gaming-1', _esportsId, 'Gaming workshop'));
    stream.add(_published('coding-2', _boardGamesId, 'Coding night'));
    await tester.pumpAndSettle();
    await _search(tester, 'coding workshop');
    await _tapText(tester, _name(_esportsId));
    await _tapText(tester, 'Follow');
    await _tap(
      tester,
      find.descendant(
        of: _eventCard('Coding workshop'),
        matching: find.widgetWithText(FilledButton, 'RSVP'),
      ),
    );
    await _back(tester);
    await _tapText(tester, 'Following');
    await _search(tester, 'coding');
    expect(find.text('Coding workshop').hitTestable(), findsOneWidget);
    expect(find.text('Gaming workshop').hitTestable(), findsNothing);
    expect(find.text('Coding night').hitTestable(), findsNothing);
    expect(find.text('Campus Coding Meetup').hitTestable(), findsNothing);
    expect(find.text('Cancel RSVP').hitTestable(), findsOneWidget);
    await _tapText(tester, 'All Events');
    expect(find.text('Coding night').hitTestable(), findsOneWidget);
    expect(find.text('Campus Coding Meetup').hitTestable(), findsOneWidget);

    await _tapText(tester, 'Profile');
    expect(find.text('Coding workshop').hitTestable(), findsOneWidget);
    await _tapText(tester, 'Cancel RSVP');
    await _tapText(tester, '1 Following');
    await _tapText(tester, _name(_esportsId));
    expect(find.widgetWithText(OutlinedButton, 'Following'), findsOneWidget);
    expect(
      find.descendant(
        of: _eventCard('Coding workshop'),
        matching: find.widgetWithText(FilledButton, 'RSVP'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('event inbox honors opt-in, deduplicates, and never RSVPs', (
    tester,
  ) async {
    final stream = StreamController<ClubEvent>();
    addTearDown(stream.close);
    await _start(tester, followed: {_esportsId}, publications: stream.stream);
    await _tapText(tester, 'Profile');
    await _tapText(tester, '1 Following');
    await _tapText(tester, _name(_esportsId));
    final toggle = find.widgetWithText(
      SwitchListTile,
      'Notify me about new events',
    );
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await _tap(tester, toggle);
    stream.add(
      _published(
        'old',
        _esportsId,
        'Backfilled event',
        at: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );
    final first = _published('notification-1', _esportsId, 'New club workshop');
    stream.add(first);
    stream.add(first);
    stream.add(_published('unrelated', _boardGamesId, 'Unrelated event'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel RSVP').hitTestable(), findsNothing);
    await _back(tester);
    expect(find.textContaining('Updates on'), findsOneWidget);
    await _tapText(tester, 'Event updates (1)');
    expect(find.text('New club workshop'), findsOneWidget);
    expect(find.text('Backfilled event'), findsNothing);
    expect(find.text('Unrelated event'), findsNothing);
    await _back(tester);
    await _tapText(tester, _name(_esportsId));
    await _tap(tester, toggle);
    stream.add(_published('after-off', _esportsId, 'After opt-out'));
    await tester.pumpAndSettle();
    await _back(tester);
    await _tapText(tester, 'Event updates (1)');
    expect(find.text('After opt-out'), findsNothing);
    await _back(tester);
    await _back(tester);
    expect(find.text('You have no RSVPs yet.').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
