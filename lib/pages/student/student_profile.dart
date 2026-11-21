import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/academics.dart';
import '../../theme/app_theme.dart';
import '../../widgets/froshie_tag.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/profile_photo_picker.dart';
import '../../widgets/profile_stats.dart';

/// Temporary student UI data until the shared profile service is available.
class StudentProfile {
  const StudentProfile({
    this.name = 'McMap Student',
    this.faculty = 'Faculty of Engineering',
    this.major = 'Software Engineering',
    this.year = 'U0',
    this.firstYearAtMcGill = false,
    this.bio = '',
    this.interests = const {},
    this.avatarUrl,
    this.avatarBytes,
    this.handle,
  });

  /// "@handle" under the name. Null for the offline demo profile.
  final String? handle;

  final String name;
  final String faculty;
  final String major;
  final String year;
  final bool firstYearAtMcGill;
  final String bio;
  final Set<String> interests;
  final String? avatarUrl;

  /// A photo picked on this device. Wins over [avatarUrl]. In memory only
  /// until avatar storage exists.
  final Uint8List? avatarBytes;

  bool get isFroshie =>
      isFroshieStanding(year, firstYearAtMcGill: firstYearAtMcGill);

  bool get hasPhoto => avatarBytes != null || avatarUrl != null;

  /// Same profile with a new photo (null removes it).
  StudentProfile withPhoto(Uint8List? bytes) => StudentProfile(
    name: name,
    faculty: faculty,
    major: major,
    year: year,
    firstYearAtMcGill: firstYearAtMcGill,
    bio: bio,
    interests: interests,
    avatarUrl: bytes == null ? null : avatarUrl,
    avatarBytes: bytes,
    handle: handle,
  );

  /// Same profile pointing at an uploaded photo.
  StudentProfile withPhotoUrl(String url, {Uint8List? preview}) =>
      StudentProfile(
        name: name,
        faculty: faculty,
        major: major,
        year: year,
        firstYearAtMcGill: firstYearAtMcGill,
        bio: bio,
        interests: interests,
        avatarUrl: url,
        avatarBytes: preview,
        handle: handle,
      );
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.radius = 32});

  final StudentProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? image = switch (profile) {
      StudentProfile(avatarBytes: final bytes?) => MemoryImage(bytes),
      StudentProfile(avatarUrl: final url?) => NetworkImage(url),
      _ => null,
    };
    // No photo yet → initials on the McGill tint.
    return InitialsAvatar(
      name: profile.name,
      diameter: radius * 2,
      image: image,
    );
  }
}

/// Your avatar with the small "+" badge. Tapping anywhere on it opens the
/// photo sheet.
class EditableProfileAvatar extends StatelessWidget {
  const EditableProfileAvatar({
    super.key,
    required this.profile,
    required this.onPhotoChanged,
  });

  final StudentProfile profile;
  final ValueChanged<Uint8List?> onPhotoChanged;

  Future<void> _change(BuildContext context) async {
    final choice = await chooseProfilePhoto(
      context,
      hasPhoto: profile.hasPhoto,
    );
    switch (choice) {
      case PhotoPicked(:final bytes):
        onPhotoChanged(bytes);
      case PhotoRemoved():
        onPhotoChanged(null);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: profile.hasPhoto ? 'Change profile photo' : 'Add profile photo',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _change(context),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            RingedAvatar(child: ProfileAvatar(profile: profile, radius: 37)),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: McMapColors.redStrong,
                  shape: BoxShape.circle,
                  border: Border.all(color: McMapColors.white, width: 2),
                ),
                child: Icon(
                  profile.hasPhoto ? Icons.edit_rounded : Icons.add_rounded,
                  size: 15,
                  color: McMapColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Your own profile, Instagram-style:
///   [ avatar ]   142        3        2
///               McGillians Events  Clubs
///   Name · major · year · faculty · Froshie · bio · interests
///   [ Edit Profile ] [ Share Profile ]
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
    this.onEdit,
    this.onPhotoChanged,
    this.mcgilliansCount,
    this.onMcGilliansTap,
    this.eventsCount,
    this.clubsCount,
  });

  final StudentProfile profile;
  final VoidCallback? onEdit;

  /// Enables the "+" photo badge. Null shows a plain avatar.
  final ValueChanged<Uint8List?>? onPhotoChanged;

  /// Stats; each is hidden when null.
  final int? mcgilliansCount;
  final VoidCallback? onMcGilliansTap;
  final int? eventsCount;
  final int? clubsCount;

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(
        text:
            '${profile.name} on McMap · ${profile.major} · ${profile.year}, '
            '${profile.faculty}',
      ),
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Profile copied. Paste it anywhere.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final onPhotoChanged = this.onPhotoChanged;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileTopRow(
              avatar: onPhotoChanged == null
                  ? RingedAvatar(
                      child: ProfileAvatar(profile: profile, radius: 37),
                    )
                  : EditableProfileAvatar(
                      profile: profile,
                      onPhotoChanged: onPhotoChanged,
                    ),
              stats: [
                if (mcgilliansCount case final count?)
                  ProfileStat(
                    value: count,
                    label: 'McGillians',
                    onTap: onMcGilliansTap,
                  ),
                if (eventsCount case final count?)
                  ProfileStat(value: count, label: 'Events'),
                if (clubsCount case final count?)
                  ProfileStat(value: count, label: 'Clubs'),
              ],
            ),
            const SizedBox(height: 12),
            Text(profile.name, style: text.titleLarge),
            Text(
              profile.handle == null ? 'Sample profile' : '@${profile.handle}',
              style: text.bodySmall,
            ),
            const SizedBox(height: 4),
            Text('${profile.major} · ${profile.year}'),
            Text(profile.faculty, style: text.bodySmall),
            if (profile.isFroshie) ...[
              const SizedBox(height: 8),
              const FroshieTag(),
            ],
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
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: McMapButtonStyles.neutral,
                      onPressed: onEdit,
                      child: const Text('Edit Profile'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: McMapButtonStyles.neutral,
                      onPressed: () => _share(context),
                      child: const Text('Share Profile'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
