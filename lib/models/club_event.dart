/// An event shown in the student feed. Sample events have no publication data.
class ClubEvent {
  const ClubEvent(
    this.id,
    this.title,
    this.club,
    this.schedule,
    this.location, {
    this.isFrosh = false,
    this.clubId,
    this.publishedAt,
    this.startsAt,
    this.description,
    this.synopsis,
    this.clubAvatarUrl,
    this.latitude,
    this.longitude,
    this.tags = const [],
    this.cancelled = false,
    this.supportsUnrestrictedRsvp = false,
  });

  final String id;
  final String title;
  final String club;
  final String schedule;
  final String location;
  final bool isFrosh;
  final String? clubId;
  final DateTime? publishedAt;
  final DateTime? startsAt;
  final String? description;

  /// 1–2 sentence AI-generated TL;DR of [description], shown on feed cards
  /// with an "AI Summary" label. Generated server-side when the event is
  /// published (TODO(ai): wire up the summarizer); null until then.
  final String? synopsis;

  /// The hosting group's picture (`groups.avatar_url`).
  final String? clubAvatarUrl;

  /// Venue coordinates for the RSVP map.
  final double? latitude;
  final double? longitude;
  final List<String> tags;
  final bool cancelled;

  /// Set by the publication source only for in-app RSVPs with no external
  /// registration, ticket, payment, approval or unconfirmed capacity.
  final bool supportsUnrestrictedRsvp;

  bool isListedAt(DateTime now) => publishedAt?.isAfter(now) != true;

  bool isUpcomingAt(DateTime now) =>
      !cancelled && (startsAt?.isAfter(now) ?? false);

  bool canRsvpAt(DateTime now) =>
      !cancelled && startsAt?.isAfter(now) != false && isListedAt(now);

  bool matchesDetails(String query) => [
    title,
    schedule,
    location,
  ].any((value) => value.toLowerCase().contains(query));

  bool matches(String query) =>
      matchesDetails(query) || club.toLowerCase().contains(query);
}
