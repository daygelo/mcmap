import '../data/academics.dart';

/// What the user tells us during onboarding.
class UserProfile {
  const UserProfile({
    required this.degreeLevel,
    required this.faculty,
    this.year,
    this.firstYearAtMcGill = false,
    this.major,
    this.interests = const {},
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

  UserProfile copyWith({Set<String>? interests}) => UserProfile(
    degreeLevel: degreeLevel,
    year: year,
    firstYearAtMcGill: firstYearAtMcGill,
    faculty: faculty,
    major: major,
    interests: interests ?? this.interests,
  );
}
