import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../data/academics.dart';
import '../data/clubs.dart';
import '../models/club_event.dart';
import '../services/local_rsvps.dart';
import 'club_picker_page.dart';
import 'student/club_discovery.dart';
import 'student/club_profile.dart';
import 'student/edit_profile_page.dart';
import 'student/suggested_clubs.dart';
import 'student/your_clubs.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'student/settings_page.dart';
import 'student/student_profile.dart';
import '../social/mcgillian_widgets.dart';
import '../social/social_graph.dart';
import '../widgets/froshie_tag.dart';

/// Quick filters under the search bar.
enum _SearchScope {
  all('All'),
  events('Events'),
  mcgillians('McGillians');

  const _SearchScope(this.label);

  final String label;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.profile, this.publications});

  final UserProfile? profile;

  /// Optional prototype publication input. Production delivery is server-side.
  final Stream<ClubEvent>? publications;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _events = {for (final event in _sampleEvents) event.id: event};
  final _rsvps = LocalRsvps();
  final _clubUpdates = <String, ClubEvent>{};
  final _clubRevision = ValueNotifier(0);
  StreamSubscription<ClubEvent>? _publications;

  // Club relationships live in UserProfile. StudentProfile remains the
  // editable presentation, including Gabby's local photo and standing.
  late UserProfile _clubProfile =
      widget.profile ??
      const UserProfile(
        degreeLevel: DegreeLevel.undergraduate,
        faculty: 'Faculty of Engineering',
        major: 'Software Engineering',
        year: 'U0',
      );
  final _rsvpVisibility = ValueNotifier(StudentVisibility.private);
  final _profileVisibility = ValueNotifier(StudentVisibility.private);
  late StudentProfile _profile = switch (widget.profile) {
    final profile? => StudentProfile(
      faculty: profile.faculty,
      major: profile.major ?? 'Program not specified',
      year: profile.standing,
      firstYearAtMcGill: profile.firstYearAtMcGill,
      interests: Set.unmodifiable(profile.interests),
    ),
    null => const StudentProfile(),
  };
  final _social = SocialGraph();
  String _query = '';
  bool _followingOnly = false;
  _SearchScope _scope = _SearchScope.all;
  int _selectedIndex = 0;

  void _changeClubState(VoidCallback update) {
    setState(update);
    _clubRevision.value++;
  }

  void _toggleRsvp(ClubEvent event) {
    _changeClubState(() => _rsvps.toggle(event.id, _rsvpVisibility.value));
  }

  Future<void> _editClubs() async {
    final ids = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => ClubPickerPage(
          initialSelection: _clubProfile.memberships.keys.toSet(),
        ),
      ),
    );
    if (mounted && ids != null) {
      _changeClubState(() => _clubProfile = _clubProfile.withClubIds(ids));
    }
  }

  void _removeClub(String id) {
    _changeClubState(
      () => _clubProfile = _clubProfile.withClubIds(
        _clubProfile.memberships.keys.toSet()..remove(id),
      ),
    );
  }

  void _updateClub(String id, {bool? showOnProfile, bool? autoRsvp}) {
    final membership = _clubProfile.memberships[id];
    if (membership == null) return;
    _changeClubState(
      () => _clubProfile = _clubProfile.copyWith(
        memberships: {
          ..._clubProfile.memberships,
          id: membership.copyWith(
            showOnProfile: showOnProfile,
            autoRsvpEnabledAt: autoRsvp == true
                ? membership.autoRsvpEnabledAt ?? DateTime.now()
                : null,
            clearAutoRsvp: autoRsvp == false,
          ),
        },
      ),
    );
  }

  void _toggleFollow(String id) {
    final followed = {..._clubProfile.followedClubIds};
    final optIns = {..._clubProfile.clubNotificationOptIns};
    if (followed.remove(id)) {
      optIns.remove(id);
    } else {
      followed.add(id);
    }
    _changeClubState(
      () => _clubProfile = _clubProfile.copyWith(
        followedClubIds: followed,
        clubNotificationOptIns: optIns,
      ),
    );
  }

  void _setNotifications(String id, bool enabled) {
    if (!_clubProfile.followedClubIds.contains(id)) return;
    final optIns = {..._clubProfile.clubNotificationOptIns};
    if (enabled) {
      optIns.putIfAbsent(id, DateTime.now);
    } else {
      optIns.remove(id);
    }
    _changeClubState(
      () =>
          _clubProfile = _clubProfile.copyWith(clubNotificationOptIns: optIns),
    );
  }

  @override
  void initState() {
    super.initState();
    _listenForPublications();
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.publications != widget.publications) {
      _listenForPublications();
    }
  }

  void _listenForPublications() {
    unawaited(_publications?.cancel());
    _publications = widget.publications?.listen((event) {
      final now = DateTime.now();
      _changeClubState(() {
        final firstPublication = _events[event.id]?.publishedAt == null;
        final enabledAt = _clubProfile.clubNotificationOptIns[event.clubId];
        final publishedAt = event.publishedAt;
        if (firstPublication &&
            !event.cancelled &&
            enabledAt != null &&
            _clubProfile.followedClubIds.contains(event.clubId) &&
            publishedAt != null &&
            publishedAt.isAfter(enabledAt) &&
            !publishedAt.isAfter(now) &&
            (event.startsAt?.isAfter(now) ?? true)) {
          _clubUpdates.putIfAbsent(event.id, () => event);
        }
        _events[event.id] = event;
        _rsvps.onPublished(event, _clubProfile, now: now);
      });
    });
  }

  @override
  void dispose() {
    unawaited(_publications?.cancel());
    _clubRevision.dispose();
    _rsvpVisibility.dispose();
    _profileVisibility.dispose();
    _social.dispose();
    super.dispose();
  }

  void _openPage(BuildContext context, Widget page) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => InheritedTheme.captureAll(context, page),
      ),
    );
  }

  void _openLivePage(Widget Function() buildPage) {
    _openPage(
      context,
      ValueListenableBuilder(
        valueListenable: _clubRevision,
        builder: (_, _, _) => buildPage(),
      ),
    );
  }

  void _browseClubs() => _openLivePage(
    () => ClubDirectoryPage(
      followedIds: _clubProfile.followedClubIds,
      onFollow: _toggleFollow,
      onOpen: _openClub,
    ),
  );

  void _openFollowing() => _openLivePage(
    () => FollowingPage(
      followedIds: _clubProfile.followedClubIds,
      notificationIds: _clubProfile.clubNotificationOptIns.keys,
      onFollow: _toggleFollow,
      onOpen: _openClub,
      onBrowse: _browseClubs,
      onInbox: _openClubUpdates,
      inboxCount: _clubUpdates.length,
    ),
  );

  void _openClubUpdates() => _openLivePage(
    () => Scaffold(
      appBar: AppBar(title: const Text('Event updates')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('In-app demo updates. Push delivery is not connected.'),
            if (_clubUpdates.isEmpty) const Text('No new club events yet.'),
            for (final event in _clubUpdates.values.toList().reversed)
              ListTile(
                title: Text(event.title),
                subtitle: Text(clubsById[event.clubId]?.name ?? event.club),
                onTap: () => _openClubById(event.clubId),
              ),
          ],
        ),
      ),
    ),
  );

  void _openMemberships() => _openLivePage(
    () => Scaffold(
      appBar: AppBar(title: const Text('Your Club Memberships')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            YourClubs(
              memberships: _clubProfile.memberships,
              onEdit: _editClubs,
              onRemove: _removeClub,
              onVisibilityChanged: (id, value) =>
                  _updateClub(id, showOnProfile: value),
              onAutoRsvpChanged: (id, value) =>
                  _updateClub(id, autoRsvp: value),
              onOpenClub: _openClubById,
            ),
          ],
        ),
      ),
    ),
  );

  void _openClubById(String? id) {
    final club = clubsById[id];
    if (club != null) _openClub(club);
  }

  void _openClub(ClubOrganization club) => _openLivePage(() {
    final now = DateTime.now();
    return ClubDetailPage(
      club: club,
      following: _clubProfile.followedClubIds.contains(club.id),
      notifications: _clubProfile.clubNotificationOptIns.containsKey(club.id),
      onFollow: () => _toggleFollow(club.id),
      onNotifications: (value) => _setNotifications(club.id, value),
      eventCards: [
        for (final event in _events.values)
          if (event.clubId == club.id &&
              !event.cancelled &&
              (event.startsAt?.isAfter(now) ?? false) &&
              (event.publishedAt?.isAfter(now) == false))
            _eventCard(event, linkClub: false),
      ],
    );
  });

  Widget _eventCard(
    ClubEvent event, {
    bool linkClub = true,
    StudentVisibility? visibility,
  }) => _EventCard(
    event: event,
    isGoing: _rsvps.visibilityFor(event.id) != null,
    visibility: visibility,
    recommended: event.isFrosh && _profile.isFroshie,
    onRsvp: () => _toggleRsvp(event),
    onOpenClub: linkClub && clubsById.containsKey(event.clubId)
        ? () => _openClubById(event.clubId)
        : null,
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final matchingEvents = _events.values.where(
      (event) =>
          event.matches(_query) &&
          (!_followingOnly ||
              _clubProfile.followedClubIds.contains(event.clubId)),
    );
    final going = [
      for (final decision in _rsvps.decisions)
        if (decision.value case final visibility?)
          (_events[decision.key]!, visibility),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: McMapColors.red,
        foregroundColor: McMapColors.white,
        titleTextStyle: AppBarTheme.of(context).titleTextStyle?.copyWith(
          color: McMapColors.white,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
        title: const Text('McMap'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => _openPage(
              context,
              SettingsPage(
                rsvpVisibility: _rsvpVisibility,
                profileVisibility: _profileVisibility,
              ),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            ListView(
              primary: false,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text('Find club events', style: text.headlineMedium),
                const SizedBox(height: 16),
                SearchBar(
                  hintText: 'Search events, clubs or McGillians',
                  leading: const Icon(Icons.search_rounded),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) {
                    setState(() => _query = value.trim().toLowerCase());
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final scope in _SearchScope.values)
                      ChoiceChip(
                        label: Text(scope.label),
                        selected: scope == _scope,
                        onSelected: (_) => setState(() => _scope = scope),
                      ),
                  ],
                ),
                // Students only show up once you search (or pick the
                // McGillians filter), so the default view stays an event feed.
                if (_scope == _SearchScope.mcgillians ||
                    (_scope == _SearchScope.all && _query.isNotEmpty))
                  ..._mcgillianResults(text),
                if (_scope != _SearchScope.mcgillians) ...[
                  const SizedBox(height: 16),
                  SuggestedClubs(
                    faculty: _profile.faculty,
                    major: _profile.major,
                    interests: _profile.interests,
                    followedClubIds: _clubProfile.followedClubIds,
                    onFollow: _toggleFollow,
                    onOpen: _openClub,
                    onBrowse: _browseClubs,
                  ),
                  const SizedBox(height: 24),
                  Text('Club events', style: text.titleLarge),
                  Text('Sample events', style: text.bodySmall),
                  if (widget.profile != null) ...[
                    const SizedBox(height: 8),
                    Text('${_profile.major} · ${_profile.faculty}'),
                    if (_profile.interests.isEmpty)
                      Text(
                        'Showing events for ${_profile.year} '
                        '${_profile.faculty} students and popular campus '
                        'events. Add interests later from Edit Profile.',
                      )
                    else
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final interest in _profile.interests)
                            Chip(label: Text(interest)),
                        ],
                      ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All Events'),
                        selected: !_followingOnly,
                        onSelected: (_) =>
                            setState(() => _followingOnly = false),
                      ),
                      ChoiceChip(
                        label: const Text('Following'),
                        selected: _followingOnly,
                        onSelected: (_) =>
                            setState(() => _followingOnly = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_followingOnly && _clubProfile.followedClubIds.isEmpty)
                    const Text('Follow clubs to see their events here.')
                  else if (matchingEvents.isEmpty)
                    Text(
                      _followingOnly
                          ? 'No events from your followed clubs match right now.'
                          : 'No club events match your search.',
                    ),
                  for (final event in matchingEvents) _eventCard(event),
                ],
              ],
            ),
            const Center(child: Text('Campus map is coming soon.')),
            ListView(
              primary: false,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text('Your profile', style: text.headlineMedium),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: _social,
                  builder: (context, _) => ProfileHeader(
                    profile: _profile,
                    onPhotoChanged: (bytes) => _changeClubState(
                      () => _profile = _profile.withPhoto(bytes),
                    ),
                    mcgilliansCount: _social.connections.length,
                    onMcGilliansTap: () =>
                        showMcGilliansSheet(context, _social),
                    eventsCount: going.length,
                    clubsCount: {
                      for (final (event, _) in going)
                        event.clubId ?? event.club,
                    }.length,
                    onEdit: () => _openPage(
                      context,
                      EditProfilePage(
                        profile: _profile,
                        onSave: (profile) async =>
                            _changeClubState(() => _profile = profile),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _openMemberships,
                      child: Text(
                        '${_clubProfile.memberships.length} Club Memberships',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _openFollowing,
                      child: Text(
                        '${_clubProfile.followedClubIds.length} Following',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ProfileClubMemberships(
                  profile: _clubProfile,
                  onOpen: _openClub,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _openLivePage(
                      () => ValueListenableBuilder(
                        valueListenable: _profileVisibility,
                        builder: (_, visibility, _) => PublicProfilePreview(
                          profile: _clubProfile,
                          presentation: _profile,
                          visibility: visibility,
                        ),
                      ),
                    ),
                    child: const Text('Preview Public Profile'),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Your RSVPs', style: text.titleLarge),
                if (going.isEmpty) const Text('You have no RSVPs yet.'),
                for (final (event, visibility) in going)
                  _eventCard(event, visibility: visibility),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectDestination,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  /// Under "All" only the top few students show, with a jump to the full list.
  List<Widget> _mcgillianResults(TextTheme text) {
    const preview = 3;
    final matches = _social.search(_query);
    final showAll = _scope == _SearchScope.mcgillians;
    if (matches.isEmpty && !showAll) return const [];
    final shown = showAll ? matches : matches.take(preview);

    return [
      const SizedBox(height: 24),
      Text(
        _query.isEmpty ? 'Suggested McGillians' : 'McGillians',
        style: text.titleLarge,
      ),
      const SizedBox(height: 4),
      if (matches.isEmpty) const Text('No McGillians match your search.'),
      for (final student in shown)
        McGillianTile(graph: _social, student: student),
      if (!showAll && matches.length > preview)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _scope = _SearchScope.mcgillians),
            child: Text('See all ${matches.length} McGillians'),
          ),
        ),
    ];
  }

  void _selectDestination(int index) {
    FocusScope.of(context).unfocus();
    setState(() => _selectedIndex = index);
  }
}

const _sampleEvents = [
  ClubEvent(
    'sample-board-game-night',
    'Board Game Night',
    'Board Games Club',
    'Tuesday · 6 PM',
    'University Centre',
  ),
  ClubEvent(
    'sample-frosh-week-kickoff',
    'Frosh Week Kickoff',
    'SSMU Frosh Committee',
    'Monday · 7 PM',
    'Lower Field',
    isFrosh: true,
  ),
  ClubEvent(
    'sample-photo-walk',
    'Photo Walk',
    'Photography Club',
    'Thursday · 4 PM',
    'Arts Building',
  ),
  ClubEvent(
    'sample-coding-meetup',
    'Campus Coding Meetup',
    'Computer Science Club',
    'Friday · 5 PM',
    'Trottier Building',
  ),
];

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.isGoing,
    required this.onRsvp,
    this.visibility,
    this.recommended = false,
    this.onOpenClub,
  });

  final ClubEvent event;
  final bool isGoing;
  final StudentVisibility? visibility;
  final VoidCallback onRsvp;
  final VoidCallback? onOpenClub;

  /// Frosh event shown to a Froshie.
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.isFrosh) ...[
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const FroshieTag(),
                  if (recommended)
                    Text('Recommended for you', style: text.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(event.title, style: text.titleMedium),
            if (onOpenClub == null)
              Text(event.club, style: text.bodySmall)
            else
              TextButton(onPressed: onOpenClub, child: Text(event.club)),
            const SizedBox(height: 4),
            Text(event.schedule, style: text.bodySmall),
            Text(event.location, style: text.bodySmall),
            if (visibility case final audience?)
              Text('Going · Demo visibility: ${audience.label}'),
            const SizedBox(height: 8),
            if (isGoing)
              OutlinedButton(
                onPressed: onRsvp,
                child: const Text('Cancel RSVP'),
              )
            else
              FilledButton(onPressed: onRsvp, child: const Text('RSVP')),
          ],
        ),
      ),
    );
  }
}
