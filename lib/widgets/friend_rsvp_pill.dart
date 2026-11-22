import 'package:material_ui/material_ui.dart';

import '../models/friend_rsvps.dart';
import '../theme/app_theme.dart';
import 'initials_avatar.dart';

/// Overlapping photos and "3 McGillians going". Nothing when nobody is.
class FriendRsvpPill extends StatelessWidget {
  const FriendRsvpPill(
    this.rsvps, {
    super.key,
    this.background = McMapColors.redTint,
  });

  final FriendRsvps rsvps;
  final Color background;

  static const _face = 22.0;
  static const _step = 15.0;

  /// "Maya Tremblay, Leo Bergeron and 2 more", for screen readers.
  String get _names {
    final names = [for (final friend in rsvps.friends) friend.name];
    final more = rsvps.count - names.length;
    if (more > 0) names.add('$more more');
    if (names.length < 2) return names.join();
    return '${names.take(names.length - 1).join(', ')} and ${names.last}';
  }

  @override
  Widget build(BuildContext context) {
    if (rsvps.count <= 0) return const SizedBox.shrink();
    final faces = rsvps.friends.take(3).toList();
    return Semantics(
      container: true,
      label: faces.isEmpty ? rsvps.label : '${rsvps.label}: $_names',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: McMapColors.red.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (faces.isEmpty)
              const SizedBox.square(
                dimension: _face,
                child: Icon(
                  Icons.group_rounded,
                  size: 16,
                  color: McMapColors.red,
                ),
              )
            else
              SizedBox(
                width: _face + _step * (faces.length - 1),
                height: _face,
                child: Stack(
                  children: [
                    // Last first, so the first person is on top.
                    for (final (index, friend)
                        in faces.indexed.toList().reversed)
                      Positioned(left: _step * index, child: _Face(friend)),
                  ],
                ),
              ),
            const SizedBox(width: 6),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${rsvps.count}',
                      style: const TextStyle(color: McMapColors.redStrong),
                    ),
                    TextSpan(
                      text: rsvps.label.substring('${rsvps.count}'.length),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: McMapColors.ink, letterSpacing: 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face(this.friend);

  final RsvpFriend friend;

  @override
  Widget build(BuildContext context) {
    final url = friend.avatarUrl;
    return Container(
      width: FriendRsvpPill._face,
      height: FriendRsvpPill._face,
      padding: const EdgeInsets.all(1.5),
      decoration: const BoxDecoration(
        color: McMapColors.white,
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        backgroundColor: McMapColors.ink,
        foregroundColor: McMapColors.white,
        foregroundImage: url == null ? null : NetworkImage(url),
        onForegroundImageError: url == null ? null : (_, _) {},
        child: Text(
          initialsFor(friend.name).characters.first,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontFamily: McMapFonts.sans,
            fontFamilyFallback: McMapFonts.sansFallback,
            fontSize: 9,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
