import 'package:mcmap/data/academics.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mcmap/data/clubs.dart';
import 'package:mcmap/models/club_event.dart';
import 'package:mcmap/models/user_profile.dart';
import 'package:mcmap/pages/all_events_page.dart';
import 'package:mcmap/pages/event_details_page.dart';
import 'package:mcmap/pages/home_page.dart';
import 'package:mcmap/pages/student/club_discovery.dart';
import 'package:mcmap/pages/student/suggested_clubs.dart';
import 'package:mcmap/pages/student/student_profile.dart';
import 'package:mcmap/social/mcgillian_widgets.dart';
import 'package:mcmap/widgets/initials_avatar.dart';
import 'package:mcmap/widgets/profile_stats.dart';
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
          degreeLevel: DegreeLevel.undergraduate,
          faculty: 'Engineering',
          major: 'Software Engineering',
          year: 'U2',
          followedClubIds: followed,
          interests: interests,
        ),
        publications: publications,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ClubEvent _published(
  String id,
  String clubId,
  String title, {
  DateTime? at,
  DateTime? startsAt,
  String? description,
  bool cancelled = false,
}) {
  final now = DateTime.now();
  return ClubEvent(
    id,
    title,
    _name(clubId),
    'Tomorrow',
    'Campus',
    clubId: clubId,
    publishedAt: at ?? now,
    startsAt: startsAt ?? now.add(const Duration(days: 1)),
    description: description,
    cancelled: cancelled,
    supportsUnrestrictedRsvp: true,
  );
}

Finder _eventCard(String title) => find
    .ancestor(of: find.text(title), matching: find.byType(Card))
    .hitTestable();

void main() {
  testWidgets(
    'For You groups followed organizations above suggestions and jumps to the heading',
    (tester) async {
      const facultyId = 'faculty-of-engineering';
      final stream = StreamController<ClubEvent>();
      addTearDown(stream.close);
      await _start(
        tester,
        followed: const {_esportsId, _boardGamesId, facultyId},
        publications: stream.stream,
      );
      await tester.binding.setSurfaceSize(const Size(600, 550));
      final now = DateTime.now();
      ClubEvent facultyEvent(String title, int days) => ClubEvent(
        title,
        title,
        'Faculty of Engineering',
        '',
        'Campus',
        clubId: facultyId,
        startsAt: now.add(Duration(days: days)),
        createdAt: now.subtract(const Duration(days: 1)),
      );
      stream
        ..add(_published('esports', _esportsId, 'Esports followed event'))
        ..add(_published('board', _boardGamesId, 'Board followed event'))
        ..add(facultyEvent('Faculty upcoming event', 1))
        ..add(facultyEvent('Faculty later event', 2))
        ..add(facultyEvent('Faculty past event', -1));
      await tester.pumpAndSettle();

      final forYou = find.widgetWithText(ChoiceChip, 'For You');
      expect(tester.widget<ChoiceChip>(forYou).selected, isTrue);
      final followed = find.text('From groups you follow');
      final suggested = find.text('Suggested events');
      expect(
        tester.getTopLeft(followed).dy,
        lessThan(tester.getTopLeft(suggested).dy),
      );
      expect(find.text('Faculty upcoming event'), findsOneWidget);
      expect(find.text('Faculty later event'), findsNothing);
      expect(find.text('Faculty past event'), findsNothing);
      expect(suggested.hitTestable(), findsNothing);

      await _tapText(tester, 'Jump to suggested events');
      expect(suggested.hitTestable(), findsOneWidget);
      final sample = find.text('Board Game Night');
      expect(sample, findsOneWidget);
      expect(
        tester.getTopLeft(sample).dy,
        greaterThan(tester.getTopLeft(suggested).dy),
      );
      expect(find.text('Faculty upcoming event'), findsOneWidget);
      await _tapText(tester, 'View all');
      expect(find.byType(AllEventsPage), findsOneWidget);
      await _back(tester);

      final bottom = find.widgetWithText(FilledButton, 'View All Events');
      await tester.scrollUntilVisible(
        bottom,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await _tap(tester, bottom);
      expect(find.byType(AllEventsPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'All Events keeps individual cards, ordering, filters, details and RSVPs',
    (tester) async {
      final stream = StreamController<ClubEvent>();
      addTearDown(stream.close);
      await _start(
        tester,
        followed: const {_esportsId},
        publications: stream.stream,
      );
      final now = DateTime.now();
      ClubEvent event(
        String title,
        String clubId,
        int createdDaysAgo, {
        bool frosh = false,
        List<String> tags = const [],
        DateTime? publication,
      }) => ClubEvent(
        title,
        title,
        _name(clubId),
        '',
        'Campus',
        clubId: clubId,
        isFrosh: frosh,
        tags: tags,
        createdAt: now.subtract(Duration(days: createdDaysAgo)),
        startsAt: now.add(Duration(days: createdDaysAgo)),
        publishedAt: publication,
        synopsis: 'Event summary for $title.',
      );
      stream
        ..add(event('Older esports', _esportsId, 3, frosh: true))
        ..add(
          event(
            'Engineering workshop',
            _boardGamesId,
            2,
            tags: ['engineering'],
          ),
        )
        ..add(event('Newest esports', _esportsId, 1))
        ..add(
          event(
            'Unlisted publication',
            _boardGamesId,
            0,
            publication: now.add(const Duration(days: 1)),
          ),
        );
      await tester.pumpAndSettle();
      await _tapText(tester, 'View all');
      final allEvents = find.byType(AllEventsPage);
      Finder title(String title) =>
          find.descendant(of: allEvents, matching: find.text(title));
      expect(title('Unlisted publication'), findsNothing);
      expect(title('Newest esports').hitTestable(), findsOneWidget);
      expect(title('Older esports').hitTestable(), findsOneWidget);
      expect(
        tester.getTopLeft(title('Newest esports')).dy,
        lessThan(tester.getTopLeft(title('Older esports')).dy),
      );
      final newestCard = _eventCard('Newest esports');
      final date = MaterialLocalizations.of(tester.element(allEvents))
          .formatFullDate(now.add(const Duration(days: 1)));
      expect(
        find.descendant(of: newestCard, matching: find.textContaining(date)),
        findsOneWidget,
      );
      expect(find.text('AI SUMMARY'), findsNothing);

      Future<void> filter(String label) =>
          _tap(tester, find.widgetWithText(ChoiceChip, label));
      await filter('Following');
      expect(title('Engineering workshop'), findsNothing);
      expect(title('Newest esports'), findsOneWidget);
      expect(title('Older esports'), findsOneWidget);
      await filter('Faculty');
      expect(title('Engineering workshop'), findsOneWidget);
      expect(title('Newest esports'), findsNothing);
      await filter('Froshie');
      expect(title('Older esports'), findsOneWidget);
      expect(title('Newest esports'), findsNothing);
      await filter('All');
      expect(title('Engineering workshop'), findsOneWidget);

      await _tap(
        tester,
        find.descendant(
          of: _eventCard('Newest esports'),
          matching: find.text('RSVP'),
        ),
      );
      expect(
        find.descendant(
          of: _eventCard('Newest esports'),
          matching: find.text('Cancel RSVP'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _eventCard('Older esports'),
          matching: find.text('RSVP'),
        ),
        findsOneWidget,
      );
      await _tap(tester, title('Newest esports'));
      expect(find.byType(EventDetailsPage), findsOneWidget);
      await _tapText(tester, 'Cancel RSVP');
      await _back(tester);
      expect(
        find.descendant(
          of: _eventCard('Newest esports'),
          matching: find.text('RSVP'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('All Events is available without followed organizations', (
    tester,
  ) async {
    await _start(tester);
    expect(find.text('From groups you follow'), findsNothing);
    expect(find.text('Jump to suggested events'), findsNothing);
    await _tapText(tester, 'View all');
    expect(find.byType(AllEventsPage), findsOneWidget);
    await _tap(tester, find.widgetWithText(ChoiceChip, 'Following'));
    expect(find.text('No events match this filter yet.'), findsOneWidget);
  });

  testWidgets(
    'club feed groups previews and keeps RSVP on the previewed event',
    (tester) async {
      final stream = StreamController<ClubEvent>();
      addTearDown(stream.close);
      await _start(tester, followed: {_esportsId}, publications: stream.stream);
      final now = DateTime.now();
      stream
        ..add(
          _published(
            'later',
            _esportsId,
            'Esports championship',
            startsAt: now.add(const Duration(days: 3)),
            description: 'Check in at the registration desk.',
          ),
        )
        ..add(
          _published(
            'board',
            _boardGamesId,
            'Board game tournament',
            startsAt: now.add(const Duration(days: 2)),
          ),
        )
        ..add(
          _published(
            'next',
            _esportsId,
            'Beginner workshop',
            startsAt: now.add(const Duration(hours: 5)),
          ),
        )
        ..add(
          _published(
            'past',
            _esportsId,
            'Last week workshop',
            startsAt: now.subtract(const Duration(days: 7)),
          ),
        )
        ..add(
          _published(
            'cancelled',
            _esportsId,
            'Called off scrimmage',
            cancelled: true,
          ),
        );
      await tester.pumpAndSettle();

      expect(find.text('View club events'), findsNWidgets(2));
      expect(find.text('1 more from this club'), findsOneWidget);
      expect(find.text('Esports championship'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Beginner workshop')).dy,
        lessThan(tester.getTopLeft(find.text('Board game tournament')).dy),
      );
      Finder action(String event, String label) =>
          find.descendant(of: _eventCard(event), matching: find.text(label));
      await _tap(tester, action('Beginner workshop', 'RSVP'));
      expect(find.byType(ClubDetailPage), findsNothing);
      expect(action('Beginner workshop', 'Cancel RSVP'), findsOneWidget);
      await _tap(tester, action('Beginner workshop', 'View club events'));
      expect(find.byType(ClubDetailPage), findsOneWidget);
      expect(find.text(_name(_esportsId)), findsOneWidget);
      expect(find.text('Next event'), findsOneWidget);
      expect(find.text('More upcoming events'), findsOneWidget);
      expect(find.text('Recent past events'), findsOneWidget);
      expect(find.text('Cancelled events'), findsOneWidget);
      expect(action('Esports championship', 'RSVP'), findsOneWidget);
      expect(action('Last week workshop', 'RSVP'), findsNothing);
      expect(action('Called off scrimmage', 'RSVP'), findsNothing);
      // Tapping the card body (not the avatar or RSVP) opens details.
      await _tap(
        tester,
        action('Esports championship', 'Esports championship'),
      );
      expect(find.text('Event details'), findsOneWidget);
      expect(find.text('Esports championship'), findsOneWidget);
      expect(find.text('Check in at the registration desk.'), findsOneWidget);
      await _back(tester);
      await _back(tester);

      await _tapText(tester, 'Following');
      expect(find.text('View club events'), findsOneWidget);
      expect(find.text('Board game tournament'), findsNothing);
      await _search(tester, 'esports');
      expect(find.text('Matching event'), findsOneWidget);
      expect(find.text('Esports championship'), findsOneWidget);
      expect(find.text('Beginner workshop').hitTestable(), findsNothing);
      expect(action('Esports championship', 'RSVP'), findsOneWidget);
      await _tapText(tester, 'Profile');
      expect(action('Beginner workshop', 'Cancel RSVP'), findsOneWidget);
      expect(find.text('Esports championship').hitTestable(), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'All searches club aliases and opens clubs using shared follow state',
    (tester) async {
      await _start(tester);
      expect(find.text('Clubs & organizations'), findsNothing);
      await _search(tester, 'mEsA');
      expect(find.byType(SuggestedClubs), findsNothing);
      final club = find.widgetWithText(ClubRow, _name(_esportsId));
      expect(club, findsOneWidget);
      expect(
        find.descendant(
          of: club,
          matching: find.text(clubsById[_esportsId]!.category),
        ),
        findsOneWidget,
      );
      await _tap(
        tester,
        find.descendant(of: club, matching: find.text('Follow')),
      );
      await _tapText(tester, _name(_esportsId));
      expect(find.byType(ClubDetailPage), findsOneWidget);
      await _tapText(tester, 'Following');
      await _back(tester);
      expect(
        find.descendant(of: club, matching: find.text('Follow')),
        findsOneWidget,
      );

      await _search(tester, 'science');
      expect(find.byType(McGillianTile), findsWidgets);
      expect(find.byType(ClubRow), findsWidgets);
      expect(find.text('Campus Coding Meetup'), findsOneWidget);
      await _search(tester, 'mcgill');
      await _tap(
        tester,
        find.textContaining(RegExp(r'^See all \d+ organizations$')),
      );
      expect(find.byType(ClubDirectoryPage), findsOneWidget);
      expect(
        tester.widget<SearchBar>(find.byType(SearchBar)).controller!.text,
        'mcgill',
      );
      await _back(tester);
      await _search(tester, 'science');
      await _tapText(tester, 'Events');
      expect(find.byType(McGillianTile), findsNothing);
      expect(find.byType(ClubRow), findsNothing);
      expect(find.text('Campus Coding Meetup'), findsOneWidget);
      await _tapText(tester, 'McGillians');
      expect(find.byType(McGillianTile), findsWidgets);
      expect(find.byType(ClubRow), findsNothing);
      expect(find.text('Campus Coding Meetup'), findsNothing);
    },
  );

  testWidgets('Home re-tap animates to the top and keeps the search query', (
    tester,
  ) async {
    await _start(tester);
    await tester.binding.setSurfaceSize(const Size(390, 520));
    await tester.pumpAndSettle();
    await _search(tester, 'science');
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scroll.position.jumpTo(320);
    await tester.pumpAndSettle();
    final offset = scroll.position.pixels;
    expect(offset, greaterThan(0));

    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(scroll.position.pixels, inExclusiveRange(0, offset));
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, 0);
    expect(
      tester.widget<SearchBar>(find.byType(SearchBar)).controller!.text,
      'science',
    );
    expect(find.byType(SearchBar).hitTestable(), findsOneWidget);
  });

  testWidgets(
    'photo, clubs, academic edits, friends and RSVPs remain independent',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync('mcmap-photo-test');
      addTearDown(() => directory.deleteSync(recursive: true));
      final bytes = [
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
        ),
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNg+M8AAAICAQB7CYF4AAAAAElFTkSuQmCC',
        ),
      ];
      final photos = [
        for (final (index, photo) in bytes.indexed)
          File('${directory.path}/$index.png')..writeAsBytesSync(photo),
      ];
      const channel = MethodChannel('plugins.flutter.io/image_picker');
      var selected = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'pickImage');
        return photos[selected++].path;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await _start(tester);
      await _tapText(tester, 'Profile');

      int stat(String label) => tester
          .widget<ProfileStat>(find.widgetWithText(ProfileStat, label))
          .value;
      expect(stat('McGillians'), 3);

      Future<void> choosePhoto(int index) async {
        await tester.runAsync(() async {
          await tester.tap(find.text('Choose from library'));
          for (var attempt = 0; attempt < 100; attempt++) {
            await tester.pump(const Duration(milliseconds: 20));
            if (tester
                .widgetList<ProfileAvatar>(find.byType(ProfileAvatar))
                .any(
                  (avatar) =>
                      avatar.profile.avatarBytes?.join(',') ==
                      bytes[index].join(','),
                )) {
              return;
            }
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          fail('The chosen profile photo did not reach the avatar.');
        });
        await tester.pumpAndSettle();
      }

      await _tap(tester, find.byType(EditableProfileAvatar));
      await choosePhoto(0);
      await _tapText(tester, '0 Following');
      await _tapText(tester, 'Browse Clubs');
      await _search(tester, 'MESA');
      await _tapText(tester, 'Follow');
      await _back(tester);
      await _back(tester);

      expect(stat('McGillians'), 3);
      expect(find.text('1 Following'), findsOneWidget);
      expect(
        tester
            .widget<ProfileHeader>(find.byType(ProfileHeader))
            .profile
            .avatarBytes,
        orderedEquals(bytes[0]),
      );
      await _tapText(tester, 'Edit Profile');
      await _tapText(tester, 'Change picture');
      await choosePhoto(1);
      final year = find.byType(DropdownButtonFormField<String>).last;
      await _tap(tester, year);
      await _tap(tester, find.text('U3').last);
      await _tapText(tester, 'Save Changes');
      expect(find.text('Software Engineering · U3'), findsOneWidget);
      expect(find.text('1 Following'), findsOneWidget);
      expect(
        tester
            .widget<ProfileHeader>(find.byType(ProfileHeader))
            .profile
            .avatarBytes,
        orderedEquals(bytes[1]),
      );
      await _tapText(tester, '1 Following');
      expect(find.text(_name(_esportsId)), findsOneWidget);
      await _back(tester);

      await _tapText(tester, 'Home');
      await _search(tester, 'Amir Haddad');
      await _tap(
        tester,
        find.descendant(
          of: find.widgetWithText(McGillianTile, 'Amir Haddad'),
          matching: find.text('Add Friend'),
        ),
      );
      await _search(tester, 'Board Game Night');
      await _tap(
        tester,
        find.descendant(
          of: _eventCard('Board Game Night'),
          matching: find.text('RSVP'),
        ),
      );
      await _tapText(tester, 'Profile');
      expect(stat('McGillians'), 4);
      expect(stat('Events'), 1);
      expect(find.text('1 Following'), findsOneWidget);
      await _tapText(tester, 'Cancel RSVP');
      expect(stat('McGillians'), 4);
      expect(stat('Events'), 0);
      expect(find.text('1 Following'), findsOneWidget);
    },
  );

  testWidgets(
    'suggestions follow immediately and replace one row after a second',
    (tester) async {
      await _start(tester, interests: {'Robotics'});
      final section = find.byType(SuggestedClubs);
      expect(section, findsNothing);
      expect(find.text('Board Game Night'), findsOneWidget);
      await _tapText(tester, 'Discover Clubs');
      expect(find.text('Board Game Night'), findsNothing);
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
        tester.getBottomLeft(find.text('Club events')).dy,
        lessThan(tester.getTopLeft(section).dy),
      );
      await _search(tester, 'photo');
      expect(names(), isEmpty);
      expect(find.text('Clubs & organizations'), findsOneWidget);
      expect(find.text('Photo Walk'), findsOneWidget);
      await _search(tester, '');
      await _tapText(tester, 'Discover Clubs');
      expect(names(), original);
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
    await _tapText(tester, 'Discover Clubs');
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

  testWidgets('Discover Clubs opens the directory without changing filters', (
    tester,
  ) async {
    await _start(tester);
    await tester.binding.setSurfaceSize(const Size(390, 820));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'Browse Clubs'), findsNothing);
    await _tapText(tester, 'Discover Clubs');
    await _tapText(tester, 'See all clubs');
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
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Discover Clubs'))
          .selected,
      isTrue,
    );
    await _tapText(tester, 'Profile');
    expect(find.textContaining('Club Memberships'), findsNothing);
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
    'organization follow and unfollow sync across the directory and Profile',
    (tester) async {
      await _start(tester);
      await _tapText(tester, 'Following');
      expect(
        find.text('Follow clubs to see their events here.'),
        findsOneWidget,
      );
      await _tapText(tester, 'Discover Clubs');
      await _tapText(tester, 'See all clubs');
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
      await _tapText(tester, 'See all clubs');
      await _search(tester, 'board game');
      expect(find.widgetWithText(OutlinedButton, 'Following'), findsOneWidget);
      await _back(tester);
      await _tapText(tester, 'Profile');
      expect(find.textContaining('Club Memberships'), findsNothing);
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

      await _tapText(tester, '1 Following');
      expect(find.text(_name(_esportsId)), findsOneWidget);
      expect(find.text(_name(_boardGamesId)), findsNothing);
    },
  );

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
    // The club avatar on the card opens the club page.
    await _tap(
      tester,
      find.descendant(
        of: _eventCard('Coding workshop'),
        matching: find.byType(InitialsAvatar),
      ),
    );
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
    await _tapText(tester, 'For You');
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
  testWidgets(
    'auto-RSVP switches sync and apply only to eligible followed organizers',
    (tester) async {
      final publications = StreamController<ClubEvent>();
      addTearDown(publications.close);
      await _start(tester, publications: publications.stream);
      const facultyId = 'faculty-of-science';
      const faculty = 'Faculty of Science';
      const autoLabel = 'Auto-RSVP to events';
      final autoSwitch = find.widgetWithText(SwitchListTile, autoLabel);
      final private = find.text('Going · Demo visibility: Private');

      Future<ClubEvent> publish(
        String title,
        String id, {
        String? name,
        bool unrestricted = true,
        DateTime? publishedAt,
      }) async {
        final event = ClubEvent(
          title,
          title,
          name ?? _name(id),
          'Tomorrow',
          'Campus',
          clubId: id,
          publishedAt: publishedAt ?? DateTime.now(),
          startsAt: DateTime.now().add(const Duration(days: 1)),
          supportsUnrestrictedRsvp: unrestricted,
        );
        publications.add(event);
        await tester.pumpAndSettle();
        return event;
      }

      await publish('Faculty welcome', facultyId, name: faculty);
      await _tapText(tester, 'Profile');
      await _tapText(tester, '0 Following');
      await _tapText(tester, 'Browse Clubs');
      await _search(tester, 'MESA');
      await _tapText(tester, _name(_esportsId));
      expect(autoSwitch, findsNothing);
      await _tapText(tester, 'Follow');
      expect(tester.widget<SwitchListTile>(autoSwitch).value, isFalse);
      final notifications = find.widgetWithText(
        SwitchListTile,
        'Notify me about new events',
      );
      expect(tester.widget<SwitchListTile>(notifications).value, isFalse);
      await _tap(tester, autoSwitch);
      expect(tester.widget<SwitchListTile>(autoSwitch).value, isTrue);
      await _back(tester);
      await _back(tester);
      expect(tester.widget<SwitchListTile>(autoSwitch).value, isTrue);
      await _back(tester);

      await publish(
        'Before consent',
        _esportsId,
        publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      final first = await publish('Club workshop', _esportsId);
      publications.add(first);
      await tester.pumpAndSettle();
      await publish('Other club', _boardGamesId);
      await publish('Paid workshop', _esportsId, unrestricted: false);
      expect(private.hitTestable(), findsOneWidget);
      expect(find.text('Club workshop').hitTestable(), findsOneWidget);
      expect(find.text('Paid workshop').hitTestable(), findsNothing);
      await _tapText(tester, 'Cancel RSVP');
      publications.add(first);
      await tester.pumpAndSettle();
      expect(private.hitTestable(), findsNothing);

      await _tapText(tester, '1 Following');
      await _tap(tester, autoSwitch);
      await _tapText(tester, _name(_esportsId));
      expect(tester.widget<SwitchListTile>(autoSwitch).value, isFalse);
      await _back(tester);
      await _tapText(tester, 'Browse Clubs');
      await _search(tester, faculty);
      await _tap(tester, find.widgetWithText(ListTile, faculty));
      await _tapText(tester, 'Follow');
      expect(tester.widget<SwitchListTile>(autoSwitch).value, isFalse);
      await _tap(tester, autoSwitch);
      await _back(tester);
      await _back(tester);
      expect(
        tester.widgetList<SwitchListTile>(autoSwitch).map((item) => item.value),
        [false, true],
      );
      await _back(tester);

      await publish('While disabled', _esportsId);
      await publish(
        'Same name, other slug',
        'different-faculty',
        name: faculty,
      );
      await publish('Faculty seminar', facultyId, name: faculty);
      expect(private.hitTestable(), findsOneWidget);
      expect(find.text('Faculty seminar').hitTestable(), findsOneWidget);
      await _tapText(tester, '2 Following');
      final club = find.widgetWithText(ListTile, _name(_esportsId));
      await _tap(
        tester,
        find.descendant(of: club, matching: find.text('Unfollow')),
      );
      await _back(tester);
      await publish('After unfollow', _esportsId);
      expect(private.hitTestable(), findsOneWidget);
      expect(find.text('Faculty seminar').hitTestable(), findsOneWidget);
      expect(find.text('1 Following'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'existing auto-RSVP opt-in works until unfollow and preserves RSVP decisions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final publications = StreamController<ClubEvent>();
      addTearDown(publications.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMcMapTheme(),
          home: HomePage(
            profile: UserProfile(
              degreeLevel: DegreeLevel.undergraduate,
              faculty: 'Engineering',
              major: 'Software Engineering',
              year: 'U2',
              followedClubIds: const {_esportsId},
              clubAutoRsvpOptIns: {
                _esportsId: DateTime.now().subtract(const Duration(hours: 1)),
              },
            ),
            publications: publications.stream,
          ),
        ),
      );
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      ClubEvent published(String id) => ClubEvent(
        id,
        id,
        _name(_esportsId),
        'Tomorrow',
        'Campus',
        clubId: _esportsId,
        publishedAt: DateTime.now(),
        startsAt: DateTime.now().add(const Duration(days: 1)),
        supportsUnrestrictedRsvp: true,
      );

      final first = published('New club event');
      publications.add(first);
      publications.add(first);
      await tester.pumpAndSettle();
      expect(
        find.text('Going · Demo visibility: Private').hitTestable(),
        findsOneWidget,
      );
      await _tapText(tester, '1 Following');
      await tester.tap(find.text('Unfollow'));
      await tester.pumpAndSettle();
      expect(
        find.text("You're not following any clubs yet.").hitTestable(),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      publications.add(published('After removal'));
      await tester.pumpAndSettle();
      expect(
        find.text('Going · Demo visibility: Private').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('After removal').hitTestable(), findsNothing);
      await tester.tap(find.text('Cancel RSVP').hitTestable());
      await tester.pumpAndSettle();
      publications.add(first);
      await tester.pumpAndSettle();
      expect(find.text('You have no RSVPs yet.').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
