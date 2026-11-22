import 'package:flutter_test/flutter_test.dart';
import 'package:mcmap/data/academics.dart';
import 'package:mcmap/data/auto_follow.dart';
import 'package:mcmap/data/club_event_feed.dart';
import 'package:mcmap/data/clubs.dart';
import 'package:mcmap/models/club_event.dart';
import 'package:mcmap/models/user_profile.dart';

void main() {
  test('unverified publisher labels stay separate and outside Following', () {
    const events = [
      ClubEvent('sample-one', 'Sample One', 'Same publisher', '', ''),
      ClubEvent(
        'sample-two',
        'Sample Two',
        'Same publisher',
        '',
        '',
        clubId: 'unknown-club',
      ),
    ];
    final now = DateTime.utc(2026, 11, 21);
    final feed = buildClubEventFeed(events, now: now, query: '');
    expect(feed.map((entry) => entry.event.id), ['sample-one', 'sample-two']);
    expect(feed.map((entry) => entry.club), everyElement(isNull));
    expect(feed.every((entry) => !entry.event.isUpcomingAt(now)), isTrue);
    expect(
      buildClubEventFeed(
        events,
        now: now,
        query: '',
        followedOnly: {'unknown-club'},
      ),
      isEmpty,
    );
  });

  test(
    'club schedule separates dates and status and hides future publications',
    () {
      const club = 'engineering-mcgill-robotics';
      final now = DateTime.utc(2026, 11, 21);
      ClubEvent event(
        String id,
        int? days, {
        bool cancelled = false,
        DateTime? publication,
      }) => ClubEvent(
        id,
        id,
        'McGill Robotics',
        '',
        '',
        clubId: club,
        startsAt: days == null ? null : now.add(Duration(days: days)),
        cancelled: cancelled,
        publishedAt: publication,
      );
      final events = [
        event(
          'future publication',
          1,
          publication: now.add(const Duration(hours: 1)),
        ),
        event('second', 2),
        event('cancelled', 1, cancelled: true),
        event('older', -10),
        event('first', 1),
        event('undated', null),
        event('recent', -1),
      ];
      final schedule = ClubEventSchedule(events, club, now);
      expect(schedule.upcoming.map((event) => event.id), ['first', 'second']);
      expect(schedule.past.map((event) => event.id), ['recent', 'older']);
      expect(schedule.cancelled.single.id, 'cancelled');
      expect(schedule.undated.single.id, 'undated');
      expect(schedule.cancelled.single.canRsvpAt(now), isFalse);
      expect(schedule.past.every((event) => !event.canRsvpAt(now)), isTrue);
    },
  );

  test('feed shows the newest created events first', () {
    final now = DateTime.utc(2026, 11, 21, 12);
    ClubEvent event(String id, {int? createdHoursAgo, int startsInDays = 1}) =>
        ClubEvent(
          id,
          id,
          'Organizer $id',
          '',
          '',
          startsAt: now.add(Duration(days: startsInDays)),
          createdAt: createdHoursAgo == null
              ? null
              : now.subtract(Duration(hours: createdHoursAgo)),
        );
    final feed = buildClubEventFeed(
      [
        event('old', createdHoursAgo: 48, startsInDays: 1),
        event('undated sample', startsInDays: 1),
        event('newest', createdHoursAgo: 1, startsInDays: 9),
        event('middle', createdHoursAgo: 5, startsInDays: 3),
      ],
      now: now,
      query: '',
    );
    expect(feed.map((entry) => entry.event.id), [
      'newest',
      'middle',
      'old',
      'undated sample',
    ]);
  });

  group('For You home feed', () {
    final now = DateTime.utc(2026, 11, 21, 12);
    ClubEvent event(
      String id, {
      String? clubId,
      int createdHoursAgo = 1,
      bool frosh = false,
      List<String> tags = const [],
    }) => ClubEvent(
      id,
      id,
      clubId == null ? 'Organizer $id' : clubsById[clubId]!.name,
      '',
      '',
      clubId: clubId,
      startsAt: now.add(const Duration(days: 2)),
      createdAt: now.subtract(Duration(hours: createdHoursAgo)),
      isFrosh: frosh,
      tags: tags,
      supportsUnrestrictedRsvp: true,
    );

    test('followed groups first, newest first; everyone else suggested', () {
      final feed = buildHomeFeed(
        [
          event('ssmu old', clubId: 'mcgill-ssmu', createdHoursAgo: 30),
          event('chess', clubId: 'ssmu-mcgill-students-chess-club'),
          event(
            'eus new',
            clubId: 'engineering-engineering-undergraduate-society-eus',
          ),
        ],
        now: now,
        followedClubIds: {
          'mcgill-ssmu',
          'engineering-engineering-undergraduate-society-eus',
        },
      );
      expect(feed.followed.map((e) => e.event.id), ['eus new', 'ssmu old']);
      expect(feed.suggested.map((e) => e.event.id), ['chess']);
    });

    test('suggestions lead with campus society, faculty association, FYC', () {
      const froshie = UserProfile(
        degreeLevel: DegreeLevel.undergraduate,
        year: 'U0',
        faculty: 'Engineering',
        major: undeclaredMajor,
      );
      final feed = buildHomeFeed(
        [
          event('chess newest', clubId: 'ssmu-mcgill-students-chess-club'),
          event('ssmu', clubId: 'mcgill-ssmu', createdHoursAgo: 40),
          event('plain', createdHoursAgo: 2),
          event(
            'eus',
            clubId: 'engineering-engineering-undergraduate-society-eus',
            createdHoursAgo: 30,
          ),
          event('fyc', clubId: 'eus-junior-council', createdHoursAgo: 20),
          event('aus', clubId: 'mcgill-aus', createdHoursAgo: 3),
        ],
        now: now,
        followedClubIds: const {},
        priorityClubIds: priorityClubIdsFor(froshie),
      );
      expect(feed.followed, isEmpty);
      expect(feed.suggested.map((e) => e.event.id), [
        // Tiers 1 + 2, newest first.
        'fyc', 'eus', 'ssmu',
        // Everyone else, newest first (AUS isn't an Engineering student's).
        'chess newest', 'plain', 'aus',
      ]);
    });

    test('returning students get no FYC boost; grad students get PGSS', () {
      const returning = UserProfile(
        degreeLevel: DegreeLevel.undergraduate,
        year: 'U2',
        faculty: 'Arts & Science',
        major: 'Cognitive Science',
      );
      expect(priorityClubIdsFor(returning), {'mcgill-ssmu', 'mcgill-basic'});
      const masters = UserProfile(
        degreeLevel: DegreeLevel.masters,
        faculty: 'Science',
        major: 'Biology',
      );
      expect(priorityClubIdsFor(masters), {'mcgill-pgss'});
    });

    test('View All lists every event, one each, newest first', () {
      final events = [
        event('a', clubId: 'mcgill-ssmu', createdHoursAgo: 5),
        event('b', clubId: 'mcgill-ssmu', createdHoursAgo: 1),
        event('c', createdHoursAgo: 3),
      ];
      expect(allCampusEvents(events, now).map((e) => e.id), ['b', 'c', 'a']);
    });
  });
}
