import '../models/club_event.dart';
import 'clubs.dart';

/// A preview event and its organizer's remaining events.
class ClubFeedEntry {
  const ClubFeedEntry(this.event, {this.club, this.additionalEvents = 0});

  final ClubEvent event;
  final ClubOrganization? club;
  final int additionalEvents;
}

List<ClubFeedEntry> buildClubEventFeed(
  Iterable<ClubEvent> events, {
  required DateTime now,
  required String query,
  Set<String>? followedOnly,
  bool groupAllOrganizations = false,
}) {
  final groups = <String, List<ClubEvent>>{};
  final entries = <ClubFeedEntry>[];
  final order = <String, int>{};
  for (final event in events) {
    if (!event.isListedAt(now)) continue;
    final club = clubsById[event.clubId];
    if (followedOnly != null && !followedOnly.contains(event.clubId)) {
      continue;
    }
    order[event.id] = order.length;
    final groupId = groupAllOrganizations ? event.clubId : club?.id;
    if (groupId == null || groupId.isEmpty) {
      if (event.matches(query)) entries.add(ClubFeedEntry(event));
    } else {
      (groups[groupId] ??= []).add(event);
    }
  }

  int compare(ClubEvent a, ClubEvent b) {
    final chronology = _compareEvents(a, b, now);
    return chronology == 0 ? order[a.id]!.compareTo(order[b.id]!) : chronology;
  }

  final normalizedQuery = normalizeClubSearch(query);
  for (final group in groups.entries) {
    final club = clubsById[group.key];
    final matchesClub =
        normalizedQuery.isNotEmpty && club?.matches(normalizedQuery) == true;
    final matches =
        group.value.where((event) {
          if (query.isEmpty) return event.canRsvpAt(now);
          return matchesClub || event.matches(query);
        }).toList()..sort((a, b) {
          if (query.isNotEmpty) {
            final aMatchesDetails = a.matchesDetails(query);
            final bMatchesDetails = b.matchesDetails(query);
            if (aMatchesDetails != bMatchesDetails) {
              return aMatchesDetails ? -1 : 1;
            }
          }
          return compare(a, b);
        });
    if (matches.isEmpty) continue;
    final preview = matches.first;
    entries.add(
      ClubFeedEntry(
        preview,
        club: club,
        additionalEvents: group.value
            .where((event) => event.id != preview.id && event.canRsvpAt(now))
            .length,
      ),
    );
  }
  // Select previews by schedule, then rank those previews by creation time.
  entries.sort((a, b) {
    final newestFirst = _compareCreationTime(a.event, b.event);
    if (newestFirst != 0) return newestFirst;
    return order[a.event.id]!.compareTo(order[b.event.id]!);
  });
  return entries;
}

/// Every listed event, with each event retaining its own RSVP.
List<ClubEvent> allCampusEvents(Iterable<ClubEvent> events, DateTime now) {
  final listed =
      [
        for (final (index, event) in events.indexed)
          if (event.isListedAt(now)) (index, event),
      ]..sort((a, b) {
        final newestFirst = _compareCreationTime(a.$2, b.$2);
        return newestFirst == 0 ? a.$1.compareTo(b.$1) : newestFirst;
      });
  return [for (final (_, event) in listed) event];
}

int _compareCreationTime(ClubEvent a, ClubEvent b) {
  final aTime = a.createdAt ?? a.publishedAt;
  final bTime = b.createdAt ?? b.publishedAt;
  if (aTime == null) return bTime == null ? 0 : 1;
  return bTime == null ? -1 : bTime.compareTo(aTime);
}

bool eventMatchesFaculty(ClubEvent event, String faculty) {
  final name = normalizeClubSearch(faculty).replaceFirst('faculty of ', '');
  if (name.isEmpty) return false;
  final category = clubsById[event.clubId]?.category ?? '';
  return [
    event.club,
    category,
    ...event.tags,
  ].any((value) => ' ${normalizeClubSearch(value)} '.contains(' $name '));
}

/// The same chronology drives the featured event and the upcoming list.
class ClubEventSchedule {
  ClubEventSchedule(Iterable<ClubEvent> events, String clubId, DateTime now) {
    for (final event in events) {
      if (event.clubId != clubId || !event.isListedAt(now)) continue;
      if (event.cancelled) {
        cancelled.add(event);
      } else if (event.startsAt == null) {
        undated.add(event);
      } else if (event.isUpcomingAt(now)) {
        upcoming.add(event);
      } else {
        past.add(event);
      }
    }
    upcoming.sort((a, b) => _compareEvents(a, b, now));
    past.sort((a, b) => _compareEvents(a, b, now));
  }

  final upcoming = <ClubEvent>[];
  final past = <ClubEvent>[];
  final undated = <ClubEvent>[];
  final cancelled = <ClubEvent>[];
}

int _compareEvents(ClubEvent a, ClubEvent b, DateTime now) {
  final aPriority = _priority(a, now);
  final bPriority = _priority(b, now);
  if (aPriority != bPriority) return aPriority.compareTo(bPriority);
  final aDate = a.startsAt;
  final bDate = b.startsAt;
  if (aDate != null && bDate != null) {
    final dates = aPriority == 2
        ? bDate.compareTo(aDate)
        : aDate.compareTo(bDate);
    if (dates != 0) return dates;
  }
  return 0;
}

int _priority(ClubEvent event, DateTime now) {
  if (event.cancelled) return 3;
  if (event.startsAt == null) return 1;
  return event.isUpcomingAt(now) ? 0 : 2;
}
