import '../data/academics.dart';

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

/// Academic onboarding data and independently editable club preferences.
class UserProfile {
  const UserProfile({
    required this.degreeLevel,
    required this.faculty,
    this.year,
    this.firstYearAtMcGill = false,
    this.major,
    this.interests = const {},
    this.memberships = const {},
    this.followedClubIds = const {},
    this.clubNotificationOptIns = const {},
  }) : assert(degreeLevel != DegreeLevel.undergraduate || year != null),
       assert(degreeLevel == DegreeLevel.exchangeOrContinuing || major != null);

  final DegreeLevel degreeLevel;

  /// U-year ("U0"–"U4+"). Only set for undergraduates.
  final String? year;

  /// Answer to the U1 follow-up ("first year at McGill?"). Ignored otherwise.
  final bool firstYearAtMcGill;

  bool get isFroshie =>
      isFroshieStanding(year, firstYearAtMcGill: firstYearAtMcGill);

  final String faculty;

  /// May be [undeclaredMajor]. Null only for exchange/continuing students who
  /// left it blank.
  final String? major;

  /// May be empty if the user skipped the interests step. Feeds should then
  /// fall back to events for [faculty] and [standing] plus popular
  /// campus-wide events.
  final Set<String> interests;

  final Map<String, ClubMembership> memberships;
  final Set<String> followedClubIds;

  /// Enable times prevent notifications for events published before consent.
  final Map<String, DateTime> clubNotificationOptIns;

  Iterable<String> get displayedClubIds => memberships.entries
      .where((entry) => entry.value.showOnProfile)
      .map((entry) => entry.key);

  bool get hasInterests => interests.isNotEmpty;

  /// "U2" for undergrads, otherwise the degree level ("Master's", "Ph.D.").
  String get standing => year ?? degreeLevel.shortLabel;

  UserProfile copyWith({
    Set<String>? interests,
    Map<String, ClubMembership>? memberships,
    Set<String>? followedClubIds,
    Map<String, DateTime>? clubNotificationOptIns,
  }) => UserProfile(
    degreeLevel: degreeLevel,
    year: year,
    firstYearAtMcGill: firstYearAtMcGill,
    faculty: faculty,
    major: major,
    interests: interests == null ? this.interests : Set.unmodifiable(interests),
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
