import 'package:material_ui/material_ui.dart';

import '../../data/clubs.dart';
import '../../models/user_profile.dart';

/// Owner-only management. Public profile rendering must be authorized server-side.
class YourClubs extends StatelessWidget {
  const YourClubs({
    super.key,
    required this.memberships,
    required this.onEdit,
    required this.onRemove,
    required this.onVisibilityChanged,
    required this.onAutoRsvpChanged,
    required this.onOpenClub,
  });

  final Map<String, ClubMembership> memberships;
  final VoidCallback onEdit;
  final ValueChanged<String> onRemove;
  final void Function(String, bool) onVisibilityChanged;
  final void Function(String, bool) onAutoRsvpChanged;
  final ValueChanged<String> onOpenClub;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Manage Clubs', style: text.titleLarge),
        const SizedBox(height: 8),
        if (memberships.isEmpty)
          const Text('You have no club memberships. Add clubs you belong to.')
        else ...[
          Text(
            'Visibility is a saved preference for this session. '
            'Public profiles and live club event automation are not connected.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final entry in memberships.entries)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(clubsById[entry.key]?.name ?? entry.key),
                    subtitle: Text(
                      ['Member', ?clubsById[entry.key]?.category].join(' · '),
                    ),
                    onTap: clubsById.containsKey(entry.key)
                        ? () => onOpenClub(entry.key)
                        : null,
                  ),
                  SwitchListTile(
                    title: const Text('Show membership on profile'),
                    subtitle: Text(
                      entry.value.showOnProfile
                          ? 'Visible preference'
                          : 'Private',
                    ),
                    value: entry.value.showOnProfile,
                    onChanged: (value) => onVisibilityChanged(entry.key, value),
                  ),
                  SwitchListTile(
                    title: const Text("Auto-RSVP to this club's events"),
                    subtitle: const Text(
                      'Automatically RSVP when this club publishes a new eligible event. '
                      'You can cancel anytime. Live publications are not connected.',
                    ),
                    value: entry.value.autoRsvpEnabledAt != null,
                    onChanged: (value) => onAutoRsvpChanged(entry.key, value),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12, bottom: 8),
                      child: TextButton(
                        onPressed: () => onRemove(entry.key),
                        child: const Text('Remove club'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: onEdit,
            child: Text(memberships.isEmpty ? 'Add Clubs' : 'Edit Clubs'),
          ),
        ),
      ],
    );
  }
}
