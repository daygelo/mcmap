import 'package:material_ui/material_ui.dart';

import '../../data/clubs.dart';
import '../../models/student_visibility.dart';
import '../../models/user_profile.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 32,
      backgroundColor: colors.primaryContainer,
      foregroundColor: colors.onPrimaryContainer,
      foregroundImage: profile.avatarUrl == null
          ? null
          : NetworkImage(profile.avatarUrl!),
      onForegroundImageError: profile.avatarUrl == null ? null : (_, _) {},
      child: const Icon(Icons.person_outline, size: 32),
    );
  }
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.profile, this.onEdit});

  final UserProfile profile;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileAvatar(profile: profile),
            const SizedBox(height: 12),
            Text('McMap Student', style: text.titleLarge),
            Text('Sample profile', style: text.bodySmall),
            const SizedBox(height: 8),
            Text([profile.major, ?profile.year].join(' · ')),
            Text(profile.faculty),
            if (profile.year == 'U0') const Chip(label: Text('Froshie')),
            if (profile.bio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(profile.bio),
            ],
            if (profile.interests.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final interest in profile.interests)
                    Chip(label: Text(interest)),
                ],
              ),
            ],
            if (onEdit != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onEdit,
                child: const Text('Edit Profile'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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
  });

  final UserProfile profile;
  final StudentVisibility visibility;

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
              ProfileHeader(profile: profile),
              const SizedBox(height: 16),
              ProfileClubMemberships(profile: profile),
            ],
          ],
        ),
      ),
    );
  }
}
