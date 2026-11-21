/// A self-reported club selection and its independent preferences.
class ClubMembership {
  const ClubMembership({this.showOnProfile = false, this.autoRsvpEnabledAt});

  final bool showOnProfile;
  final DateTime? autoRsvpEnabledAt;

  ClubMembership copyWith({
    bool? showOnProfile,
    DateTime? autoRsvpEnabledAt,
    bool clearAutoRsvp = false,
  }) => ClubMembership(
    showOnProfile: showOnProfile ?? this.showOnProfile,
    autoRsvpEnabledAt: clearAutoRsvp
        ? null
        : autoRsvpEnabledAt ?? this.autoRsvpEnabledAt,
  );
}

/// Student profile shared by onboarding, the feed, and Profile.
class UserProfile {
  const UserProfile({
    required this.faculty,
    required this.major,
    this.year,
    this.interests = const {},
    this.bio = '',
    this.avatarUrl,
    this.memberships = const {},
    this.followedClubIds = const {},
    this.clubNotificationOptIns = const {},
  });

  final String faculty;
  final String major;
  final String? year;
  final Set<String> interests;
  final String bio;
  final String? avatarUrl;
  final Map<String, ClubMembership> memberships;
  final Set<String> followedClubIds;

  /// Enable times prevent notifications for events published before consent.
  final Map<String, DateTime> clubNotificationOptIns;

  Iterable<String> get displayedClubIds => memberships.entries
      .where((entry) => entry.value.showOnProfile)
      .map((entry) => entry.key);

  bool get hasInterests => interests.isNotEmpty;

  UserProfile copyWith({
    String? faculty,
    String? major,
    String? year,
    Set<String>? interests,
    String? bio,
    Map<String, ClubMembership>? memberships,
    Set<String>? followedClubIds,
    Map<String, DateTime>? clubNotificationOptIns,
  }) => UserProfile(
    faculty: faculty ?? this.faculty,
    major: major ?? this.major,
    year: year ?? this.year,
    interests: interests == null ? this.interests : Set.unmodifiable(interests),
    bio: bio ?? this.bio,
    avatarUrl: avatarUrl,
    memberships: memberships == null
        ? this.memberships
        : Map.unmodifiable(memberships),
    followedClubIds: followedClubIds == null
        ? this.followedClubIds
        : Set.unmodifiable(followedClubIds),
    clubNotificationOptIns: clubNotificationOptIns == null
        ? this.clubNotificationOptIns
        : Map.unmodifiable(clubNotificationOptIns),
  );

  UserProfile withClubIds(Set<String> ids) => copyWith(
    memberships: {
      for (final id in ids) id: memberships[id] ?? const ClubMembership(),
    },
  );
}
