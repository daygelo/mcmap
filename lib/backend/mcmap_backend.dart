import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../data/academics.dart';
import '../data/campus_groups.dart';
import '../models/app_notification.dart';
import '../models/club_event.dart';
import '../models/friend_rsvps.dart';
import '../models/student_visibility.dart';
import '../models/user_profile.dart';
import '../pages/student/student_profile.dart';
import '../social/social_graph.dart';

/// The signed-in student's row in `profiles`.
class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.handle,
    required this.fullName,
    this.avatarUrl,
    this.bio = '',
    this.academics,
    this.rsvpVisibility = StudentVisibility.defaultForRsvps,
  });

  final String id;
  final String handle;
  final String fullName;
  final String? avatarUrl;
  final String bio;

  /// Null until onboarding (academic profile) is complete.
  final UserProfile? academics;

  /// Who can see the RSVPs they make next.
  final StudentVisibility rsvpVisibility;

  bool get onboardingCompleted => academics != null;
}

/// An organization verified by the server for the current publisher.
class PublishingGroup {
  const PublishingGroup({required this.id, required this.name});

  final String id;
  final String name;
}

/// The server does not expose the table used to load organization follows.
class OrganizationFollowsUnavailable implements Exception {
  const OrganizationFollowsUnavailable();
}

/// Everything the app reads from or writes to the server. The app runs
/// without one in demo mode (and in tests), using in-memory sample data.
abstract interface class McMapBackend {
  /// Bumped when the signed-in profile changes in a way that affects
  /// routing (e.g. onboarding finished). AuthGate listens to it.
  ValueListenable<int> get profileRevision;

  Future<AccountProfile> loadMyProfile();

  /// Saves onboarding steps 2–3 and marks onboarding complete.
  Future<void> completeOnboarding(UserProfile profile);

  /// Keys are followed catalog IDs. A timestamp represents explicit auto-RSVP consent.
  /// Throws [OrganizationFollowsUnavailable] when the follows table is missing.
  Future<Map<String, DateTime?>> fetchOrganizationFollows();

  Future<void> setOrganizationFollow(String id, bool following);
  Future<DateTime?> setOrganizationAutoRsvp(String id, bool enabled);

  /// Public organizations keyed by the same stable slugs as events.
  Future<Map<String, CampusGroup>> fetchOrganizations();

  /// Saves Edit Profile changes (not the photo; see [uploadAvatar]).
  Future<void> updateProfile(StudentProfile profile);

  /// Uploads a new profile photo and returns its public URL.
  Future<String> uploadAvatar(Uint8List bytes);
  Future<void> removeAvatar();

  Future<List<ClubEvent>> fetchEvents();

  /// Null when it was deleted or isn't published.
  Future<ClubEvent?> fetchEvent(String id);
  Future<List<PublishingGroup>> fetchPublishingGroups();
  Future<ClubEvent> publishEvent({
    required String eventId,
    required String groupId,
    required String title,
    required String description,
    required DateTime startsAt,
    DateTime? endsAt,
    required String location,
  });

  Future<Map<String, StudentVisibility>> fetchMyRsvps();

  /// Null cancels the RSVP.
  Future<void> setRsvp(String eventId, StudentVisibility? visibility);

  /// Saves who can see RSVPs from now on. Existing ones don't change.
  Future<void> setRsvpVisibility(StudentVisibility visibility);

  /// Events another student is going to, as far as they let you see.
  Future<List<ClubEvent>> fetchRsvpsOf(String profileId);

  /// Your McGillians going to upcoming events, by event id. Events with none
  /// are left out, as are RSVPs their owner keeps private.
  Future<Map<String, FriendRsvps>> fetchFriendRsvps();

  /// The most recent notifications.
  Future<List<AppNotification>> fetchNotifications();

  /// Asks the server to write any of your reminders that are due.
  Future<void> refreshNotifications();

  /// Marks one notification read, or all of them without an [id].
  Future<void> markNotificationsRead({String? id});

  /// Fires whenever your notifications may have changed.
  Stream<void> watchNotifications();

  Future<List<McGillian>> searchMcGillians(String query);

  /// People you follow or have requested, with their status.
  Future<List<(McGillian, FriendStatus)>> fetchMyConnections();

  /// Returns the status the server settled on (requested for private
  /// profiles, following otherwise).
  Future<FriendStatus> addMcGillian(String profileId);
  Future<void> removeMcGillian(String profileId);

  Future<void> signOut();
}

/// Makes the backend available to pages pushed on the navigator (it sits
/// above MaterialApp). Absent in demo mode.
class BackendScope extends InheritedWidget {
  const BackendScope({super.key, required this.backend, required super.child});

  final McMapBackend backend;

  static McMapBackend? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BackendScope>()?.backend;

  @override
  bool updateShouldNotify(BackendScope oldWidget) =>
      backend != oldWidget.backend;
}

// ---------------------------------------------------------------------------
// App ↔ database value mapping
// ---------------------------------------------------------------------------

const degreeLevelDbValues = {
  DegreeLevel.undergraduate: 'undergraduate',
  DegreeLevel.masters: 'masters',
  DegreeLevel.doctorate: 'doctorate',
  DegreeLevel.professional: 'professional',
  DegreeLevel.exchangeOrContinuing: 'exchange_continuing',
};

DegreeLevel? degreeLevelFromDb(Object? value) => degreeLevelDbValues.entries
    .where((e) => e.value == value)
    .map((e) => e.key)
    .firstOrNull;

/// 'U4+' ↔ 'U4_plus'; other U-years are the same.
String? uYearToDb(String? year) => year == 'U4+' ? 'U4_plus' : year;
String? uYearFromDb(Object? value) =>
    value == 'U4_plus' ? 'U4+' : value as String?;

/// Edit Profile's single "Year / degree level" value → (degree, U-year).
(DegreeLevel, String?) standingToDb(String standing) {
  if (academicYears.contains(standing)) {
    return (DegreeLevel.undergraduate, standing);
  }
  final level = DegreeLevel.values.firstWhere(
    (l) => l.shortLabel == standing,
    orElse: () => DegreeLevel.undergraduate,
  );
  return (level, level.hasUYear ? 'U0' : null);
}

String visibilityToDb(StudentVisibility v) => v.name;
StudentVisibility visibilityFromDb(Object? value) =>
    StudentVisibility.values.firstWhere(
      (v) => v.name == value,
      orElse: () => StudentVisibility.private,
    );
