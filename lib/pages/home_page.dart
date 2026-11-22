import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:material_ui/material_ui.dart';

import '../backend/mcmap_backend.dart';
import '../data/academics.dart';
import '../data/campus_groups.dart';
import '../data/club_event_feed.dart';
import '../data/clubs.dart';
import '../models/club_event.dart';
import '../models/student_visibility.dart';
import '../services/local_rsvps.dart';
import 'all_events_page.dart';
import 'create_event_page.dart';
import 'event_details_page.dart';
import 'map_page.dart';
import 'organization_page.dart';
import 'student/club_discovery.dart';
import 'student/edit_profile_page.dart';
import 'student/suggested_clubs.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'student/settings_page.dart';
import 'student/student_profile.dart';
import '../social/mcgillian_widgets.dart';
import '../social/social_graph.dart';
import '../widgets/event_bits.dart';
import '../widgets/froshie_tag.dart';
import '../widgets/group_type_badge.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/mcmap_logo.dart';

/// Quick filters under the search bar.
enum _SearchScope {
  all('All'),
  events('Events'),
  mcgillians('McGillians');

  const _SearchScope(this.label);

  final String label;
}

enum _EventDiscovery {
  forYou('For You'),
  following('Following'),
  discover('Discover Clubs');

  const _EventDiscovery(this.label);

  final String label;
}

enum _Destination { home, map, create, profile }

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.profile,
    this.publications,
    this.account,
    this.backend,
  });

  final UserProfile? profile;

  /// Name, handle, photo and bio from `profiles` (signed-in only).
  final AccountProfile? account;

  /// Loads events, RSVPs and McGillians from the server and saves changes.
  /// Null = offline demo with sample data.
  final McMapBackend? backend;

  /// Optional prototype publication input. Production delivery is server-side.
  final Stream<ClubEvent>? publications;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Map<String, ClubEvent> _events = {
    if (widget.backend == null)
      for (final event in _sampleEvents) event.id: event,
  };
  bool _loadingEvents = false;
  Future<bool>? _organizationFollowsLoad;
  bool _usingLocalOrganizationFollows = false;
  final _pendingOrganizationChanges = <String>{};
  Map<String, CampusGroup> _organizations = const {};

  /// Organizations outside the bundled catalog. Signed in, the server decides
  /// which exist; the offline demo uses the bundled list.
  Map<String, CampusGroup> get _otherOrganizations => {
    if (widget.backend == null)
      for (final group in campusGroups) group.id: group,
    for (final event in _events.values)
      if (event.clubId case final id?
          when !clubsById.containsKey(id) && event.club.isNotEmpty)
        id: CampusGroup(id: id, name: event.club, type: event.clubType),
    for (final entry in _organizations.entries)
      if (!clubsById.containsKey(entry.key)) entry.key: entry.value,
  };
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
  late StudentProfile _profile = switch (widget.profile) {
    final profile? => StudentProfile(
      name: switch (widget.account?.fullName.trim()) {
        final name? when name.isNotEmpty => name,
        _ => 'McMap Student',
      },
      faculty: profile.faculty,
      major: profile.major ?? 'Program not specified',
      year: profile.standing,
      firstYearAtMcGill: profile.firstYearAtMcGill,
      interests: Set.unmodifiable(profile.interests),
      bio: widget.account?.bio ?? '',
      avatarUrl: widget.account?.avatarUrl,
      handle: widget.account?.handle,
    ),
    null => const StudentProfile(),
  };
  late final SocialGraph _social = switch (widget.backend) {
    final backend? => SocialGraph.remote(backend),
    null => SocialGraph(),
  };
  final _homeScroll = ScrollController();
  final _suggestedEventsHeading = GlobalKey();
  final _homeSearch = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  _EventDiscovery _discovery = _EventDiscovery.forYou;
  _SearchScope _scope = _SearchScope.all;
  _Destination _destination = _Destination.home;
  bool _hasOpenedMap = false;
  List<PublishingGroup> _publishingGroups = const [];
  final _publishedDuringLoad = <String, ClubEvent>{};

  List<_Destination> get _destinations => [
    _Destination.home,
    _Destination.map,
    if (_publishingGroups.isNotEmpty) _Destination.create,
    _Destination.profile,
  ];

  /// Filter pills only show while you're searching, so the default home
  /// screen stays a clean event feed.
  bool get _showSearchFilters =>
      _searchFocus.hasFocus || _query.isNotEmpty || _scope != _SearchScope.all;

  void _onSearchFocusChanged() => setState(() {});

  /// Clears the search and collapses the filter pills.
  void _closeSearch() {
    _homeSearch.clear();
    _searchFocus.unfocus();
    setState(() {
      _query = '';
      _scope = _SearchScope.all;
    });
  }

  void _changeClubState(VoidCallback update) {
    setState(update);
    _clubRevision.value++;
  }

  void _toggleRsvp(ClubEvent event) {
    final current = _events[event.id] ?? event;
    if (_rsvps.visibilityFor(event.id) == null &&
        !current.canRsvpAt(DateTime.now())) {
      return;
    }
    final previous = _rsvps.visibilityFor(event.id);
    _changeClubState(() => _rsvps.toggle(event.id, _rsvpVisibility.value));
    final backend = widget.backend;
    if (backend == null) return;
    backend.setRsvp(event.id, _rsvps.visibilityFor(event.id)).catchError((
      Object _,
    ) {
      if (!mounted) return;
      _changeClubState(() => _rsvps.set(event.id, previous));
      _showError("Couldn't save your RSVP. Try again.");
    });
  }

  Future<bool> _loadOrganizationFollows(McMapBackend backend) async {
    try {
      final follows = await backend.fetchOrganizationFollows();
      if (!mounted) return false;
      _changeClubState(() {
        _clubProfile = _clubProfile.copyWith(
          followedClubIds: follows.keys.toSet(),
          clubAutoRsvpOptIns: {
            for (final entry in follows.entries) entry.key: ?entry.value,
          },
        );
      });
      return true;
    } on OrganizationFollowsUnavailable {
      if (!mounted) return false;
      _changeClubState(() => _usingLocalOrganizationFollows = true);
      return true;
    } catch (_) {
      _organizationFollowsLoad = null;
      if (mounted) {
        _showError(
          "Couldn't load followed organizations. Try following a group to retry.",
        );
      }
      return false;
    }
  }

  Future<void> _toggleFollow(String id) async {
    final backend = widget.backend;
    final following = !_clubProfile.followedClubIds.contains(id);
    if (backend == null || _usingLocalOrganizationFollows) {
      _changeOrganizationFollow(id, following);
      return;
    }
    if (!_pendingOrganizationChanges.add(id)) return;
    try {
      final loaded = await (_organizationFollowsLoad ??=
          _loadOrganizationFollows(backend));
      if (!mounted || !loaded) return;
      if (_clubProfile.followedClubIds.contains(id) == following) return;
      final notificationOptIn = _clubProfile.clubNotificationOptIns[id];
      final autoRsvpOptIn = _clubProfile.clubAutoRsvpOptIns[id];
      _changeOrganizationFollow(id, following);
      if (_usingLocalOrganizationFollows) return;
      try {
        await backend.setOrganizationFollow(id, following);
      } catch (_) {
        if (!mounted) return;
        _changeOrganizationFollow(
          id,
          !following,
          notificationOptIn: notificationOptIn,
          autoRsvpOptIn: autoRsvpOptIn,
        );
        _showError("Couldn't update Following. Try again.");
      }
    } finally {
      _pendingOrganizationChanges.remove(id);
      if (mounted) _clubRevision.value++;
    }
  }

  void _changeOrganizationFollow(
    String id,
    bool following, {
    DateTime? notificationOptIn,
    DateTime? autoRsvpOptIn,
  }) {
    final followed = {..._clubProfile.followedClubIds};
    final optIns = {..._clubProfile.clubNotificationOptIns};
    final autoRsvps = {..._clubProfile.clubAutoRsvpOptIns};
    if (following) {
      followed.add(id);
      if (notificationOptIn != null) optIns[id] = notificationOptIn;
      if (autoRsvpOptIn != null) autoRsvps[id] = autoRsvpOptIn;
    } else {
      followed.remove(id);
      optIns.remove(id);
      autoRsvps.remove(id);
    }
    _changeClubState(
      () => _clubProfile = _clubProfile.copyWith(
        followedClubIds: followed,
        clubNotificationOptIns: optIns,
        clubAutoRsvpOptIns: autoRsvps,
      ),
    );
  }

  ValueChanged<bool>? _autoRsvpAction(String id) =>
      _pendingOrganizationChanges.contains(id)
      ? null
      : (enabled) => _setAutoRsvp(id, enabled);

  Future<void> _setAutoRsvp(String id, bool enabled) async {
    if (!_clubProfile.followedClubIds.contains(id) ||
        !_pendingOrganizationChanges.add(id)) {
      return;
    }
    _clubRevision.value++;
    try {
      final backend = widget.backend;
      final timestamp = backend == null || _usingLocalOrganizationFollows
          ? (enabled ? DateTime.now() : null)
          : await backend.setOrganizationAutoRsvp(id, enabled);
      if (!mounted) return;
      final optIns = {..._clubProfile.clubAutoRsvpOptIns};
      if (timestamp == null) {
        optIns.remove(id);
      } else {
        optIns[id] = timestamp;
      }
      _changeClubState(
        () => _clubProfile = _clubProfile.copyWith(clubAutoRsvpOptIns: optIns),
      );
    } catch (_) {
      if (mounted) {
        _showError("Couldn't save your auto-RSVP preference. Try again.");
      }
    } finally {
      _pendingOrganizationChanges.remove(id);
      if (mounted) _clubRevision.value++;
    }
  }

  Future<void> _loadOrganizations(McMapBackend backend) async {
    try {
      final groups = await backend.fetchOrganizations();
      if (mounted) _changeClubState(() => _organizations = groups);
    } catch (_) {
      // Event organizers and the bundled club directory remain available.
    }
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
    _searchFocus.addListener(_onSearchFocusChanged);
    _social.onError = (_) {
      _showError("Couldn't update your McGillians.");
    };
    _social.addListener(_onSocialChanged);
    _listenForPublications();
    if (widget.backend case final backend?) {
      unawaited(_loadFromServer());
      _organizationFollowsLoad = _loadOrganizationFollows(backend);
      unawaited(_loadOrganizations(backend));
    }
    if (widget.account != null && widget.backend != null) {
      unawaited(_loadPublishingGroups(widget.backend!));
    }
  }

  Future<void> _loadPublishingGroups(McMapBackend backend) async {
    try {
      final groups = await backend.fetchPublishingGroups();
      if (mounted) setState(() => _publishingGroups = groups);
    } catch (_) {
      // Discovery remains available if publisher verification fails.
    }
  }

  void _onEventPublished(ClubEvent event) {
    _changeClubState(() {
      if (_loadingEvents) _publishedDuringLoad[event.id] = event;
      _events[event.id] = event;
      _destination = _Destination.home;
    });
    _openEvent(event);
    _showError('Event published.');
  }

  /// Search results for McGillians arrive asynchronously.
  void _onSocialChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadFromServer() async {
    final backend = widget.backend!;
    setState(() => _loadingEvents = true);
    try {
      final (events, rsvps) = await (
        backend.fetchEvents(),
        backend.fetchMyRsvps(),
        _social.load(),
      ).wait.then((r) => (r.$1, r.$2));
      if (!mounted) return;
      _changeClubState(() {
        _events
          ..clear()
          ..addEntries(events.map((e) => MapEntry(e.id, e)))
          ..addAll(_publishedDuringLoad);
        _publishedDuringLoad.clear();
        _rsvps.restore(rsvps);
        _loadingEvents = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingEvents = false;
        _publishedDuringLoad.clear();
      });
      _showError("Couldn't load events. Pull to refresh or try again later.");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changePhoto(Uint8List? bytes) async {
    final backend = widget.backend;
    // Instant preview; the server copy follows.
    _changeClubState(() => _profile = _profile.withPhoto(bytes));
    if (backend == null) return;
    try {
      if (bytes == null) {
        await backend.removeAvatar();
      } else {
        final url = await backend.uploadAvatar(bytes);
        if (!mounted) return;
        _changeClubState(
          () => _profile = _profile.withPhotoUrl(url, preview: bytes),
        );
      }
    } catch (error) {
      _showError("Couldn't save your photo. Try again.");
    }
  }

  Future<void> _saveProfile(StudentProfile profile) async {
    final backend = widget.backend;
    if (backend != null) {
      await backend.updateProfile(profile);
      final bytes = profile.avatarBytes;
      if (bytes != null && bytes != _profile.avatarBytes) {
        profile = profile.withPhotoUrl(
          await backend.uploadAvatar(bytes),
          preview: bytes,
        );
      } else if (!profile.hasPhoto && _profile.hasPhoto) {
        await backend.removeAvatar();
      }
    }
    if (mounted) _changeClubState(() => _profile = profile);
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
    _homeScroll.dispose();
    _homeSearch.dispose();
    _searchFocus.dispose();
    _clubRevision.dispose();
    _rsvpVisibility.dispose();
    _social
      ..removeListener(_onSocialChanged)
      ..dispose();
    super.dispose();
  }

  /// [route] names the screen (e.g. `/events/:id`) for future deep links.
  void _openPage(BuildContext context, Widget page, {String? route}) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: RouteSettings(name: route),
        builder: (_) => InheritedTheme.captureAll(context, page),
      ),
    );
  }

  void _openLivePage(Widget Function() buildPage, {String? route}) {
    _openPage(
      context,
      ValueListenableBuilder(
        valueListenable: _clubRevision,
        builder: (_, _, _) => buildPage(),
      ),
      route: route,
    );
  }

  void _browseClubs({String query = ''}) => _openLivePage(
    () => ClubDirectoryPage(
      initialQuery: query,
      organizations: _otherOrganizations,
      onOpenOrganization: _openGroup,
      followedIds: _clubProfile.followedClubIds,
      onFollow: _toggleFollow,
      onOpen: _openClub,
    ),
  );

  void _openFollowing() => _openLivePage(
    () => FollowingPage(
      temporaryPreferences: _usingLocalOrganizationFollows,
      organizations: _otherOrganizations,
      onOpenOrganization: _openGroup,
      autoRsvpIds: _clubProfile.clubAutoRsvpOptIns.keys,
      autoRsvpAction: _autoRsvpAction,
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
                onTap: () => _openOrganizer(event),
              ),
          ],
        ),
      ),
    ),
  );

  void _openClub(ClubOrganization club) => _openLivePage(() {
    final schedule = ClubEventSchedule(_events.values, club.id, DateTime.now());
    List<Widget> cards(Iterable<ClubEvent> events) => [
      for (final event in events) _eventCard(event, insideClub: true),
    ];
    return ClubDetailPage(
      club: club,
      following: _clubProfile.followedClubIds.contains(club.id),
      notifications: _clubProfile.clubNotificationOptIns.containsKey(club.id),
      onFollow: () => _toggleFollow(club.id),
      onNotifications: (value) => _setNotifications(club.id, value),
      autoRsvp: _clubProfile.clubAutoRsvpOptIns.containsKey(club.id),
      onAutoRsvp: _autoRsvpAction(club.id),
      upcoming: cards(schedule.upcoming),
      past: cards(schedule.past.take(5)),
      undated: cards(schedule.undated),
      cancelled: cards(schedule.cancelled),
    );
  });

  void _openGroup(String id, String name) => _openLivePage(
    () => OrganizationPage(
      id: id,
      name: name,
      group: _otherOrganizations[id],
      following: _clubProfile.followedClubIds.contains(id),
      onFollow: () => _toggleFollow(id),
      autoRsvp: _clubProfile.clubAutoRsvpOptIns.containsKey(id),
      onAutoRsvp: _autoRsvpAction(id),
    ),
    route: OrganizationPage.routeFor(id),
  );

  void _openOrganizer(ClubEvent event) {
    final id = event.clubId;
    final club = clubsById[id];
    if (club != null) return _openClub(club);
    if (id != null && id.isNotEmpty) return _openGroup(id, event.club);

    final routeId = OrganizationPage.idFor(event.club);
    _openPage(
      context,
      OrganizationPage(id: routeId, name: event.club),
      route: OrganizationPage.routeFor(routeId),
    );
  }

  void _openEvent(ClubEvent event) => _openLivePage(() {
    final current = _events[event.id] ?? event;
    return EventDetailsPage(
      event: current,
      isGoing: _rsvps.visibilityFor(current.id) != null,
      canRsvp: current.canRsvpAt(DateTime.now()),
      recommended: current.isFrosh && _profile.isFroshie,
      onRsvp: () => _toggleRsvp(current),
      onOpenClub: current.club.isEmpty ? null : () => _openOrganizer(current),
    );
  }, route: EventDetailsPage.routeFor(event.id));

  Widget _eventCard(
    ClubEvent event, {
    bool insideClub = false,
    StudentVisibility? visibility,
    ClubFeedEntry? feedEntry,
  }) {
    final now = DateTime.now();
    return _EventCard(
      event: event,
      isGoing: _rsvps.visibilityFor(event.id) != null,
      visibility: visibility,
      recommended: event.isFrosh && _profile.isFroshie,
      canRsvp: event.canRsvpAt(now),
      upcoming: event.isUpcomingAt(now),
      feedEntry: feedEntry,
      previewLabel: _query.isEmpty ? 'Next event' : 'Matching event',
      onRsvp: () => _toggleRsvp(event),
      showOrganizer: !insideClub,
      onOpenDetails: () => _openEvent(event),
      onOpenClub: insideClub || event.club.isEmpty
          ? null
          : () => _openOrganizer(event),
    );
  }

  void _openAllEvents() => _openLivePage(
    () => AllEventsPage(
      events: _events.values,
      buildCard: _eventCard,
      followedClubIds: _clubProfile.followedClubIds,
      faculty: _profile.faculty,
    ),
    route: AllEventsPage.routeName,
  );

  void _jumpToSuggestedEvents() {
    if (_suggestedEventsHeading.currentContext case final heading?) {
      unawaited(
        Scrollable.ensureVisible(
          heading,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  List<Widget> _forYouFeed(TextTheme text, DateTime now) {
    final followedIds = _clubProfile.followedClubIds;
    final entries = buildClubEventFeed(
      _events.values.where(
        (event) => followedIds.contains(event.clubId)
            ? event.isUpcomingAt(now)
            : event.canRsvpAt(now),
      ),
      now: now,
      query: '',
      groupAllOrganizations: true,
    );
    final followed = <ClubFeedEntry>[];
    final suggested = <ClubFeedEntry>[];
    for (final entry in entries) {
      (followedIds.contains(entry.event.clubId) ? followed : suggested).add(
        entry,
      );
    }

    return [
      // Keep the jump action and its target mounted in the same scroll child.
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (followed.isNotEmpty) ...[
            Text('From groups you follow', style: text.titleLarge),
            if (followed.length >= 3)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _jumpToSuggestedEvents,
                  child: const Text('Jump to suggested events'),
                ),
              ),
            const SizedBox(height: 8),
            for (final entry in followed)
              _eventCard(entry.event, feedEntry: entry),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
          ],
          Row(
            key: _suggestedEventsHeading,
            children: [
              Expanded(child: Text('Suggested events', style: text.titleLarge)),
              TextButton(
                onPressed: _openAllEvents,
                child: const Text('View all'),
              ),
            ],
          ),
        ],
      ),
      if (suggested.isEmpty) const Text('No upcoming events right now.'),
      for (final entry in suggested.take(6))
        _eventCard(entry.event, feedEntry: entry),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _openAllEvents,
        icon: const Icon(Icons.event_note_rounded),
        label: const Text('View All Events'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final showForYou = _discovery == _EventDiscovery.forYou && _query.isEmpty;
    final organizations = _otherOrganizations;
    final matchingEvents = showForYou
        ? const <ClubFeedEntry>[]
        : buildClubEventFeed(
            _events.values,
            now: now,
            query: _query,
            followedOnly: _discovery == _EventDiscovery.following
                ? _clubProfile.followedClubIds
                : null,
            matchesOrganization: (id) =>
                organizations[id]?.searchRank(_query) != null,
          );
    final going = [
      for (final decision in _rsvps.decisions)
        if (decision.value case final visibility?)
          (_events[decision.key]!, visibility),
    ];

    final selectedIndex = _destinations.indexOf(_destination);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: McMapColors.red,
        foregroundColor: McMapColors.white,
        titleTextStyle: AppBarTheme.of(context).titleTextStyle?.copyWith(
          color: McMapColors.white,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
        title: const McMapWordmark(color: McMapColors.white),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => _openPage(
              context,
              SettingsPage(rsvpVisibility: _rsvpVisibility),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          if (widget.backend case final backend?)
            IconButton(
              tooltip: 'Sign out',
              onPressed: backend.signOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: selectedIndex,
          children: [
            ListView(
              controller: _homeScroll,
              primary: false,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                SearchBar(
                  controller: _homeSearch,
                  focusNode: _searchFocus,
                  trailing: [
                    if (_showSearchFilters)
                      TextFieldTapRegion(
                        child: TextButton(
                          onPressed: _closeSearch,
                          child: const Text('Cancel'),
                        ),
                      ),
                  ],
                  hintText: 'Search events, clubs or McGillians',
                  leading: const Icon(Icons.search_rounded),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _query = value.trim().toLowerCase();
                      if (_query.isNotEmpty &&
                          _discovery == _EventDiscovery.discover) {
                        _discovery = _EventDiscovery.forYou;
                      }
                    });
                  },
                ),
                // Counts as part of the search field, so tapping a pill
                // doesn't unfocus the search and hide the pills mid-tap.
                TextFieldTapRegion(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topLeft,
                    child: _showSearchFilters
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Wrap(
                              spacing: 8,
                              children: [
                                for (final scope in _SearchScope.values)
                                  ChoiceChip(
                                    label: Text(scope.label),
                                    selected: scope == _scope,
                                    onSelected: (_) =>
                                        setState(() => _scope = scope),
                                  ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ),
                // Students only show up once you search (or pick the
                // McGillians filter), so the default view stays an event feed.
                if (_scope == _SearchScope.mcgillians ||
                    (_scope == _SearchScope.all && _query.isNotEmpty))
                  ..._mcgillianResults(text),
                if (_scope == _SearchScope.all && _query.isNotEmpty)
                  ..._clubSearchResults(text),
                if (_scope != _SearchScope.mcgillians) ...[
                  const SizedBox(height: 24),
                  Text('Club events', style: text.titleLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final mode in _EventDiscovery.values)
                        ChoiceChip(
                          label: Text(mode.label),
                          selected: _discovery == mode,
                          onSelected: (_) => setState(() => _discovery = mode),
                        ),
                    ],
                  ),
                  Visibility(
                    visible: _discovery == _EventDiscovery.discover,
                    maintainState: true,
                    child: SuggestedClubs(
                      faculty: _profile.faculty,
                      major: _profile.major,
                      interests: _profile.interests,
                      followedClubIds: _clubProfile.followedClubIds,
                      onFollow: _toggleFollow,
                      onOpen: _openClub,
                      onBrowse: _browseClubs,
                    ),
                  ),
                  if (_discovery != _EventDiscovery.discover) ...[
                    const SizedBox(height: 8),
                    if (widget.backend == null)
                      Text('Sample events', style: text.bodySmall),
                    const SizedBox(height: 12),
                    if (_loadingEvents)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (showForYou)
                      ..._forYouFeed(text, now)
                    else ...[
                      if (_discovery == _EventDiscovery.following &&
                          _clubProfile.followedClubIds.isEmpty)
                        const Text('Follow clubs to see their events here.')
                      else if (matchingEvents.isEmpty)
                        Text(
                          _discovery == _EventDiscovery.following
                              ? 'No events from your followed clubs match right now.'
                              : 'No club events match your search.',
                        ),
                      for (final entry in matchingEvents)
                        _eventCard(entry.event, feedEntry: entry),
                    ],
                  ],
                ],
              ],
            ),
            if (_hasOpenedMap)
              McGillMapPage(
                events: [for (final (event, _) in going) event],
                onOpenEvent: _openEvent,
                onOpenOrganization: (id) {
                  if (clubsById[id] case final club?) _openClub(club);
                },
              )
            else
              const SizedBox.shrink(),
            if (_publishingGroups.isNotEmpty)
              CreateEventPage(
                backend: widget.backend!,
                groups: _publishingGroups,
                onPublished: _onEventPublished,
              ),
            ListView(
              key: const ValueKey(_Destination.profile),
              primary: false,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text('Your profile', style: text.headlineMedium),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: _social,
                  builder: (context, _) => ProfileHeader(
                    profile: _profile,
                    onPhotoChanged: _changePhoto,
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
                      EditProfilePage(profile: _profile, onSave: _saveProfile),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: _openFollowing,
                    child: Text(
                      '${_clubProfile.followedClubIds.length} Following',
                    ),
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
        selectedIndex: selectedIndex,
        onDestinationSelected: _selectDestination,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          if (_publishingGroups.isNotEmpty)
            const NavigationDestination(
              icon: Icon(Icons.add_circle_outline_rounded),
              selectedIcon: Icon(Icons.add_circle_rounded),
              label: 'Create',
            ),
          const NavigationDestination(
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

  List<Widget> _clubSearchResults(TextTheme text) {
    final query = normalizeClubSearch(_query);
    if (query.isEmpty) return const [];
    final matches = searchOrganizations(query, _otherOrganizations.values);
    if (matches.isEmpty) return const [];

    const previewSize = 5;
    return [
      const SizedBox(height: 24),
      Text('Clubs & organizations', style: text.titleLarge),
      for (final match in matches.take(previewSize))
        if (match.group case final group?)
          OrganizationRow(
            key: ValueKey(group.id),
            group: group,
            compact: true,
            following: _clubProfile.followedClubIds.contains(group.id),
            onOpen: () => _openGroup(group.id, group.name),
            onFollow: () => _toggleFollow(group.id),
          )
        else if (match.club case final club?)
          ClubRow(
            key: ValueKey(club.id),
            club: club,
            compact: true,
            following: _clubProfile.followedClubIds.contains(club.id),
            onOpen: () => _openClub(club),
            onFollow: () => _toggleFollow(club.id),
          ),
      if (matches.length > previewSize)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _browseClubs(query: _homeSearch.text),
            child: Text('See all ${matches.length} organizations'),
          ),
        ),
    ];
  }

  void _selectDestination(int index) {
    FocusScope.of(context).unfocus();
    final destination = _destinations[index];
    if (destination == _destination) {
      if (destination == _Destination.home && _homeScroll.hasClients) {
        unawaited(
          _homeScroll.animateTo(
            _homeScroll.position.minScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          ),
        );
      }
      return;
    }
    setState(() {
      _destination = destination;
      if (destination == _Destination.map) _hasOpenedMap = true;
    });
  }
}

// Sample synopses stand in for the AI summarizer's output.
const _sampleEvents = [
  ClubEvent(
    'sample-board-game-night',
    'Board Game Night',
    'Board Games Club',
    'Tuesday · 6 PM',
    'University Centre',
    description:
        'Join the Board Games Club for our weekly open game night! We bring '
        'over 60 games, from quick party games like Codenames and Just One to '
        'longer strategy games like Catan, Wingspan and Terraforming Mars. '
        'No experience needed: our volunteers will teach you the rules and '
        'help you find a table. Snacks and drinks are provided, and you are '
        'welcome to bring your own games too. Drop in any time between 6 and '
        '10 PM, alone or with friends.',
    synopsis:
        'Weekly drop-in game night with 60+ games, from party games to '
        'strategy. Beginners welcome; volunteers teach the rules.',
  ),
  ClubEvent(
    'sample-frosh-week-kickoff',
    'Frosh Week Kickoff',
    'SSMU Frosh Committee',
    'Monday · 7 PM',
    'Lower Field',
    isFrosh: true,
    description:
        'Welcome to McGill! Frosh Week starts here. Meet your Frosh group '
        'and leaders, pick up your Frosh kit and t-shirt, and get the full '
        'schedule for the week. There will be music, food trucks, games on '
        'the field and a short welcome from SSMU. The event is alcohol-free '
        'and open to all first-year students, including U0s and U1s coming '
        'from CEGEP. Bring your student ID to check in. In case of rain, the '
        'kickoff moves to the SSMU Ballroom.',
    synopsis:
        'Kick off Frosh Week on Lower Field: meet your Frosh group, grab your '
        'kit, and enjoy music, food trucks and games. Bring your student ID.',
  ),
  ClubEvent(
    'sample-photo-walk',
    'Photo Walk',
    'Photography Club',
    'Thursday · 4 PM',
    'Arts Building',
    description:
        'Explore downtown campus and Mount Royal through a lens. We meet on '
        'the steps of the Arts Building and walk up to the Kondiaronk '
        'Belvedere for golden hour, stopping for shots along the way. Any '
        'camera works, including your phone. Club members will share quick '
        'tips on composition and light. The walk takes about two hours, so '
        'wear comfortable shoes and dress for the weather.',
    synopsis:
        'A two-hour golden-hour walk from the Arts Building up Mount Royal. '
        'Any camera works, phones included.',
  ),
  ClubEvent(
    'sample-coding-meetup',
    'Campus Coding Meetup',
    'Computer Science Club',
    'Friday · 5 PM',
    'Trottier Building',
    description:
        'Bring a laptop and a project, or come find one. This casual meetup '
        'is for students of every faculty who want to code together, ask '
        'questions and get feedback. Upper-year mentors will be around to '
        'help with assignments, personal projects and interview prep. We '
        'will also have a short lightning-talk segment where anyone can '
        'demo what they are building. Pizza at 6.',
    synopsis:
        'Casual co-working session with upper-year mentors for help on '
        'projects and interview prep, plus lightning talks and pizza.',
  ),
];

/// Feed card. Tapping the club avatar opens the club page; tapping anywhere
/// else (except the buttons) opens the event details page.
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.isGoing,
    required this.onRsvp,
    required this.canRsvp,
    required this.upcoming,
    required this.previewLabel,
    required this.showOrganizer,
    this.feedEntry,
    this.visibility,
    this.onOpenDetails,
    this.recommended = false,
    this.onOpenClub,
  });

  final ClubEvent event;
  final bool isGoing;
  final bool canRsvp;
  final bool upcoming;
  final bool showOrganizer;
  final String previewLabel;
  final ClubFeedEntry? feedEntry;
  final VoidCallback? onOpenDetails;
  final StudentVisibility? visibility;
  final VoidCallback onRsvp;
  final VoidCallback? onOpenClub;

  /// Frosh event shown to a Froshie.
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final club = feedEntry?.club;
    final clubName = club?.name ?? event.club;
    final groupType = (club ?? clubsById[event.clubId])?.type ?? event.clubType;
    final more = feedEntry?.additionalEvents ?? 0;
    final schedule = formatEventSchedule(context, event);
    final muted = text.bodySmall?.copyWith(color: McMapColors.slate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenDetails,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showOrganizer && clubName.isNotEmpty) ...[
                Row(
                  children: [
                    InitialsAvatar(
                      name: clubName,
                      image: switch (event.clubAvatarUrl) {
                        final url? => NetworkImage(url),
                        null => null,
                      },
                      onTap: onOpenClub,
                      semanticLabel: 'Open $clubName page',
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clubName,
                            style: text.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (groupType != null || (club != null && upcoming))
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (groupType != null)
                                    GroupTypeBadge(groupType),
                                  if (club != null && upcoming)
                                    Text(previewLabel, style: muted),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
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
              Text(event.title, style: text.titleLarge),
              const SizedBox(height: 4),
              if (schedule.isNotEmpty) Text(schedule, style: muted),
              if (event.location.isNotEmpty) Text(event.location, style: muted),
              if (event.cancelled)
                const Text('Cancelled')
              else if (event.startsAt == null)
                Text('Schedule unconfirmed', style: muted)
              else if (!upcoming)
                const Text('Past event'),
              if (event.synopsis != null || event.description != null) ...[
                const SizedBox(height: 10),
                EventSynopsis(event: event),
              ],
              if (visibility case final audience?)
                Text('Going · Demo visibility: ${audience.label}'),
              if (more > 0) Text('$more more from this club', style: muted),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (isGoing)
                    OutlinedButton(
                      onPressed: onRsvp,
                      child: const Text('Cancel RSVP'),
                    )
                  else if (canRsvp)
                    FilledButton(onPressed: onRsvp, child: const Text('RSVP')),
                  if (club != null && onOpenClub != null)
                    TextButton(
                      onPressed: onOpenClub,
                      child: const Text('View club events'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
