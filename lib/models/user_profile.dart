/// What the user tells us during onboarding.
class UserProfile {
  const UserProfile({
    required this.faculty,
    required this.major,
    this.interests = const {},
  });

  final String faculty;
  final String major;

  /// May be empty if the user skipped the interests step. Feeds should then
  /// fall back to events from [faculty] plus popular campus-wide events.
  final Set<String> interests;

  bool get hasInterests => interests.isNotEmpty;

  UserProfile copyWith({Set<String>? interests}) => UserProfile(
    faculty: faculty,
    major: major,
    interests: interests ?? this.interests,
  );
}
