import 'package:material_ui/material_ui.dart';

import '../data/clubs.dart';

/// Returns a draft selection on save, or null when the student goes back.
class ClubPickerPage extends StatefulWidget {
  const ClubPickerPage({super.key});

  @override
  State<ClubPickerPage> createState() => _ClubPickerPageState();
}

class _ClubPickerPageState extends State<ClubPickerPage> {
  final _selected = <String>{};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final matches = clubCatalog.where((club) => club.matches(_query)).toList();
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
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final club = matches[index];
                    return CheckboxListTile(
                      key: ValueKey(club.id),
                      title: Text(club.name),
                      subtitle: Text('${club.type.label} · ${club.category}'),
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
                onPressed: () => Navigator.of(context).pop(const <String>{}),
                child: const Text('Skip for now'),
              ),
              FilledButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () =>
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
