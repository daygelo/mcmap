export 'db_values.dart';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../models/club_event.dart';
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
  });

  final String id;
  final String handle;
  final String fullName;
  final String? avatarUrl;
  final String bio;

  /// Null until onboarding (academic profile) is complete.
  final UserProfile? academics;

  bool get onboardingCompleted => academics != null;
}

/// Why the signed-in profile couldn't load. AuthGate shows a different
/// message for each instead of always blaming the connection.
enum ProfileLoadProblem {
  /// No connection / server unreachable. "Try again" may help.
  network,

  /// Session missing or expired. Signing in again fixes it.
  signedOut,

  /// A table, column or function the app needs doesn't exist, or a
  /// security rule blocks it: the Supabase migrations haven't all been run.
  databaseSetup,

  unknown,
}

class ProfileLoadException implements Exception {
  const ProfileLoadException(this.problem, this.detail);

  final ProfileLoadProblem problem;

  /// The underlying error, for logs and debug builds.
  final String detail;

  @override
  String toString() => 'ProfileLoadException(${problem.name}): $detail';
}

/// Everything the app reads from or writes to the server. The app runs
/// without one in demo mode (and in tests), using in-memory sample data.
abstract interface class McMapBackend {
  /// Bumped when the signed-in profile changes in a way that affects
  /// routing (e.g. onboarding finished). AuthGate listens to it.
  ValueListenable<int> get profileRevision;

  /// Loads (or creates) the signed-in user's profile. Throws
  /// [ProfileLoadException] on failure.
  Future<AccountProfile> loadMyProfile();

  /// Saves onboarding steps 2–3 and marks onboarding complete.
  Future<void> completeOnboarding(UserProfile profile);

  /// Saves Edit Profile changes (not the photo; see [uploadAvatar]).
  Future<void> updateProfile(StudentProfile profile);

  /// Uploads a new profile photo and returns its public URL.
  Future<String> uploadAvatar(Uint8List bytes);
  Future<void> removeAvatar();

  Future<List<ClubEvent>> fetchEvents();
  Future<Map<String, StudentVisibility>> fetchMyRsvps();

  /// Null cancels the RSVP.
  Future<void> setRsvp(String eventId, StudentVisibility? visibility);

  Future<List<McGillian>> searchMcGillians(String query);

  /// People you follow or have requested, with their status.
  Future<List<(McGillian, FriendStatus)>> fetchMyConnections();

  /// Returns the status the server settled on (requested for private
  /// profiles, following otherwise).
  Future<FriendStatus> addMcGillian(String profileId);
  Future<void> removeMcGillian(String profileId);

  // Clubs, by catalog id. Follows and memberships are independent.
  Future<void> setClubFollow(String clubId, {required bool following});

  /// Null turns event notifications off for a followed club.
  Future<void> setClubNotifications(String clubId, DateTime? enabledAt);

  /// Null removes the membership.
  Future<void> saveClubMembership(String clubId, ClubMembership? membership);

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
