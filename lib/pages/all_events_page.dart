import 'package:material_ui/material_ui.dart';

import '../data/club_event_feed.dart';
import '../models/club_event.dart';
import '../theme/app_theme.dart';

enum _Filter { all, froshie, faculty, following }

/// "View All Events": every event across campus, one card each, newest
/// created first, with quick filters. Opened from the Home feed.
class AllEventsPage extends StatefulWidget {
  const AllEventsPage({
    super.key,
    required this.events,
    required this.buildCard,
    required this.followedClubIds,
    this.faculty = '',
  });

  final Iterable<ClubEvent> events;

  /// The Home tab's event card, so RSVPs and navigation behave the same.
  final Widget Function(ClubEvent event) buildCard;
  final Set<String> followedClubIds;
  final String faculty;

  static const routeName = '/events';

  @override
  State<AllEventsPage> createState() => _AllEventsPageState();
}

class _AllEventsPageState extends State<AllEventsPage> {
  _Filter _filter = _Filter.all;

  String _label(_Filter filter) => switch (filter) {
    _Filter.all => 'All',
    _Filter.froshie => 'Froshie',
    _Filter.faculty => widget.faculty,
    _Filter.following => 'Following',
  };

  bool _matches(ClubEvent event) => switch (_filter) {
    _Filter.all => true,
    _Filter.froshie => event.isFrosh,
    _Filter.faculty => eventMatchesFaculty(event, widget.faculty),
    _Filter.following => widget.followedClubIds.contains(event.clubId),
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final all = allCampusEvents(widget.events, DateTime.now());
    final shown = all.where(_matches).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('All campus events')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(
                  'Every event from McGill clubs and societies, newest first.',
                  style: text.bodyMedium?.copyWith(color: McMapColors.slate),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final filter in _Filter.values)
                      if (filter != _Filter.faculty ||
                          widget.faculty.isNotEmpty)
                        ChoiceChip(
                          label: Text(_label(filter)),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${shown.length} of ${all.length} events',
                  style: text.bodySmall?.copyWith(color: McMapColors.slate),
                ),
                const SizedBox(height: 12),
                if (shown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No events match this filter yet.'),
                  ),
                for (final event in shown) widget.buildCard(event),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
