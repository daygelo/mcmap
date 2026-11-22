import 'package:material_ui/material_ui.dart';

import '../data/clubs.dart';

/// Returns a draft selection on save, or null when the student goes back.
class ClubPickerPage extends StatefulWidget {
  const ClubPickerPage({
    super.key,
    this.academicIds = const {},
    this.initialSelection,
  });

  final Set<String> academicIds;
  final Set<String>? initialSelection;

  @override
  State<ClubPickerPage> createState() => _ClubPickerPageState();
}

class _ClubPickerPageState extends State<ClubPickerPage> {
  late final _selected = {...(widget.initialSelection ?? widget.academicIds)};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final matches = downtownClubCatalog
        .where((club) => club.matches(_query))
        .toList();
    final ordered = [
      ...matches.where((club) => widget.academicIds.contains(club.id)),
      ...matches.where((club) => !widget.academicIds.contains(club.id)),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Step 3 of 3')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Which groups would you like to follow?',
                          style: text.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Follow McGill clubs, departments, and organizations to see their events. You can always change this later.',
                        ),
                        if (widget.academicIds.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Your student associations are preselected. You can unselect any of them.',
                          ),
                        ],
                        const SizedBox(height: 16),
                        SearchBar(
                          hintText: 'Search clubs by name or alias',
                          leading: const Icon(Icons.search_rounded),
                          onChanged: (value) => setState(
                            () => _query = normalizeClubSearch(value),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text('${_selected.length} selected'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (matches.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text('No organizations match your search.'),
                    ),
                  ),
                SliverList.builder(
                  itemCount: ordered.length,
                  itemBuilder: (context, index) {
                    final club = ordered[index];
                    return CheckboxListTile(
                      key: ValueKey(club.id),
                      title: Text(club.name),
                      subtitle: Text(
                        widget.academicIds.contains(club.id)
                            ? 'Student association · ${club.category}'
                            : '${club.type.label} · ${club.category}',
                      ),
                      value: _selected.contains(club.id),
                      onChanged: (selected) => setState(() {
                        if (selected == true) {
                          _selected.add(club.id);
                        } else {
                          _selected.remove(club.id);
                        }
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context)
                        .pop(_selected.intersection(widget.academicIds)),
                child: Text(
                  widget.academicIds.isEmpty
                      ? 'Skip for now'
                      : 'Skip optional groups',
                ),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(Set<String>.of(_selected)),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
