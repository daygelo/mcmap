import 'package:material_ui/material_ui.dart';

import 'student/edit_profile_page.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'student/settings_page.dart';
import 'student/student_profile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.profile});

  final UserProfile? profile;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _rsvps = <_ClubEvent, StudentVisibility>{};
  final _rsvpVisibility = ValueNotifier(StudentVisibility.private);
  final _profileVisibility = ValueNotifier(StudentVisibility.private);
  late StudentProfile _profile = switch (widget.profile) {
    final profile? => StudentProfile(
      faculty: profile.faculty,
      major: profile.major,
      interests: Set.unmodifiable(profile.interests),
    ),
    null => const StudentProfile(),
  };
  String _query = '';
  int _selectedIndex = 0;

  void _toggleRsvp(_ClubEvent event) {
    setState(() {
      if (_rsvps.remove(event) == null) {
        _rsvps[event] = _rsvpVisibility.value;
      }
    });
  }

  @override
  void dispose() {
    _rsvpVisibility.dispose();
    _profileVisibility.dispose();
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final matchingEvents = _sampleEvents.where(
      (event) => event.matches(_query),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: McMapColors.red,
        foregroundColor: McMapColors.white,
        titleTextStyle: AppBarTheme.of(context).titleTextStyle
            ?.copyWith(color: McMapColors.white, fontWeight: FontWeight.w700),
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
                  hintText: 'Search clubs or events',
                  leading: const Icon(Icons.search_rounded),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) {
                    setState(() => _query = value.trim().toLowerCase());
                  },
                ),
                const SizedBox(height: 24),
                Text('Club events', style: text.titleLarge),
                Text('Sample events', style: text.bodySmall),
                if (widget.profile != null) ...[
                  const SizedBox(height: 8),
                  Text('${_profile.major} · ${_profile.faculty}'),
                  if (_profile.interests.isEmpty)
                    const Text('Add interests later from Edit Profile.')
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
                if (matchingEvents.isEmpty)
                  const Text('No club events match your search.'),
                for (final event in matchingEvents)
                  _EventCard(
                    event: event,
                    isGoing: _rsvps.containsKey(event),
                    onRsvp: () => _toggleRsvp(event),
                  ),
              ],
            ),
            const Center(child: Text('Campus map is coming soon.')),
            ListView(
              primary: false,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text('Your profile', style: text.headlineMedium),
                const SizedBox(height: 12),
                ProfileHeader(
                  profile: _profile,
                  onEdit: () => _openPage(
                    context,
                    EditProfilePage(
                      profile: _profile,
                      onSave: (profile) async =>
                          setState(() => _profile = profile),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Your RSVPs', style: text.titleLarge),
                if (_rsvps.isEmpty) const Text('You have no RSVPs yet.'),
                for (final entry in _rsvps.entries)
                  _EventCard(
                    event: entry.key,
                    isGoing: true,
                    visibility: entry.value,
                    onRsvp: () => _toggleRsvp(entry.key),
                  ),
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

  void _selectDestination(int index) {
    FocusScope.of(context).unfocus();
    setState(() => _selectedIndex = index);
  }
}

class _ClubEvent {
  const _ClubEvent(this.title, this.club, this.schedule, this.location);

  final String title;
  final String club;
  final String schedule;
  final String location;

  bool matches(String query) => [
    title,
    club,
    schedule,
    location,
  ].any((value) => value.toLowerCase().contains(query));
}

const _sampleEvents = [
  _ClubEvent(
    'Board Game Night',
    'Board Games Club',
    'Tuesday · 6 PM',
    'University Centre',
  ),
  _ClubEvent(
    'Photo Walk',
    'Photography Club',
    'Thursday · 4 PM',
    'Arts Building',
  ),
  _ClubEvent(
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
  });

  final _ClubEvent event;
  final bool isGoing;
  final StudentVisibility? visibility;
  final VoidCallback onRsvp;

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
            Text(event.title, style: text.titleMedium),
            Text(event.club, style: text.bodySmall),
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
