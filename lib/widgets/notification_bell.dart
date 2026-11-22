import 'package:material_ui/material_ui.dart';

import '../services/notification_center.dart';
import '../theme/app_theme.dart';

/// White bell button for the red app bar, with an unread count.
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    required this.center,
    required this.onPressed,
  });

  final NotificationCenter center;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: center,
      builder: (context, _) {
        final unread = center.unreadCount;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: McMapColors.white,
            foregroundColor: McMapColors.ink,
            hoverColor: McMapColors.surfaceMuted,
            fixedSize: const Size.square(36),
            minimumSize: const Size.square(36),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                unread == 0
                    ? Icons.notifications_none_rounded
                    : Icons.notifications_rounded,
                size: 21,
              ),
              if (unread > 0)
                Positioned(
                  top: -11,
                  left: 11,
                  child: Semantics(
                    label: '$unread unread',
                    excludeSemantics: true,
                    child: _Count(unread),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // McGill Red, a hair darker: the theme's red for white labels.
        color: McMapColors.redFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: McMapColors.white, width: 2),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          fontFamily: McMapFonts.sans,
          fontFamilyFallback: McMapFonts.sansFallback,
          color: McMapColors.white,
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
