import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../widgets/froshie_tag.dart';
import '../widgets/profile_stats.dart';
import 'social_graph.dart';

/// Add Friend → Following / Requested.
///
/// Not connected: solid McGill red CTA. Connected or pending: neutral outlined
/// pill, so the red stays reserved for the action you can still take.
class FriendButton extends StatelessWidget {
  const FriendButton({
    super.key,
    required this.graph,
    required this.student,
    this.expanded = false,
  });

  final SocialGraph graph;
  final McGillian student;

  /// Full-width version for profile pages.
  final bool expanded;

  Future<void> _confirmUnfollow(BuildContext context) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${student.name}?'),
        content: const Text(
          "They won't be notified. You can add them again anytime.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove ?? false) graph.remove(student);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: graph,
      builder: (context, _) {
        final size = expanded ? const Size.fromHeight(48) : const Size(0, 36);
        const pill = StadiumBorder();
        final padding = EdgeInsets.symmetric(horizontal: expanded ? 20 : 14);

        return switch (graph.statusOf(student)) {
          FriendStatus.none => FilledButton.icon(
            onPressed: () => graph.add(student),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Add Friend'),
            style: FilledButton.styleFrom(
              minimumSize: size,
              padding: padding,
              shape: pill,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          FriendStatus.requested => OutlinedButton.icon(
            onPressed: () => graph.remove(student),
            icon: const Icon(Icons.schedule_rounded, size: 18),
            label: const Text('Requested'),
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              padding: padding,
              shape: pill,
              foregroundColor: McMapColors.slate,
            ),
          ),
          FriendStatus.following => OutlinedButton.icon(
            onPressed: () => _confirmUnfollow(context),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Following'),
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              padding: padding,
              shape: pill,
            ),
          ),
        };
      },
    );
  }
}

class McGillianAvatar extends StatelessWidget {
  const McGillianAvatar({super.key, required this.student, this.radius = 22});

  final McGillian student;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: McMapColors.redTint,
      foregroundColor: McMapColors.burgundy,
      child: Text(
        student.initials,
        style: TextStyle(
          fontFamily: McMapFonts.serif,
          fontFamilyFallback: McMapFonts.serifFallback,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}

/// Search result / list row for a student.
class McGillianTile extends StatelessWidget {
  const McGillianTile({
    super.key,
    required this.graph,
    required this.student,
    this.trailing,
  });

  final SocialGraph graph;
  final McGillian student;

  /// Defaults to [FriendButton].
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => McGillianProfilePage(graph: graph, student: student),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            McGillianAvatar(student: student),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: text.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '@${student.handle} · ${student.major} · ${student.year}',
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ?? FriendButton(graph: graph, student: student),
          ],
        ),
      ),
    );
  }
}

/// Another student's profile, same Instagram layout as your own: avatar and
/// stats side by side, details underneath, then the friend button.
class McGillianProfilePage extends StatelessWidget {
  const McGillianProfilePage({
    super.key,
    required this.graph,
    required this.student,
  });

  final SocialGraph graph;
  final McGillian student;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('@${student.handle}')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListenableBuilder(
                          listenable: graph,
                          builder: (context, _) => ProfileTopRow(
                            avatar: RingedAvatar(
                              child: McGillianAvatar(
                                student: student,
                                radius: 37,
                              ),
                            ),
                            stats: [
                              ProfileStat(
                                value: graph.countFor(student),
                                label: 'McGillians',
                              ),
                              ProfileStat(
                                value: student.eventsCount,
                                label: 'Events',
                              ),
                              ProfileStat(
                                value: student.clubsCount,
                                label: 'Clubs',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(student.name, style: text.titleLarge),
                        const SizedBox(height: 4),
                        Text('${student.major} · ${student.year}'),
                        Text(student.faculty, style: text.bodySmall),
                        if (student.isFroshie) ...[
                          const SizedBox(height: 8),
                          const FroshieTag(),
                        ],
                        if (student.bio.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(student.bio),
                        ],
                        const SizedBox(height: 14),
                        FriendButton(
                          graph: graph,
                          student: student,
                          expanded: true,
                        ),
                        if (student.isPrivate) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Private profile: they need to accept your '
                            'request.',
                            style: text.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the McGillians drawer: your connections, searchable, removable.
Future<void> showMcGilliansSheet(BuildContext context, SocialGraph graph) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: McMapColors.white,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) =>
          _McGilliansSheet(graph: graph, scroll: scroll),
    ),
  );
}

class _McGilliansSheet extends StatefulWidget {
  const _McGilliansSheet({required this.graph, required this.scroll});

  final SocialGraph graph;
  final ScrollController scroll;

  @override
  State<_McGilliansSheet> createState() => _McGilliansSheetState();
}

class _McGilliansSheetState extends State<_McGilliansSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: widget.graph,
      builder: (context, _) {
        final all = widget.graph.connections;
        final shown = [
          for (final s in all)
            if (s.matches(_query)) s,
        ];
        return ListView(
          controller: widget.scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text('${all.length} McGillians', style: text.headlineMedium),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search your McGillians',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 8),
            if (all.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No McGillians yet. Search for classmates from the Home '
                  'tab and tap Add Friend.',
                ),
              )
            else if (shown.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No McGillians match your search.'),
              ),
            for (final student in shown)
              McGillianTile(
                graph: widget.graph,
                student: student,
                trailing: TextButton(
                  onPressed: () => widget.graph.remove(student),
                  child: const Text('Remove'),
                ),
              ),
          ],
        );
      },
    );
  }
}
