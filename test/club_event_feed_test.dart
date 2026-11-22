import 'package:flutter_test/flutter_test.dart';
import 'package:mcmap/data/club_event_feed.dart';
import 'package:mcmap/models/club_event.dart';

void main() {
  test(
    'feed uses creation time, publication fallback, and stable input ties',
    () {
      final now = DateTime.utc(2026, 11, 21);
      ClubEvent event(String id, int start, {int? created, int? published}) =>
          ClubEvent(
            id,
            id,
            'Organizer',
            '',
            '',
            startsAt: now.add(Duration(days: start)),
            createdAt: created == null
                ? null
                : now.subtract(Duration(days: created)),
            publishedAt: published == null
                ? null
                : now.subtract(Duration(days: published)),
          );

      final events = [
        event('untimed-first', 10),
        event('old-created', 1, created: 4, published: 0),
        event('new-created', 9, created: 1),
        event('publication-fallback', 2, published: 2),
        event('untimed-second', 3),
        event('same-creation-time', 4, created: 1),
      ];
      expect(
        buildClubEventFeed(
          events,
          now: now,
          query: '',
        ).map((entry) => entry.event.id),
        [
          'new-created',
          'same-creation-time',
          'publication-fallback',
          'old-created',
          'untimed-first',
          'untimed-second',
        ],
      );
    },
  );

  test(
    'feed ranks organization previews without changing which event is next',
    () {
      const robotics = 'engineering-mcgill-robotics';
      const esports = 'ssmu-mcgill-e-sports-students-society';
      final now = DateTime.utc(2026, 11, 21);
      ClubEvent event(String id, String clubId, int start, int created) =>
          ClubEvent(
            id,
            id,
            'Organizer',
            '',
            '',
            clubId: clubId,
            startsAt: now.add(Duration(days: start)),
            createdAt: now.subtract(Duration(days: created)),
          );
      final events = [
        event('robotics-later', robotics, 5, 1),
        event('robotics-next', robotics, 1, 3),
        event('esports-next', esports, 3, 2),
      ];

      final feed = buildClubEventFeed(events, now: now, query: '');
      expect(feed.map((entry) => entry.event.id), [
        'esports-next',
        'robotics-next',
      ]);
      expect(feed.last.additionalEvents, 1);
      expect(
        ClubEventSchedule(
          events,
          robotics,
          now,
        ).upcoming.map((event) => event.id),
        ['robotics-next', 'robotics-later'],
      );
      expect(
        buildClubEventFeed(
          events,
          now: now,
          query: 'robotics-later',
        ).single.event.id,
        'robotics-later',
      );
    },
  );

  test('a non-catalog organizer matches Following by its exact slug', () {
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
      ).map((entry) => entry.event.id),
      ['sample-two'],
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
}
