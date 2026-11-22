import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../backend/mcmap_backend.dart';
import '../data/academics.dart';
import '../models/club_event.dart';

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
    this.id,
    this.avatarUrl,
  });

  /// `profiles.id` when loaded from the server; null for demo students.
  final String? id;
  final String? avatarUrl;

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

/// Your McGillians. In demo mode it's an in-memory sample directory; with a
/// [backend] it starts empty and fills from the server (your connections,
/// plus search results as you type).
class SocialGraph extends ChangeNotifier {
  SocialGraph({
    List<McGillian> directory = sampleMcGillians,
    Set<String> following = const {'maya.t', 'leo.b', 'sofia.r'},
  }) : backend = null,
       _directory = [...directory],
       _status = {
         for (final handle in following) handle: FriendStatus.following,
       };

  /// Server-backed graph. Call [load] once to fetch your connections.
  SocialGraph.remote(McMapBackend this.backend) : _directory = [], _status = {};

  final McMapBackend? backend;
  final List<McGillian> _directory;
  final Map<String, FriendStatus> _status;

  /// Called when a server request fails (e.g. to show a snackbar).
  void Function(Object error)? onError;

  /// Called when the server has saved a change to your connections.
  VoidCallback? onConnectionsSaved;

  /// Goes up each time that happens.
  int savedConnections = 0;

  /// Loads the upcoming events a student is going to and lets you see.
  Future<List<ClubEvent>> Function(McGillian student)? loadGoing;

  /// Opens one of those events.
  ValueChanged<ClubEvent>? onOpenEvent;

  String? _lastRemoteQuery;
  Timer? _searchDebounce;
  bool _disposed = false;

  List<McGillian> get directory => List.unmodifiable(_directory);

  FriendStatus statusOf(McGillian student) =>
      _status[student.handle] ?? FriendStatus.none;

  Future<void> load() async {
    final backend = this.backend;
    if (backend == null) return;
    try {
      final connections = await backend.fetchMyConnections();
      for (final (student, status) in connections) {
        _merge(student);
        _status[student.handle] = status;
      }
      _notify();
    } catch (error) {
      onError?.call(error);
    }
  }

  /// "Add Friend": follows public profiles, requests private ones.
  void add(McGillian student) {
    final previous = _status[student.handle];
    _status[student.handle] = student.isPrivate
        ? FriendStatus.requested
        : FriendStatus.following;
    notifyListeners();
    final id = student.id;
    if (backend == null || id == null) return;
    backend!
        .addMcGillian(id)
        .then(
          (status) {
            _status[student.handle] = status;
            _connectionsSaved();
          },
          onError: (Object error) {
            _restore(student, previous);
            onError?.call(error);
          },
        );
  }

  /// Cancels a request or removes a connection.
  void remove(McGillian student) {
    final previous = _status.remove(student.handle);
    if (previous == null) return;
    notifyListeners();
    final id = student.id;
    if (backend == null || id == null) return;
    backend!
        .removeMcGillian(id)
        .then(
          (_) => _connectionsSaved(),
          onError: (Object error) {
            _restore(student, previous);
            onError?.call(error);
          },
        );
  }

  /// People you're connected to: your McGillians.
  List<McGillian> get connections => [
    for (final student in _directory)
      if (statusOf(student) == FriendStatus.following) student,
  ];

  /// Their count as others see it. Demo counts exclude you, so you're added
  /// when connected; server counts are already up to date.
  int countFor(McGillian student) =>
      student.mcgilliansCount +
      (backend == null && statusOf(student) == FriendStatus.following ? 1 : 0);

  /// The latest copy of [student].
  McGillian current(McGillian student) => _directory.firstWhere(
    (other) => other.handle == student.handle,
    orElse: () => student,
  );

  /// Your connections load without their stats; search results have them.
  Future<void> loadStats(McGillian student) async {
    final backend = this.backend;
    if (backend == null) return;
    try {
      final results = await backend.searchMcGillians(student.handle);
      results.where((found) => found.handle == student.handle).forEach(_merge);
      _notify();
    } catch (_) {
      // The rest of the profile is still useful.
    }
  }

  /// Matches from what's loaded so far. With a backend this also kicks off
  /// a server search; results arrive via [notifyListeners].
  List<McGillian> search(String query) {
    if (backend != null && query != _lastRemoteQuery) {
      _lastRemoteQuery = query;
      _searchDebounce?.cancel();
      _searchDebounce = Timer(
        const Duration(milliseconds: 250),
        () => _searchRemote(query),
      );
    }
    return [
      for (final student in _directory)
        if (query.isEmpty || student.matches(query)) student,
    ];
  }

  Future<void> _searchRemote(String query) async {
    try {
      final results = await backend!.searchMcGillians(query);
      if (query != _lastRemoteQuery) return;
      results.forEach(_merge);
      _notify();
    } catch (error) {
      onError?.call(error);
    }
  }

  void _merge(McGillian student) {
    final index = _directory.indexWhere((s) => s.handle == student.handle);
    if (index == -1) {
      _directory.add(student);
    } else {
      _directory[index] = student;
    }
  }

  void _restore(McGillian student, FriendStatus? previous) {
    if (previous == null) {
      _status.remove(student.handle);
    } else {
      _status[student.handle] = previous;
    }
    _notify();
  }

  void _connectionsSaved() {
    if (_disposed) return;
    savedConnections++;
    notifyListeners();
    onConnectionsSaved?.call();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounce?.cancel();
    super.dispose();
  }
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
