import 'package:material_ui/material_ui.dart';

import '../data/campus_groups.dart';
import '../theme/app_theme.dart';
import '../widgets/group_type_badge.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/auto_rsvp_switch.dart';
import 'student/club_discovery.dart';

/// Placeholder Faculty / Club page (route `/organization/:id`), opened by
/// tapping a club avatar on an event. Catalog clubs open the full
/// ClubDetailPage instead; this covers organizers that aren't in the
/// catalog yet (faculties, committees, ...).
///
/// TODO(organizations): replace the placeholder body with the real
/// faculty/club data (about, links, upcoming events).
class OrganizationPage extends StatelessWidget {
  const OrganizationPage({
    super.key,
    required this.id,
    required this.name,
    this.group,
    this.following = false,
    this.autoRsvp = false,
    this.onFollow,
    this.onAutoRsvp,
  });

  /// URL-safe id, e.g. `ssmu-frosh-committee`.
  final String id;
  final String name;

  /// Type, handle and description, when known.
  final CampusGroup? group;
  final bool following;
  final bool autoRsvp;
  final VoidCallback? onFollow;
  final ValueChanged<bool>? onAutoRsvp;

  static String routeFor(String id) => '/organization/$id';

  /// Route fallback for a display-only organizer, never a follow ID.
  static String idFor(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Faculty & Club')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    InitialsAvatar(
                      name: name,
                      diameter: 72,
                      image: switch (group?.avatarUrl) {
                        final url? => NetworkImage(url),
                        null => null,
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: text.headlineSmall),
                          if (group?.handle case final handle?)
                            Text('@$handle', style: text.bodyMedium),
                          if (group?.type case final type?) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                GroupTypeBadge(type),
                                if (group?.facultyAffiliation
                                    case final faculty?)
                                  Text(faculty, style: text.bodySmall),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (group?.description case final description?) ...[
                  const SizedBox(height: 16),
                  Text(description, style: text.bodyLarge),
                ],
                if (onFollow != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FollowClubButton(
                      clubName: name,
                      following: following,
                      onPressed: onFollow,
                    ),
                  ),
                  if (following)
                    AutoRsvpSwitch(value: autoRsvp, onChanged: onAutoRsvp),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 36,
                  ),
                  decoration: BoxDecoration(
                    color: McMapColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: McMapColors.borderStrong),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.account_balance_outlined,
                        size: 36,
                        color: McMapColors.slate,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Coming soon — Faculty & Club details will be '
                        'populated here',
                        textAlign: TextAlign.center,
                        style: text.titleMedium,
                      ),
                    ],
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
