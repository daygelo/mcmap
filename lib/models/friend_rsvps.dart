/// One of your McGillians going to an event.
class RsvpFriend {
  const RsvpFriend({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;
}

/// Your McGillians going to an event, counting only RSVPs they let you see.
class FriendRsvps {
  const FriendRsvps({required this.count, this.friends = const []});

  static const none = FriendRsvps(count: 0);

  final int count;

  /// Up to three of them, for avatars.
  final List<RsvpFriend> friends;

  String get label => '$count ${count == 1 ? 'McGillian' : 'McGillians'} going';
}
