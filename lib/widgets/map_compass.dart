import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// White compass with a McGill-red north needle that follows the map.
/// Tapping it returns to the default campus view.
class MapCompass extends StatelessWidget {
  const MapCompass({super.key, required this.bearing, required this.onPressed});

  /// Map bearing in degrees clockwise from north.
  final ValueListenable<double> bearing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: McMapColors.white,
    elevation: 4,
    shadowColor: McMapColors.ink.withValues(alpha: 0.22),
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    child: IconButton(
      tooltip: 'Reset campus view',
      onPressed: onPressed,
      icon: ValueListenableBuilder(
        valueListenable: bearing,
        builder: (_, value, child) =>
            Transform.rotate(angle: -value * math.pi / 180, child: child),
        child: const CustomPaint(
          size: Size.square(26),
          painter: _NeedlePainter(),
        ),
      ),
    ),
  );
}

class _NeedlePainter extends CustomPainter {
  const _NeedlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.center(Offset.zero);
    final half = size.width * 0.2;
    void needle(double tip, Color color) => canvas.drawPath(
      Path()
        ..moveTo(middle.dx, tip)
        ..lineTo(middle.dx + half, middle.dy)
        ..lineTo(middle.dx - half, middle.dy)
        ..close(),
      Paint()..color = color,
    );
    needle(0, McMapColors.red);
    needle(size.height, McMapColors.ink);
    canvas.drawCircle(middle, 2.2, Paint()..color = McMapColors.white);
  }

  @override
  bool shouldRepaint(_NeedlePainter oldDelegate) => false;
}
