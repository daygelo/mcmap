import 'package:material_ui/material_ui.dart';

import '../../data/clubs.dart';
import '../../models/student_visibility.dart';
import '../../models/user_profile.dart';
import 'student_profile.dart';

class ProfileClubMemberships extends StatelessWidget {
  const ProfileClubMemberships({super.key, required this.profile, this.onOpen});

  final UserProfile profile;
  final ValueChanged<ClubOrganization>? onOpen;

  @override
  Widget build(BuildContext context) {
    final clubs = profile.displayedClubIds.map((id) => clubsById[id]).nonNulls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Club Memberships', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (clubs.isEmpty) const Text('No memberships are shown on Profile.'),
        for (final club in clubs)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.groups_outlined),
            title: Text(club.name),
            subtitle: Text(club.category),
            onTap: onOpen == null ? null : () => onOpen!(club),
          ),
      ],
    );
  }
}

class PublicProfilePreview extends StatelessWidget {
  const PublicProfilePreview({
    super.key,
    required this.profile,
    required this.visibility,
    required this.presentation,
  });

  final UserProfile profile;
  final StudentVisibility visibility;
  final StudentProfile presentation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview Public Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Local preview. Backend access controls are pending.'),
            const SizedBox(height: 12),
            if (visibility == StudentVisibility.private)
              const Text(
                'Your profile is private. Other students cannot see this preview.',
              )
            else ...[
              Text(
                visibility == StudentVisibility.friends
                    ? 'This preview represents what permitted friends would see.'
                    : 'This preview represents what other McMap students would see.',
              ),
              const SizedBox(height: 12),
              ProfileHeader(profile: presentation),
              const SizedBox(height: 16),
              ProfileClubMemberships(profile: profile),
            ],
          ],
        ),
      ),
    );
  }
}
