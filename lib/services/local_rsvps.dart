import '../models/club_event.dart';
import '../models/student_visibility.dart';
import '../models/user_profile.dart';

/// In-memory RSVP decisions for the prototype. Null records a cancellation,
/// so reprocessing a publication cannot undo the user's decision.
class LocalRsvps {
  final _decisions = <String, StudentVisibility?>{};

  Iterable<MapEntry<String, StudentVisibility?>> get decisions =>
      _decisions.entries;

  StudentVisibility? visibilityFor(String eventId) => _decisions[eventId];

  /// Replaces everything with RSVPs loaded from the server.
  void restore(Map<String, StudentVisibility> saved) {
    _decisions
      ..clear()
      ..addAll(saved);
  }

  void applyVisibility(StudentVisibility visibility) {
    _decisions.updateAll((_, current) => current == null ? null : visibility);
  }

  /// Puts back a decision after a failed save.
  void set(String eventId, StudentVisibility? visibility) {
    _decisions.remove(eventId);
    _decisions[eventId] = visibility;
  }

  void toggle(String eventId, StudentVisibility visibility) {
    final previous = _decisions.remove(eventId);
    _decisions[eventId] = previous == null ? visibility : null;
  }

  void onPublished(
    ClubEvent event,
    OrganizationPreferences profile, {
    required DateTime now,
    StudentVisibility visibility = StudentVisibility.private,
  }) {
    if (!profile.followedClubIds.contains(event.clubId)) return;
    final enabledAt = profile.clubAutoRsvpOptIns[event.clubId];
    final publishedAt = event.publishedAt;
    final startsAt = event.startsAt;
    if (enabledAt == null ||
        publishedAt == null ||
        !publishedAt.isAfter(enabledAt) ||
        publishedAt.isAfter(now) ||
        startsAt == null ||
        !event.canRsvpAt(now) ||
        event.cancelled ||
        !event.supportsUnrestrictedRsvp) {
      return;
    }

    _decisions.putIfAbsent(event.id, () => visibility);
  }
}
