import 'package:material_ui/material_ui.dart';

import 'student/edit_profile_page.dart';
import 'student/mcmap_theme.dart';
import 'student/settings_page.dart';
import 'student/student_profile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _rsvps = <_ClubEvent, StudentVisibility>{};
  final _rsvpVisibility = ValueNotifier(StudentVisibility.private);
  final _profileVisibility = ValueNotifier(StudentVisibility.private);
  StudentProfile _profile = const StudentProfile();
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
    return Theme(
      data: mcMapTheme,
      child: Builder(builder: _buildStudentShell),
    );
  }

  Widget _buildStudentShell(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final matchingEvents = _sampleEvents.where(
      (event) => event.matches(_query),
    );

    return Scaffold(
      appBar: AppBar(
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
                Text(
                  'Find club events',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
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
                Text(
                  'Club events',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Text('Sample events'),
                const SizedBox(height: 12),
                if (matchingEvents.isEmpty)
                  const Text('No club events match your search.'),
                for (final event in matchingEvents)
                  _EventCard(
                    event: event,
                    isGoing: _rsvps.containsKey(event),
                    onRsvp: () => _toggleRsvp(event),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Explore campus',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.map_rounded,
                        label: 'Campus map',
                        color: colorScheme.primaryContainer,
                        onTap: () => _selectDestination(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.school_rounded,
                        label: 'Buildings',
                        color: colorScheme.secondaryContainer,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.restaurant_rounded,
                        label: 'Dining',
                        color: colorScheme.tertiaryContainer,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.local_parking_rounded,
                        label: 'Parking',
                        color: colorScheme.surfaceContainerHighest,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Center(child: Text('Campus map is coming soon.')),
            ListView(
              primary: false,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(
                  'Your profile',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
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
                Text(
                  'Your RSVPs',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.title, style: Theme.of(context).textTheme.titleMedium),
            Text(event.club),
            const SizedBox(height: 4),
            Text(event.schedule),
            Text(event.location),
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

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 20),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
