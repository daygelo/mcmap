import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Refreshes when the vertical scrollable [child] is dragged past its top or
/// its bottom, by touch, mouse or trackpad.
class PullToRefresh extends StatefulWidget {
  const PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;

  /// Give it [AlwaysScrollableScrollPhysics] so short lists can be dragged.
  final Widget child;

  @override
  State<PullToRefresh> createState() => _PullToRefreshState();
}

class _PullToRefreshState extends State<PullToRefresh> {
  /// How far past the bottom a drag has to go.
  static const _bottomPull = 80.0;

  /// How far a wheel or web trackpad has to keep scrolling at an end.
  static const _wheelPull = 200.0;

  /// A pause this long ends a wheel gesture.
  static const _wheelPause = Duration(milliseconds: 250);

  final _topIndicator = GlobalKey<RefreshIndicatorState>();
  ScrollMetrics? _metrics;
  bool _refreshing = false;
  bool _refreshingBottom = false;
  bool _dragging = false;
  double _pulledUp = 0;

  Duration _lastWheel = Duration.zero;
  bool _wheelFromTop = false;
  bool _wheelFromBottom = false;
  double _wheel = 0;

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await widget.onRefresh();
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refreshFromBottom() async {
    if (_refreshing) return;
    setState(() => _refreshingBottom = true);
    try {
      await _refresh();
    } finally {
      if (mounted) setState(() => _refreshingBottom = false);
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    _metrics = notification.metrics;
    switch (notification) {
      case ScrollStartNotification(:final dragDetails):
        _dragging = dragDetails != null;
        _pulledUp = 0;
      // Where the list stops dead at its ends.
      case OverscrollNotification(dragDetails: _?, :final overscroll)
          when overscroll > 0:
        _pulledUp += overscroll;
      // Where it stretches past them, or is dragged back.
      case ScrollUpdateNotification(dragDetails: _?, :final metrics):
        _pulledUp = math.max(0, metrics.pixels - metrics.maxScrollExtent);
      // Let go.
      case ScrollUpdateNotification() || ScrollEndNotification() when _dragging:
        _dragging = false;
        if (_pulledUp >= _bottomPull) _refreshFromBottom();
        _pulledUp = 0;
      default:
        break;
    }
    return false;
  }

  /// Web trackpads arrive as wheel events, which never go past the end of a
  /// list. Scrolling on from an end counts instead, but not the momentum of a
  /// scroll that only just got there.
  void _onPointerSignal(PointerSignalEvent event) {
    final metrics = _metrics;
    if (event is! PointerScrollEvent || metrics == null) return;
    if (event.timeStamp - _lastWheel > _wheelPause) {
      _wheelFromTop = metrics.extentBefore <= 0;
      _wheelFromBottom = metrics.extentAfter <= 0;
      _wheel = 0;
    }
    _lastWheel = event.timeStamp;
    _wheel += event.scrollDelta.dy;
    if (_wheelFromTop && _wheel <= -_wheelPull) {
      _wheelFromTop = _wheelFromBottom = false;
      if (!_refreshing) _topIndicator.currentState?.show();
    } else if (_wheelFromBottom && _wheel >= _wheelPull) {
      _wheelFromTop = _wheelFromBottom = false;
      _refreshFromBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    return Stack(
      children: [
        RefreshIndicator(
          key: _topIndicator,
          color: McMapColors.red,
          backgroundColor: McMapColors.white,
          triggerMode: RefreshIndicatorTriggerMode.anywhere,
          semanticsLabel: 'Refreshing',
          onRefresh: _refresh,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (notification) {
              if (notification.depth == 0) _metrics = notification.metrics;
              return false;
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: Listener(
                onPointerSignal: _onPointerSignal,
                child: ScrollConfiguration(
                  behavior: behavior.copyWith(
                    dragDevices: {
                      ...behavior.dragDevices,
                      PointerDeviceKind.mouse,
                    },
                    // Lists on a Mac barely stretch by default, so a pull
                    // would have to be longer than most windows.
                    physics: Theme.of(context).platform == TargetPlatform.macOS
                        ? const BouncingScrollPhysics()
                        : null,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
        if (_refreshingBottom)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Center(
              child: RefreshProgressIndicator(
                color: McMapColors.red,
                backgroundColor: McMapColors.white,
                semanticsLabel: 'Refreshing',
              ),
            ),
          ),
      ],
    );
  }
}
