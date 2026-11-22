import '../models/club_event.dart';
import 'clubs.dart';

/// One feed entry per verified club. Events without a catalog ID keep their
/// own entry, even if their publisher labels happen to match.
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
}) {
  final groups = <String, List<ClubEvent>>{};
  final entries = <ClubFeedEntry>[];
  final order = <String, int>{};
  for (final event in events) {
    if (!event.isListedAt(now)) continue;
    final club = clubsById[event.clubId];
    if (followedOnly != null &&
        (club == null || !followedOnly.contains(club.id))) {
      continue;
    }
    order[event.id] = order.length;
    if (club == null) {
      if (event.matches(query)) entries.add(ClubFeedEntry(event));
    } else {
      (groups[club.id] ??= []).add(event);
    }
  }

  int compare(ClubEvent a, ClubEvent b) {
    final chronology = _compareEvents(a, b, now);
    return chronology == 0 ? order[a.id]!.compareTo(order[b.id]!) : chronology;
  }

  final normalizedQuery = normalizeClubSearch(query);
  for (final group in groups.entries) {
    final club = clubsById[group.key]!;
    final matchesClub =
        normalizedQuery.isNotEmpty && club.matches(normalizedQuery);
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
  // Newest created first; events with no creation time (samples) come
  // after, and ties fall back to the schedule order.
  entries.sort((a, b) {
    final aNew = a.event.createdAt ?? a.event.publishedAt;
    final bNew = b.event.createdAt ?? b.event.publishedAt;
    if (aNew != null && bNew != null && aNew != bNew) {
      return bNew.compareTo(aNew);
    }
    if ((aNew == null) != (bNew == null)) return aNew == null ? 1 : -1;
    return compare(a.event, b.event);
  });
  return entries;
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

/// The Home tab's "For You" feed: events from groups you follow or belong
/// to (only shown when there are some), then suggested events from
/// everyone else.
class HomeFeed {
  const HomeFeed({required this.followed, required this.suggested});

  /// Newest created first.
  final List<ClubFeedEntry> followed;

  /// Your campus society, faculty association and (for Froshies) First-Year
  /// Councils first, then everything else; newest created first within each.
  final List<ClubFeedEntry> suggested;
}

HomeFeed buildHomeFeed(
  Iterable<ClubEvent> events, {
  required DateTime now,
  required Set<String> followedClubIds,
  Set<String> priorityClubIds = const {},
}) {
  // Already newest-first.
  final entries = buildClubEventFeed(events, now: now, query: '');
  String? idOf(ClubFeedEntry e) => e.club?.id ?? e.event.clubId;
  final followed = <ClubFeedEntry>[];
  final priority = <ClubFeedEntry>[];
  final rest = <ClubFeedEntry>[];
  for (final entry in entries) {
    final id = idOf(entry);
    if (id != null && followedClubIds.contains(id)) {
      followed.add(entry);
    } else if (id != null && priorityClubIds.contains(id)) {
      priority.add(entry);
    } else {
      rest.add(entry);
    }
  }
  return HomeFeed(followed: followed, suggested: [...priority, ...rest]);
}

/// "Engineering" matches clubs in the Engineering catalog category, events
/// tagged `engineering`, or organizers named after the faculty.
bool eventMatchesFaculty(ClubEvent event, String faculty) {
  if (faculty.isEmpty) return false;
  // "Desautels Management" → "desautels"; "Arts & Science" → "arts".
  final key = faculty.toLowerCase().split(RegExp(r'[\s&]+')).first;
  final category = clubsById[event.clubId]?.category.toLowerCase() ?? '';
  return category.contains(key) ||
      event.tags.any((t) => t.toLowerCase().contains(key)) ||
      event.club.toLowerCase().contains(key);
}

/// Every listed event across campus, one card per event, newest created
/// first ("View All Events").
List<ClubEvent> allCampusEvents(Iterable<ClubEvent> events, DateTime now) {
  final listed = [
    for (final (i, e) in events.indexed)
      if (e.isListedAt(now)) (e, i),
  ];
  listed.sort((a, b) {
    final aNew = a.$1.createdAt ?? a.$1.publishedAt;
    final bNew = b.$1.createdAt ?? b.$1.publishedAt;
    if (aNew != null && bNew != null && aNew != bNew) {
      return bNew.compareTo(aNew);
    }
    if ((aNew == null) != (bNew == null)) return aNew == null ? 1 : -1;
    return a.$2.compareTo(b.$2);
  });
  return [for (final (e, _) in listed) e];
}
