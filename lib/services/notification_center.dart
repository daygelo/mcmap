import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/mcmap_backend.dart';
import '../models/app_notification.dart';

/// The signed-in student's notifications, kept current by the server. Without
/// a backend (offline demo) it only holds what's passed in or [add]ed.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter.remote(McMapBackend this._backend);

  NotificationCenter.local([Iterable<AppNotification> items = const []])
    : _backend = null,
      _items = _newestFirst(items);

  final McMapBackend? _backend;

  /// Called when marking something as read couldn't be saved.
  VoidCallback? onSaveFailed;

  List<AppNotification> _items = const [];

  /// Marked read here. Kept so a list requested just before the save finished
  /// can't bring them back as unread.
  final _readHere = <String>{};
  StreamSubscription<void>? _changes;
  Timer? _reload;
  int _loads = 0;
  bool _loaded = false;
  bool _failed = false;
  bool _disposed = false;

  Iterable<AppNotification> get unread => _items.where((item) => !item.isRead);
  Iterable<AppNotification> get read => _items.where((item) => item.isRead);
  int get unreadCount => unread.length;
  bool get isEmpty => _items.isEmpty;

  /// Nothing has arrived from the server yet.
  bool get loading => _backend != null && !_loaded && !_failed;

  /// The latest load failed; whatever loaded before it is still listed.
  bool get failed => _failed;

  /// Loads the list and follows live changes.
  Future<void> start() async {
    final backend = _backend;
    if (backend == null) return;
    _changes ??= backend.watchNotifications().listen(
      // One student can get several at once ("mark all" changes every row).
      (_) {
        _reload?.cancel();
        _reload = Timer(const Duration(milliseconds: 300), _load);
      },
      onError: (Object _) {},
    );
    await refresh();
  }

  /// Has the server write any reminders that are due, then loads the list.
  Future<void> refresh() async {
    final backend = _backend;
    if (backend == null) return;
    try {
      await backend.refreshNotifications();
    } catch (_) {
      // The scheduled job writes them too; the list below says if we're offline.
    }
    await _load();
  }

  Future<void> _load() async {
    if (_disposed) return;
    final load = ++_loads;
    try {
      final items = await _backend!.fetchNotifications();
      if (_disposed || load != _loads) return;
      _items = _newestFirst([
        for (final item in items)
          _readHere.contains(item.id) ? item.asRead() : item,
      ]);
      _loaded = true;
      _failed = false;
    } catch (_) {
      if (_disposed || load != _loads) return;
      _failed = true;
    }
    notifyListeners();
  }

  void markRead(AppNotification item) => _markRead({item.id}, id: item.id);

  void markAllRead() => _markRead({for (final item in unread) item.id});

  void _markRead(Set<String> ids, {String? id}) {
    final changed = {
      for (final item in unread)
        if (ids.contains(item.id)) item.id,
    };
    if (changed.isEmpty) return;
    final before = {for (final item in _items) item.id: item};
    _readHere.addAll(changed);
    _items = [
      for (final item in _items)
        changed.contains(item.id) ? item.asRead() : item,
    ];
    notifyListeners();
    _backend?.markNotificationsRead(id: id).catchError((Object _) {
      if (_disposed) return;
      _readHere.removeAll(changed);
      _items = [
        for (final item in _items)
          changed.contains(item.id) ? before[item.id] ?? item : item,
      ];
      notifyListeners();
      onSaveFailed?.call();
    });
  }

  /// Demo only: shows a notification made on this device.
  void add(AppNotification item) {
    if (_items.any((existing) => existing.id == item.id)) return;
    _items = _newestFirst([item, ..._items]);
    notifyListeners();
  }

  static List<AppNotification> _newestFirst(Iterable<AppNotification> items) =>
      [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  void dispose() {
    _disposed = true;
    _reload?.cancel();
    unawaited(_changes?.cancel());
    super.dispose();
  }
}
