import 'package:material_ui/material_ui.dart';

import '../data/club_event_feed.dart';
import '../models/club_event.dart';

enum _Filter {
  all('All'),
  froshie('Froshie'),
  faculty('Faculty'),
  following('Following');

  const _Filter(this.label);

  final String label;
}

class AllEventsPage extends StatefulWidget {
  const AllEventsPage({
    super.key,
    required this.events,
    required this.buildCard,
    required this.followedClubIds,
    required this.faculty,
  });

  static const routeName = '/events';

  final Iterable<ClubEvent> events;
  final Widget Function(ClubEvent event) buildCard;
  final Set<String> followedClubIds;
  final String faculty;

  @override
  State<AllEventsPage> createState() => _AllEventsPageState();
}

class _AllEventsPageState extends State<AllEventsPage> {
  _Filter _filter = _Filter.all;

  bool _matches(ClubEvent event) => switch (_filter) {
    _Filter.all => true,
    _Filter.froshie => event.isFrosh,
    _Filter.faculty => eventMatchesFaculty(event, widget.faculty),
    _Filter.following => widget.followedClubIds.contains(event.clubId),
  };

  @override
  Widget build(BuildContext context) {
    final all = allCampusEvents(widget.events, DateTime.now());
    final shown = all.where(_matches).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('All campus events')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: shown.isEmpty ? 2 : shown.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final filter in _Filter.values)
                          ChoiceChip(
                            label: Text(filter.label),
                            tooltip: filter == _Filter.faculty
                                ? widget.faculty
                                : null,
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                      ],
                    ),
                  );
                }
                if (shown.isEmpty) {
                  return const Text('No events match this filter yet.');
                }
                return widget.buildCard(shown[index - 1]);
              },
            ),
          ),
        ),
      ),
    );
  }
}
