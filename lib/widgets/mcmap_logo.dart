import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// The McMap mark: a tri-fold campus map (white panels, soft street grid,
/// McGill-red corner fold) with a McGill-red pin whose head carries a white
/// "M". The M's centre valley points straight down the pin to its tip, so
/// the letter and the location marker read as one shape.
///
/// Drawn on a 64×64 grid; scales crisply to any size. The same geometry is
/// in assets/branding/mcmap_logo.svg (web favicon) and is rendered into the
/// app icons by tool/render_app_icons.dart — keep them in sync.
class McMapLogo extends StatelessWidget {
  const McMapLogo({super.key, this.size = 48, this.semanticLabel = 'McMap'});

  final double size;

  /// Null hides it from screen readers (e.g. next to the "McMap" word).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final logo = CustomPaint(
      size: Size.square(size),
      painter: const McMapLogoPainter(),
    );
    final label = semanticLabel;
    return label == null
        ? ExcludeSemantics(child: logo)
        : Semantics(label: label, image: true, child: logo);
  }
}

/// Logo + "McMap" in the serif brand face, for app bars.
class McMapWordmark extends StatelessWidget {
  const McMapWordmark({super.key, this.color, this.logoSize = 32});

  final Color? color;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'McMap',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          McMapLogo(size: logoSize, semanticLabel: null),
          const SizedBox(width: 10),
          Text(
            'McMap',
            style: TextStyle(
              fontFamily: McMapFonts.serif,
              fontFamilyFallback: McMapFonts.serifFallback,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class McMapLogoPainter extends CustomPainter {
  const McMapLogoPainter();

  // Shared with the SVG.
  static const _streets = Color(0xFFE4E5E9);
  static const _panelShade = McMapColors.surfaceMuted; // #F4F4F5
  static const _mapEdge = McMapColors.borderStrong; // #D9DCE1

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Map: three panels, the middle one shaded like a fold.
    final map = Path()
      ..moveTo(6, 14)
      ..lineTo(23, 8)
      ..lineTo(41, 14)
      ..lineTo(58, 8)
      ..lineTo(58, 50)
      ..lineTo(41, 56)
      ..lineTo(23, 50)
      ..lineTo(6, 56)
      ..close();
    canvas.drawPath(map, Paint()..color = McMapColors.white);
    canvas.drawPath(
      Path()
        ..moveTo(23, 8)
        ..lineTo(41, 14)
        ..lineTo(41, 56)
        ..lineTo(23, 50)
        ..close(),
      Paint()..color = _panelShade,
    );

    // Streets / campus grid.
    canvas.drawPath(
      Path()
        ..moveTo(6, 31)
        ..lineTo(23, 26)
        ..lineTo(41, 32)
        ..lineTo(58, 27)
        ..moveTo(6, 45)
        ..lineTo(23, 40)
        ..lineTo(41, 46)
        ..lineTo(58, 41)
        ..moveTo(14, 11)
        ..lineTo(14, 53)
        ..moveTo(50, 11)
        ..lineTo(50, 53),
      Paint.from(stroke)
        ..color = _streets
        ..strokeWidth = 1.4,
    );

    canvas.drawPath(
      map,
      Paint.from(stroke)
        ..color = _mapEdge
        ..strokeWidth = 1.5,
    );

    // McGill-red corner fold, top right.
    canvas.drawPath(
      Path()
        ..moveTo(58, 8)
        ..lineTo(58, 17)
        ..lineTo(50.5, 10.6)
        ..close(),
      Paint()..color = McMapColors.red,
    );

    // Pin shadow on the map.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(32, 56), width: 14, height: 4.4),
      Paint()..color = McMapColors.ink.withValues(alpha: 0.18),
    );

    // Pin: round head, tapering to a point at (32, 55).
    final pin = Path()
      ..moveTo(32, 55)
      ..cubicTo(26, 46, 18, 39, 18, 27)
      ..arcToPoint(
        const Offset(46, 27),
        radius: const Radius.circular(14),
        largeArc: true,
      )
      ..cubicTo(46, 39, 38, 46, 32, 55)
      ..close();
    canvas.drawPath(
      pin,
      Paint.from(stroke)
        ..color = McMapColors.white
        ..strokeWidth = 2.5,
    );
    canvas.drawPath(pin, Paint()..color = McMapColors.red);

    // The "M": its middle valley sits on the pin's axis.
    canvas.drawPath(
      Path()
        ..moveTo(25, 33)
        ..lineTo(25, 21)
        ..lineTo(32, 29)
        ..lineTo(39, 21)
        ..lineTo(39, 33),
      Paint.from(stroke)
        ..color = McMapColors.white
        ..strokeWidth = 3.6,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(McMapLogoPainter oldDelegate) => false;
}
