import 'package:material_ui/material_ui.dart';

import '../models/friend_rsvps.dart';
import '../theme/app_theme.dart';
import 'initials_avatar.dart';

/// Photos and names for McGillians whose attendance is visible to the viewer.
class FriendRsvpPill extends StatelessWidget {
  const FriendRsvpPill(
    this.rsvps, {
    super.key,
    this.background = McMapColors.redTint,
    this.onFriendTap,
  });

  final FriendRsvps rsvps;
  final Color background;
  final ValueChanged<String>? onFriendTap;

  static const _face = 22.0;

  @override
  Widget build(BuildContext context) {
    if (rsvps.count <= 0) return const SizedBox.shrink();
    final friends = rsvps.friends.take(rsvps.count).toList();
    final named = friends
        .where((friend) => friend.name.isNotEmpty)
        .take(2)
        .toList();
    final others = rsvps.count - named.length;
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: McMapColors.ink, letterSpacing: 0);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: McMapColors.red.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final friend in friends.take(3))
            _link(friend, _Face(friend), avatar: true),
          if (friends.isEmpty)
            const Icon(Icons.group_rounded, size: 17, color: McMapColors.red),
          const SizedBox(width: 6),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  if (named.isEmpty)
                    TextSpan(
                      text:
                          "${rsvps.count} ${rsvps.count == 1 ? 'McGillian' : 'McGillians'}",
                    ),
                  for (final (index, friend) in named.indexed) ...[
                    if (index > 0) TextSpan(text: others > 0 ? ', ' : ' and '),
                    if (onFriendTap != null && friend.profileId != null)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: _link(
                          friend,
                          Text(
                            friend.name,
                            style: style?.copyWith(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      )
                    else
                      TextSpan(text: friend.name),
                  ],
                  if (named.isNotEmpty && others > 0)
                    TextSpan(
                      text: ' and $others ${others == 1 ? 'other' : 'others'}',
                    ),
                  const TextSpan(text: " RSVP'd for this event"),
                ],
              ),
              style: style,
            ),
          ),
        ],
      ),
    );
  }

  Widget _link(RsvpFriend friend, Widget child, {bool avatar = false}) {
    final id = friend.profileId;
    if (id == null || onFriendTap == null) return child;
    final label = friend.name.isEmpty
        ? 'Open student profile'
        : 'Open ${friend.name}’s profile';
    return Semantics(
      button: true,
      label: avatar ? label : null,
      child: InkWell(onTap: () => onFriendTap!(id), child: child),
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
          initialsFor(friend.name).characters.firstOrNull ?? '?',
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
