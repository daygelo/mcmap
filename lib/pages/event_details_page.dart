import 'package:material_ui/material_ui.dart';

import '../models/club_event.dart';
import '../models/friend_rsvps.dart';
import '../theme/app_theme.dart';
import '../widgets/event_bits.dart';
import '../widgets/friend_rsvp_pill.dart';
import '../widgets/froshie_tag.dart';
import '../widgets/initials_avatar.dart';

/// Full event page (route `/events/:id`): opened by tapping an event card
/// anywhere except the club avatar or the RSVP button.
class EventDetailsPage extends StatelessWidget {
  const EventDetailsPage({
    super.key,
    required this.event,
    required this.isGoing,
    required this.canRsvp,
    required this.onRsvp,
    this.onOpenClub,
    this.recommended = false,
    this.friendRsvps = FriendRsvps.none,
    this.onFriendTap,
    this.attendees,
  });

  final ClubEvent event;
  final bool isGoing;
  final bool canRsvp;
  final VoidCallback onRsvp;
  final VoidCallback? onOpenClub;

  /// Frosh event shown to a Froshie.
  final bool recommended;

  /// Your McGillians going.
  final FriendRsvps friendRsvps;
  final ValueChanged<String>? onFriendTap;
  final Future<List<RsvpFriend>>? attendees;

  static String routeFor(String id) => '/events/$id';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final description = event.description?.trim();
    final schedule = formatEventSchedule(context, event);
    final deadline = formatRsvpDeadline(context, event, DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Event details')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                // Header: club, then the event itself.
                Row(
                  children: [
                    InitialsAvatar(
                      name: event.club,
                      image: switch (event.clubAvatarUrl) {
                        final url? => NetworkImage(url),
                        null => null,
                      },
                      onTap: onOpenClub,
                      semanticLabel: 'Open ${event.club} page',
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        event.club,
                        style: text.titleSmall?.copyWith(
                          color: McMapColors.slate,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                  const SizedBox(height: 10),
                ],
                Text(event.title, style: text.headlineMedium),
                const SizedBox(height: 12),
                if (schedule.isNotEmpty)
                  _InfoRow(icon: Icons.schedule_rounded, label: schedule),
                if (event.location.isNotEmpty)
                  _InfoRow(icon: Icons.place_outlined, label: event.location),
                if (deadline != null)
                  _InfoRow(icon: Icons.timer_outlined, label: deadline),
                if (event.cancelled)
                  Text(
                    'This event was cancelled.',
                    style: text.bodyMedium?.copyWith(
                      color: McMapColors.burgundy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (friendRsvps.count > 0) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FriendRsvpPill(
                      friendRsvps,
                      onFriendTap: onFriendTap,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (isGoing)
                  OutlinedButton(
                    onPressed: onRsvp,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Cancel RSVP'),
                  )
                else if (canRsvp)
                  FilledButton(
                    onPressed: onRsvp,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('RSVP'),
                  ),
                if (attendees case final attendance?)
                  FutureBuilder<List<RsvpFriend>>(
                    future: attendance,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const SizedBox.shrink();
                      }
                      final people = snapshot.data
                          ?.where((person) => person.name.isNotEmpty)
                          .toList();
                      if (people == null || people.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Visible attendees', style: text.titleLarge),
                            for (final person in people)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: InitialsAvatar(
                                  name: person.name,
                                  image: switch (person.avatarUrl) {
                                    final url? => NetworkImage(url),
                                    null => null,
                                  },
                                ),
                                title: Text(person.name),
                                onTap:
                                    person.profileId == null ||
                                        onFriendTap == null
                                    ? null
                                    : () => onFriendTap!(person.profileId!),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 28),
                Text('About this event', style: text.titleLarge),
                const SizedBox(height: 8),
                Text(
                  description == null || description.isEmpty
                      ? "The organizer hasn't added a description yet."
                      : description,
                  style: text.bodyLarge?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 28),
                Text('Location', style: text.titleLarge),
                const SizedBox(height: 8),
                if (event.location.isNotEmpty)
                  _InfoRow(icon: Icons.place_outlined, label: event.location),
                const SizedBox(height: 8),
                const _MapPlaceholder(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: McMapColors.slate),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

/// Slot for the interactive map. TODO(map): swap for the real map widget,
/// centred on this event's venue with a McGill-red pin.
class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Container(
        decoration: BoxDecoration(
          color: McMapColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: McMapColors.borderStrong),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 40, color: McMapColors.red),
            const SizedBox(height: 8),
            Text(
              'Interactive Map View — Ready for Map Integration',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: McMapColors.slate),
            ),
          ],
        ),
      ),
    );
  }
}
