import 'dart:math' as math;

/// A straight line from the map's camera through a point on the screen, used
/// to tell which of two buildings is in front. Works in metres from the middle
/// of the map: east, north and up.
class SightLine {
  SightLine._(this._from, this._direction, this._origin);

  /// [x] and [y] are in logical pixels on a map of [width] by [height],
  /// centred on [center] (longitude, latitude).
  factory SightLine.through({
    required double x,
    required double y,
    required double width,
    required double height,
    required (double, double) center,
    required double zoom,
    required double pitch,
    required double bearing,
  }) {
    final turn = bearing * math.pi / 180;
    final tilt = pitch * math.pi / 180;
    final metresPerPixel =
        _metresPerPixelAtZoom0 *
        math.cos(center.$2 * math.pi / 180) /
        math.pow(2, zoom);
    // Mapbox's field of view puts the camera 1.5 screen heights away.
    final distance = 1.5 * height;
    final right = x - width / 2;
    final up = height / 2 - y;
    final view = (
      math.sin(turn) * math.sin(tilt),
      math.cos(turn) * math.sin(tilt),
      -math.cos(tilt),
    );
    final above = (
      math.sin(turn) * math.cos(tilt),
      math.cos(turn) * math.cos(tilt),
      math.sin(tilt),
    );
    final side = (math.cos(turn), -math.sin(turn), 0.0);
    double mix(double v, double s, double a) =>
        (v * distance + s * right + a * up) * metresPerPixel;
    return SightLine._(
      (
        -view.$1 * distance * metresPerPixel,
        -view.$2 * distance * metresPerPixel,
        -view.$3 * distance * metresPerPixel,
      ),
      (
        mix(view.$1, side.$1, above.$1),
        mix(view.$2, side.$2, above.$2),
        mix(view.$3, side.$3, above.$3),
      ),
      center,
    );
  }

  static const _metresPerPixelAtZoom0 = 40075016.686 / 512;
  static const _metresPerDegree = 40075016.686 / 360;

  final (double, double, double) _from;
  final (double, double, double) _direction;
  final (double, double) _origin;

  List<double> _local(List<dynamic> point) => [
    ((point[0] as num) - _origin.$1) *
        _metresPerDegree *
        math.cos(_origin.$2 * math.pi / 180),
    ((point[1] as num) - _origin.$2) * _metresPerDegree,
  ];

  /// Metres to where the line first meets an upright block with this
  /// footprint, or null if it misses. [rings] are GeoJSON polygon rings.
  double? distanceTo(
    List<dynamic> rings, {
    required double base,
    required double top,
  }) {
    final (ox, oy, oz) = _from;
    final (dx, dy, dz) = _direction;
    double? nearest;
    void consider(double t) {
      if (t > 0 && (nearest == null || t < nearest!)) nearest = t;
    }

    final local = [
      for (final ring in rings)
        [for (final point in ring as List) _local(point as List)],
    ];
    // Roof.
    if (dz != 0) {
      final t = (top - oz) / dz;
      if (t > 0 && isInside(ox + dx * t, oy + dy * t, local)) consider(t);
    }
    // Walls.
    for (final ring in local) {
      for (var i = 0; i + 1 < ring.length; i++) {
        final [ax, ay] = ring[i];
        final (ex, ey) = (ring[i + 1][0] - ax, ring[i + 1][1] - ay);
        final cross = dx * ey - dy * ex;
        if (cross.abs() < 1e-12) continue;
        final t = ((ax - ox) * ey - (ay - oy) * ex) / cross;
        final along = ((ax - ox) * dy - (ay - oy) * dx) / cross;
        final z = oz + dz * t;
        if (along >= 0 && along <= 1 && z >= base && z <= top) consider(t);
      }
    }
    final t = nearest;
    return t == null ? null : t * math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}

/// Whether a point is inside a polygon given as GeoJSON-style rings.
bool isInside(double x, double y, List<dynamic> rings) {
  var inside = false;
  for (final ring in rings.cast<List<dynamic>>()) {
    for (var i = 0; i + 1 < ring.length; i++) {
      final [num ax, num ay, ...] = ring[i] as List;
      final [num bx, num by, ...] = ring[i + 1] as List;
      if ((ay > y) != (by > y) && x < (bx - ax) * (y - ay) / (by - ay) + ax) {
        inside = !inside;
      }
    }
  }
  return inside;
}
