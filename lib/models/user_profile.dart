import '../data/academics.dart';

/// Follow, notification, and Auto-RSVP preferences for any account.
class OrganizationPreferences {
  const OrganizationPreferences({
    this.clubAutoRsvpOptIns = const {},
    this.followedClubIds = const {},
    this.clubNotificationOptIns = const {},
  });

  final Map<String, DateTime> clubAutoRsvpOptIns;
  final Set<String> followedClubIds;
  final Map<String, DateTime> clubNotificationOptIns;

  OrganizationPreferences copyWith({
    Map<String, DateTime>? clubAutoRsvpOptIns,
    Set<String>? followedClubIds,
    Map<String, DateTime>? clubNotificationOptIns,
  }) => OrganizationPreferences(
    clubAutoRsvpOptIns: clubAutoRsvpOptIns == null
        ? this.clubAutoRsvpOptIns
        : Map.unmodifiable(clubAutoRsvpOptIns),
    followedClubIds: followedClubIds == null
        ? this.followedClubIds
        : Set.unmodifiable(followedClubIds),
    clubNotificationOptIns: clubNotificationOptIns == null
        ? this.clubNotificationOptIns
        : Map.unmodifiable(clubNotificationOptIns),
  );
}

/// Academic onboarding data and independently editable club preferences.
class UserProfile extends OrganizationPreferences {
  const UserProfile({
    required this.degreeLevel,
    required this.faculty,
    this.year,
    this.firstYearAtMcGill = false,
    this.major,
    this.interests = const {},
    super.clubAutoRsvpOptIns,
    super.followedClubIds,
    super.clubNotificationOptIns,
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

  bool get hasInterests => interests.isNotEmpty;

  /// "U2" for undergrads, otherwise the degree level ("Master's", "Ph.D.").
  String get standing => year ?? degreeLevel.shortLabel;

  @override
  UserProfile copyWith({
    Set<String>? interests,
    Map<String, DateTime>? clubAutoRsvpOptIns,
    Set<String>? followedClubIds,
    Map<String, DateTime>? clubNotificationOptIns,
  }) => UserProfile(
    degreeLevel: degreeLevel,
    year: year,
    firstYearAtMcGill: firstYearAtMcGill,
    faculty: faculty,
    major: major,
    interests: interests == null ? this.interests : Set.unmodifiable(interests),
    clubAutoRsvpOptIns: clubAutoRsvpOptIns == null
        ? this.clubAutoRsvpOptIns
        : Map.unmodifiable(clubAutoRsvpOptIns),
    followedClubIds: followedClubIds == null
        ? this.followedClubIds
        : Set.unmodifiable(followedClubIds),
    clubNotificationOptIns: clubNotificationOptIns == null
        ? this.clubNotificationOptIns
        : Map.unmodifiable(clubNotificationOptIns),
  );
}
