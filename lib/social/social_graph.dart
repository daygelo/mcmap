import 'package:material_ui/material_ui.dart';

import '../data/academics.dart';

/// Your relationship to another student.
enum FriendStatus {
  /// Not connected: show "Add Friend".
  none,

  /// Sent to a private profile, waiting for them to accept.
  requested,

  /// Connected: they count toward your McGillians.
  following,
}

/// Another McGill student in the directory.
class McGillian {
  const McGillian({
    required this.name,
    required this.handle,
    required this.faculty,
    required this.major,
    required this.year,
    required this.mcgilliansCount,
    this.eventsCount = 0,
    this.clubsCount = 0,
    this.firstYearAtMcGill = false,
    this.isPrivate = false,
    this.bio = '',
  });

  final String name;

  /// Without the "@".
  final String handle;
  final String faculty;
  final String major;

  /// U-year or degree level, same as `StudentProfile.year`.
  final String year;
  final bool firstYearAtMcGill;

  /// Private profiles need to accept requests; public ones are followed
  /// immediately.
  final bool isPrivate;
  final String bio;

  /// Their McGillians count, not including you.
  final int mcgilliansCount;

  /// Events they've RSVPed to and clubs they're in.
  final int eventsCount;
  final int clubsCount;

  bool get isFroshie =>
      isFroshieStanding(year, firstYearAtMcGill: firstYearAtMcGill);

  String get initials => name
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  /// Search by name, handle, faculty or major. [query] is already lowercased.
  bool matches(String query) {
    final q = query.startsWith('@') ? query.substring(1) : query;
    return [
      name,
      handle,
      faculty,
      major,
    ].any((value) => value.toLowerCase().contains(q));
  }
}

/// Demo friend graph. Lives in memory until there's a backend.
class SocialGraph extends ChangeNotifier {
  SocialGraph({
    this.directory = sampleMcGillians,
    Set<String> following = const {'maya.t', 'leo.b', 'sofia.r'},
  }) : _status = {
         for (final handle in following) handle: FriendStatus.following,
       };

  final List<McGillian> directory;
  final Map<String, FriendStatus> _status;

  FriendStatus statusOf(McGillian student) =>
      _status[student.handle] ?? FriendStatus.none;

  /// "Add Friend": follows public profiles, requests private ones.
  void add(McGillian student) {
    _status[student.handle] = student.isPrivate
        ? FriendStatus.requested
        : FriendStatus.following;
    notifyListeners();
  }

  /// Cancels a request or removes a connection.
  void remove(McGillian student) {
    if (_status.remove(student.handle) != null) notifyListeners();
  }

  /// People you're connected to: your McGillians.
  List<McGillian> get connections => [
    for (final student in directory)
      if (statusOf(student) == FriendStatus.following) student,
  ];

  /// Their count as others see it, including you if you're connected.
  int countFor(McGillian student) =>
      student.mcgilliansCount +
      (statusOf(student) == FriendStatus.following ? 1 : 0);

  List<McGillian> search(String query) => [
    for (final student in directory)
      if (query.isEmpty || student.matches(query)) student,
  ];
}

const sampleMcGillians = [
  McGillian(
    name: 'Maya Tremblay',
    handle: 'maya.t',
    faculty: 'Science',
    major: 'Neuroscience',
    year: 'U2',
    mcgilliansCount: 214,
    eventsCount: 12,
    clubsCount: 5,
    bio: 'Neuro nerd, Gerts regular, always down for a study session.',
  ),
  McGillian(
    name: 'Leo Bergeron',
    handle: 'leo.b',
    faculty: 'Engineering',
    major: 'Mechanical Engineering',
    year: 'U3',
    mcgilliansCount: 98,
    eventsCount: 15,
    clubsCount: 4,
  ),
  McGillian(
    name: 'Sofia Rossi',
    handle: 'sofia.r',
    faculty: 'Arts',
    major: 'Political Science',
    year: 'U1',
    mcgilliansCount: 156,
    eventsCount: 5,
    clubsCount: 2,
  ),
  McGillian(
    name: 'Amir Haddad',
    handle: 'amir.h',
    faculty: 'Engineering',
    major: 'Software Engineering',
    year: 'U0',
    mcgilliansCount: 12,
    eventsCount: 14,
    clubsCount: 3,
    bio: 'New to Montreal! Looking for people to explore the city with.',
  ),
  McGillian(
    name: 'Chloé Gagnon',
    handle: 'chloe.g',
    faculty: 'Desautels Management',
    major: 'Finance',
    year: 'U1',
    firstYearAtMcGill: true,
    mcgilliansCount: 31,
    eventsCount: 16,
    clubsCount: 2,
    bio: 'Fresh out of CEGEP. Finance club + intramural volleyball.',
  ),
  McGillian(
    name: 'Daniel Okafor',
    handle: 'dan.okafor',
    faculty: 'Medicine & Health Sciences',
    major: 'Medicine',
    year: 'Professional',
    isPrivate: true,
    mcgilliansCount: 77,
    eventsCount: 11,
    clubsCount: 3,
  ),
  McGillian(
    name: 'Priya Natarajan',
    handle: 'priya.n',
    faculty: 'Science',
    major: 'Computer Science',
    year: 'Ph.D.',
    mcgilliansCount: 203,
    eventsCount: 18,
    clubsCount: 4,
  ),
  McGillian(
    name: 'Noah Lefebvre',
    handle: 'noah.l',
    faculty: 'Music',
    major: 'Jazz Performance',
    year: 'U2',
    isPrivate: true,
    mcgilliansCount: 64,
    eventsCount: 15,
    clubsCount: 5,
  ),
];
