enum AppNotificationType {
  newFollowedEvent('new_followed_event'),
  eventDeadlineSoon('event_deadline_soon');

  const AppNotificationType(this.dbValue);

  final String dbValue;

  static AppNotificationType? fromDb(Object? value) =>
      values.where((type) => type.dbValue == value).firstOrNull;
}

/// A row in `notifications`, with its group's name and picture.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.eventId,
    required this.groupName,
    required this.title,
    required this.body,
    required this.createdAt,
    this.groupAvatarUrl,
    this.friendRsvpCount = 0,
    this.isRead = false,
  });

  final String id;
  final AppNotificationType type;
  final String eventId;
  final String groupName;
  final String? groupAvatarUrl;
  final String title;
  final String body;

  /// McGillians going when a deadline reminder was written.
  final int friendRsvpCount;
  final bool isRead;
  final DateTime createdAt;

  AppNotification asRead() => isRead
      ? this
      : AppNotification(
          id: id,
          type: type,
          eventId: eventId,
          groupName: groupName,
          groupAvatarUrl: groupAvatarUrl,
          title: title,
          body: body,
          friendRsvpCount: friendRsvpCount,
          isRead: true,
          createdAt: createdAt,
        );
}
