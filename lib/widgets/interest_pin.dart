import 'package:material_ui/material_ui.dart';

import '../data/interests.dart';
import '../theme/app_theme.dart';
import 'mcmap_logo.dart';

/// An interest as a McMap pin: the logo's pin in the interest's colour, with
/// its symbol where the M would be.
class InterestPin extends StatelessWidget {
  const InterestPin(this.interest, {super.key, this.height = 64});

  final Interest interest;
  final double height;

  /// The logo's grid, cropped to the pin and its shadow.
  static const _left = 15.0;
  static const _top = 10.0;
  static const _width = 34.0;
  static const _height = 50.0;

  @override
  Widget build(BuildContext context) {
    final scale = height / _height;
    return SizedBox(
      width: _width * scale,
      height: height,
      child: CustomPaint(
        painter: _PinPainter(interest.accent.deep),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            // Centred on the head of the pin.
            padding: EdgeInsets.only(top: (27 - _top - 9) * scale),
            child: Icon(
              interest.icon,
              size: 18 * scale,
              color: McMapColors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  const _PinPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pin = mcMapPin();
    canvas
      ..save()
      ..scale(size.height / InterestPin._height)
      ..translate(-InterestPin._left, -InterestPin._top)
      ..drawOval(
        Rect.fromCenter(center: const Offset(32, 56), width: 14, height: 4.4),
        Paint()..color = McMapColors.ink.withValues(alpha: 0.16),
      )
      ..drawPath(
        pin,
        Paint()
          ..color = McMapColors.white
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 3,
      )
      ..drawPath(pin, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_PinPainter oldDelegate) => oldDelegate.color != color;
}

/// A patch of map behind a pin: the accent's tint with pale streets.
class MapPatchPainter extends CustomPainter {
  const MapPatchPainter(this.accent);

  final McMapAccent accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = accent.tint);
    final (w, h) = (size.width, size.height);
    final street = Paint()
      ..color = McMapColors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(
        Path()
          ..moveTo(-4, h * 0.34)
          ..quadraticBezierTo(w * 0.45, h * 0.2, w + 4, h * 0.4)
          ..moveTo(w * 0.2, -4)
          ..lineTo(w * 0.34, h + 4),
        street..strokeWidth = w * 0.05,
      )
      ..drawPath(
        Path()
          ..moveTo(w * 0.78, -4)
          ..lineTo(w * 0.7, h + 4)
          ..moveTo(-4, h * 0.72)
          ..lineTo(w + 4, h * 0.62),
        street..strokeWidth = w * 0.025,
      );
  }

  @override
  bool shouldRepaint(MapPatchPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
