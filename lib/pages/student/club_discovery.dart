import 'package:material_ui/material_ui.dart';

import '../../data/clubs.dart';
import '../../widgets/auto_rsvp_switch.dart';

class FollowClubButton extends StatelessWidget {
  const FollowClubButton({
    super.key,
    required this.clubName,
    required this.following,
    required this.onPressed,
    this.showUnfollow = false,
  });

  final String clubName;
  final bool following;
  final VoidCallback? onPressed;
  final bool showUnfollow;

  @override
  Widget build(BuildContext context) {
    final selected = following && !showUnfollow;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: following,
      child: OutlinedButton(
        onPressed: onPressed,
        style: selected
            ? ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(
                  colors.primaryContainer,
                ),
                foregroundColor: WidgetStatePropertyAll(
                  colors.onPrimaryContainer,
                ),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 16),
              const SizedBox(width: 4),
            ],
            Text(
              following ? (showUnfollow ? 'Unfollow' : 'Following') : 'Follow',
              semanticsLabel:
                  '${onPressed == null
                      ? 'Following'
                      : following
                      ? 'Unfollow'
                      : 'Follow'} $clubName',
            ),
          ],
        ),
      ),
    );
  }
}

class ClubDirectoryPage extends StatefulWidget {
  const ClubDirectoryPage({
    super.key,
    required this.followedIds,
    required this.onFollow,
    required this.onOpen,
    required this.organizationNames,
    required this.onOpenOrganization,
    this.initialQuery = '',
  });

  final Set<String> followedIds;
  final ValueChanged<String> onFollow;
  final ValueChanged<ClubOrganization> onOpen;
  final Map<String, String> organizationNames;
  final void Function(String id, String name) onOpenOrganization;
  final String initialQuery;

  @override
  State<ClubDirectoryPage> createState() => _ClubDirectoryPageState();
}

class _ClubDirectoryPageState extends State<ClubDirectoryPage> {
  late final _search = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clubs = searchClubCatalog(_search.text);
    final query = normalizeClubSearch(_search.text);
    final organizations = widget.organizationNames.entries
        .where((entry) => normalizeClubSearch(entry.value).contains(query))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Browse Clubs')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SearchBar(
                controller: _search,
                hintText: 'Search club names or aliases',
                leading: const Icon(Icons.search),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (clubs.isEmpty && organizations.isEmpty)
              const Text('No organizations match your search.')
            else
              Expanded(
                child: ListView.builder(
                  itemCount: clubs.length + organizations.length,
                  itemBuilder: (context, index) {
                    if (index >= clubs.length) {
                      final entry = organizations[index - clubs.length];
                      return _OrganizationRow(
                        name: entry.value,
                        following: widget.followedIds.contains(entry.key),
                        onOpen: () =>
                            widget.onOpenOrganization(entry.key, entry.value),
                        onFollow: () => widget.onFollow(entry.key),
                      );
                    }
                    final club = clubs[index];
                    return ClubRow(
                      club: club,
                      following: widget.followedIds.contains(club.id),
                      onOpen: () => widget.onOpen(club),
                      onFollow: () => widget.onFollow(club.id),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FollowingPage extends StatelessWidget {
  const FollowingPage({
    super.key,
    required this.followedIds,
    required this.notificationIds,
    required this.onFollow,
    required this.onOpen,
    required this.onBrowse,
    required this.onInbox,
    required this.inboxCount,
    required this.organizationNames,
    required this.onOpenOrganization,
    required this.autoRsvpIds,
    required this.autoRsvpAction,
    this.temporaryPreferences = false,
  });

  final bool temporaryPreferences;
  final Set<String> followedIds;
  final Iterable<String> notificationIds;
  final ValueChanged<String> onFollow;
  final ValueChanged<ClubOrganization> onOpen;
  final VoidCallback onBrowse;
  final VoidCallback onInbox;
  final int inboxCount;
  final Map<String, String> organizationNames;
  final void Function(String id, String name) onOpenOrganization;
  final Iterable<String> autoRsvpIds;
  final ValueChanged<bool>? Function(String id) autoRsvpAction;

  Widget _autoRsvp(String id) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: AutoRsvpSwitch(
      value: autoRsvpIds.contains(id),
      onChanged: autoRsvpAction(id),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final clubs = clubCatalog.where((club) => followedIds.contains(club.id));
    final otherIds = followedIds.where((id) => !clubsById.containsKey(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (temporaryPreferences) ...[
              Text(
                'Following and event preferences are temporary for this session.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: onBrowse,
                  child: const Text('Browse Clubs'),
                ),
                OutlinedButton.icon(
                  onPressed: onInbox,
                  icon: const Icon(Icons.notifications_outlined),
                  label: Text('Event updates ($inboxCount)'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (followedIds.isEmpty)
              const Text("You're not following any clubs yet."),
            for (final club in clubs) ...[
              ClubRow(
                club: club,
                following: true,
                notifications: notificationIds.contains(club.id),
                showUnfollow: true,
                onOpen: () => onOpen(club),
                onFollow: () => onFollow(club.id),
              ),
              _autoRsvp(club.id),
            ],
            for (final id in otherIds) ...[
              _OrganizationRow(
                name: organizationNames[id] ?? id,
                following: true,
                showUnfollow: true,
                onOpen: () =>
                    onOpenOrganization(id, organizationNames[id] ?? id),
                onFollow: () => onFollow(id),
              ),
              _autoRsvp(id),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrganizationRow extends StatelessWidget {
  const _OrganizationRow({
    required this.name,
    required this.following,
    required this.onOpen,
    required this.onFollow,
    this.showUnfollow = false,
  });

  final String name;
  final bool following;
  final VoidCallback onOpen;
  final VoidCallback onFollow;
  final bool showUnfollow;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.account_balance_outlined),
    title: Text(name),
    onTap: onOpen,
    trailing: FollowClubButton(
      clubName: name,
      following: following,
      onPressed: onFollow,
      showUnfollow: showUnfollow,
    ),
  );
}

class ClubRow extends StatelessWidget {
  const ClubRow({
    super.key,
    required this.club,
    required this.following,
    required this.onOpen,
    required this.onFollow,
    this.notifications = false,
    this.showUnfollow = false,
    this.compact = false,
  });

  final ClubOrganization club;
  final bool following;
  final VoidCallback onOpen;
  final VoidCallback? onFollow;
  final bool notifications;
  final bool showUnfollow;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: compact,
      contentPadding: compact ? EdgeInsets.zero : null,
      leading: const Icon(Icons.groups_outlined),
      title: compact
          ? InkWell(onTap: onOpen, child: Text(club.name))
          : Text(club.name),
      subtitle: Text(
        notifications ? '${club.category} · Updates on' : club.category,
      ),
      onTap: compact ? null : onOpen,
      trailing: FollowClubButton(
        clubName: club.name,
        following: following,
        onPressed: onFollow,
        showUnfollow: showUnfollow,
      ),
    );
  }
}

class ClubDetailPage extends StatelessWidget {
  const ClubDetailPage({
    super.key,
    required this.club,
    required this.following,
    required this.notifications,
    required this.onFollow,
    required this.onNotifications,
    required this.autoRsvp,
    required this.onAutoRsvp,
    required this.upcoming,
    required this.past,
    required this.undated,
    required this.cancelled,
  });

  final ClubOrganization club;
  final bool following;
  final bool notifications;
  final VoidCallback onFollow;
  final ValueChanged<bool> onNotifications;
  final bool autoRsvp;
  final ValueChanged<bool>? onAutoRsvp;
  final List<Widget> upcoming;
  final List<Widget> past;
  final List<Widget> undated;
  final List<Widget> cancelled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Club details')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: CircleAvatar(child: Icon(Icons.groups_outlined)),
            ),
            const SizedBox(height: 12),
            Text(club.name, style: text.headlineMedium),
            Text('${club.type.label} · ${club.category}'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FollowClubButton(
                clubName: club.name,
                following: following,
                onPressed: onFollow,
              ),
            ),
            if (following)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notify me about new events'),
                subtitle: const Text(
                  'In-app demo updates for new publications.',
                ),
                value: notifications,
                onChanged: onNotifications,
              ),
            if (following)
              AutoRsvpSwitch(value: autoRsvp, onChanged: onAutoRsvp),
            const SizedBox(height: 20),
            if (upcoming.isEmpty) ...[
              Text('Upcoming events', style: text.titleLarge),
              const Text('No upcoming events are listed.'),
            ] else ...[
              Text('Next event', style: text.titleLarge),
              const SizedBox(height: 8),
              upcoming.first,
              if (upcoming.length > 1) ...[
                Text('More upcoming events', style: text.titleLarge),
                const SizedBox(height: 8),
                ...upcoming.skip(1),
              ],
            ],
            for (final (title, cards) in [
              ('Unconfirmed schedules', undated),
              ('Recent past events', past),
              ('Cancelled events', cancelled),
            ])
              if (cards.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(title, style: text.titleLarge),
                const SizedBox(height: 8),
                ...cards,
              ],
          ],
        ),
      ),
    );
  }
}
