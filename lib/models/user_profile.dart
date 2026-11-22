import '../data/academics.dart';

/// Academic onboarding data and independently editable club preferences.
class UserProfile {
  const UserProfile({
    required this.degreeLevel,
    required this.faculty,
    this.year,
    this.campus,
    this.firstYearAtMcGill = false,
    this.major,
    this.interests = const {},
    this.clubAutoRsvpOptIns = const {},
    this.followedClubIds = const {},
    this.clubNotificationOptIns = const {},
  }) : assert(degreeLevel != DegreeLevel.undergraduate || year != null),
       assert(degreeLevel == DegreeLevel.exchangeOrContinuing || major != null);

  final DegreeLevel degreeLevel;
  final AcademicCampus? campus;

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

  /// Explicit opt-ins retained for followed organizations.
  final Map<String, DateTime> clubAutoRsvpOptIns;
  final Set<String> followedClubIds;

  /// Enable times prevent notifications for events published before consent.
  final Map<String, DateTime> clubNotificationOptIns;

  bool get hasInterests => interests.isNotEmpty;

  /// "U2" for undergrads, otherwise the degree level ("Master's", "Ph.D.").
  String get standing => year ?? degreeLevel.shortLabel;

  UserProfile copyWith({
    Set<String>? interests,
    Map<String, DateTime>? clubAutoRsvpOptIns,
    Set<String>? followedClubIds,
    Map<String, DateTime>? clubNotificationOptIns,
  }) => UserProfile(
    degreeLevel: degreeLevel,
    year: year,
    campus: campus,
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
