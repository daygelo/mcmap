import 'package:flutter_test/flutter_test.dart';
import 'package:mcmap/data/club_event_feed.dart';
import 'package:mcmap/models/club_event.dart';

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
}
