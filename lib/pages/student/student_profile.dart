import 'package:material_ui/material_ui.dart';

/// Temporary student UI data until the shared profile service is available.
class StudentProfile {
  const StudentProfile({
    this.faculty = 'Faculty of Engineering',
    this.major = 'Software Engineering',
    this.year = 'U0',
    this.bio = '',
    this.interests = const {},
    this.avatarUrl,
  });

  final String faculty;
  final String major;
  final String year;
  final String bio;
  final Set<String> interests;
  final String? avatarUrl;
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile});

  final StudentProfile profile;

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
  const ProfileHeader({super.key, required this.profile, required this.onEdit});

  final StudentProfile profile;
  final VoidCallback onEdit;

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
            const Text('Sample profile'),
            const SizedBox(height: 8),
            Text('${profile.major} · ${profile.year}'),
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
            const SizedBox(height: 12),
            FilledButton(onPressed: onEdit, child: const Text('Edit Profile')),
          ],
        ),
      ),
    );
  }
}
