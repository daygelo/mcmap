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

  /// McGillians whose attendance was visible when the inbox was loaded.
  final int friendRsvpCount;
  final bool isRead;
  final DateTime createdAt;

  AppNotification asRead() => withReadState(true);

  AppNotification withReadState(bool read) =>
      isRead == read ? this : _copy(isRead: read);

  AppNotification withoutAttendance() =>
      type == AppNotificationType.eventDeadlineSoon && friendRsvpCount > 0
      ? _copy(
          body: 'An event’s RSVP deadline is coming up.',
          friendRsvpCount: 0,
        )
      : this;

  AppNotification _copy({bool? isRead, String? body, int? friendRsvpCount}) =>
      AppNotification(
        id: id,
        type: type,
        eventId: eventId,
        groupName: groupName,
        groupAvatarUrl: groupAvatarUrl,
        title: title,
        body: body ?? this.body,
        friendRsvpCount: friendRsvpCount ?? this.friendRsvpCount,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}
