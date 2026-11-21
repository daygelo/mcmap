/// An event shown in the student feed. Sample events have no publication data.
class ClubEvent {
  const ClubEvent(
    this.id,
    this.title,
    this.club,
    this.schedule,
    this.location, {
    this.clubId,
    this.publishedAt,
    this.startsAt,
    this.cancelled = false,
    this.supportsUnrestrictedRsvp = false,
  });

  final String id;
  final String title;
  final String club;
  final String schedule;
  final String location;
  final String? clubId;
  final DateTime? publishedAt;
  final DateTime? startsAt;
  final bool cancelled;

  /// Set by the publication source only for in-app RSVPs with no external
  /// registration, ticket, payment, approval or unconfirmed capacity.
  final bool supportsUnrestrictedRsvp;

  bool matches(String query) => [
    title,
    club,
    schedule,
    location,
  ].any((value) => value.toLowerCase().contains(query));
}
