import 'package:material_ui/material_ui.dart';

import '../models/app_notification.dart';
import '../services/notification_center.dart';
import '../theme/app_theme.dart';
import 'initials_avatar.dart';

/// Side panel behind the bell: unread notifications, then read ones.
class NotificationsDrawer extends StatelessWidget {
  const NotificationsDrawer({
    super.key,
    required this.center,
    required this.onOpen,
  });

  final NotificationCenter center;

  /// Opens the notification's event.
  final ValueChanged<AppNotification> onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: width < 440 ? width * 0.9 : 400,
      backgroundColor: McMapColors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
      ),
      semanticLabel: 'Notifications',
      child: SafeArea(
        child: ListenableBuilder(
          listenable: center,
          builder: (context, _) {
            final now = DateTime.now();
            final unread = center.unread.toList();
            final read = center.read.toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Notifications', style: text.headlineSmall),
                      ),
                      IconButton(
                        tooltip: 'Close notifications',
                        onPressed: () => Scaffold.of(context).closeEndDrawer(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        unread.isEmpty
                            ? "You're all caught up"
                            : '${unread.length} unread',
                        style: text.bodySmall,
                      ),
                      TextButton(
                        onPressed: unread.isEmpty ? null : center.markAllRead,
                        child: const Text('Mark all as read'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    primary: false,
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      if (center.failed) _LoadFailed(onRetry: center.refresh),
                      if (center.loading)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (center.isEmpty && !center.failed)
                        const _Empty(),
                      for (final (heading, items) in [
                        ('New', unread),
                        ('Earlier', read),
                      ])
                        if (items.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                            child: Semantics(
                              header: true,
                              child: Text(
                                heading,
                                style: text.labelLarge?.copyWith(
                                  color: McMapColors.slate,
                                ),
                              ),
                            ),
                          ),
                          for (final item in items)
                            _NotificationTile(
                              item,
                              now: now,
                              onTap: () => onOpen(item),
                            ),
                        ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile(this.item, {required this.now, required this.onTap});

  final AppNotification item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final unread = !item.isRead;
    final deadline = item.type == AppNotificationType.eventDeadlineSoon;
    return Semantics(
      container: true,
      button: true,
      label: unread ? 'Unread' : null,
      child: Material(
        color: unread ? McMapColors.redTint : McMapColors.white,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: _GroupPicture(item: item, deadline: deadline),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: text.titleSmall?.copyWith(
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.body,
                        style: text.bodyMedium?.copyWith(
                          height: 1.4,
                          color: unread ? McMapColors.ink : McMapColors.slate,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notificationAge(item.createdAt, now),
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: unread ? McMapColors.red : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
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

/// The group's picture with a small mark for the kind of notification.
class _GroupPicture extends StatelessWidget {
  const _GroupPicture({required this.item, required this.deadline});

  final AppNotification item;
  final bool deadline;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 46,
      child: Stack(
        children: [
          DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: McMapColors.borderStrong),
            ),
            child: InitialsAvatar(
              name: item.groupName,
              diameter: 42,
              image: switch (item.groupAvatarUrl) {
                final url? => NetworkImage(url),
                null => null,
              },
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: deadline ? McMapColors.red : McMapColors.ink,
                shape: BoxShape.circle,
                border: Border.all(color: McMapColors.white, width: 2),
              ),
              child: Icon(
                deadline ? Icons.schedule_rounded : Icons.event_rounded,
                size: 11,
                color: McMapColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      child: Column(
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            size: 40,
            color: McMapColors.slateLight,
          ),
          const SizedBox(height: 12),
          Text('No notifications yet', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            "New events and closing RSVPs from clubs you follow show up here.",
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: McMapColors.slate),
          ),
        ],
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: [
          const Expanded(child: Text("Couldn't load notifications.")),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

/// "Just now", "5 min ago", "3 h ago", "2 d ago", then weeks.
String notificationAge(DateTime createdAt, DateTime now) {
  final age = now.difference(createdAt);
  if (age.inMinutes < 1) return 'Just now';
  if (age.inHours < 1) return '${age.inMinutes} min ago';
  if (age.inDays < 1) return '${age.inHours} h ago';
  if (age.inDays < 7) return '${age.inDays} d ago';
  return '${age.inDays ~/ 7} wk ago';
}
