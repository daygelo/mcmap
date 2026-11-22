import 'dart:math' as math;

import '../models/club_event.dart';

/// Where the campus map opens and how far it can go. Coordinates are
/// (longitude, latitude), the order Mapbox uses.
abstract final class CampusCamera {
  static const center = (-73.5772, 45.5048);
  static const zoom = 16.3;
  static const pitch = 55.0;

  /// Looks up campus from Sherbrooke, along McGill's street grid.
  static const bearing = -33.0;

  static const minZoom = 15.8;
  static const maxZoom = 19.5;

  /// Always at least a little tilted, so it never becomes a flat map.
  static const minPitch = 25.0;
  static const maxPitch = 70.0;

  /// Downtown campus: Sherbrooke to Pine, Peel to Milton Parc, plus padding.
  static const southwest = (-73.5865, 45.4995);
  static const northeast = (-73.5685, 45.5115);

  /// The main campus: Sherbrooke & McTavish, Sherbrooke & University,
  /// University & Pine, Peel & Pine. It runs diagonally to north.
  static const core = [
    (-73.5776, 45.5025),
    (-73.5735, 45.5052),
    (-73.5795, 45.5093),
    (-73.5842, 45.5052),
  ];

  /// The hard limits stop the centre of the screen at the edge of a box that
  /// includes blocks of downtown. Zoomed out, this is the nearest centre on
  /// campus itself. The closer you zoom, the further out you can go.
  static (double, double) keepInView(
    (double, double) point, {
    required double zoom,
  }) {
    final boxed = (
      point.$1.clamp(southwest.$1, northeast.$1),
      point.$2.clamp(southwest.$2, northeast.$2),
    );
    if (zoom >= 18) return boxed;
    final scale = 1 + ((zoom - 16) / 2).clamp(0.0, 1.0) * 1.2;
    return _nearestInside(boxed, [
      for (final corner in core)
        (
          center.$1 + (corner.$1 - center.$1) * scale,
          center.$2 + (corner.$2 - center.$2) * scale,
        ),
    ]);
  }

  /// How close the camera gets when a building is selected.
  static const buildingZoom = 17.2;
  static const buildingPitch = 45.0;

  /// The camera centre that shows [point] moved [left] and [up] from the
  /// middle of the screen, in pixels, so a card doesn't cover it.
  static (double, double) focusOn(
    (double, double) point, {
    required double zoom,
    required double bearing,
    required double pitch,
    double left = 0,
    double up = 0,
  }) {
    final latitudeScale = math.cos(point.$2 * math.pi / 180);
    final metresPerPixel =
        78271.517 * latitudeScale / math.pow(2, zoom).toDouble();
    final across = left * metresPerPixel;
    // Tilting squashes distances away from the viewer.
    final back = up * metresPerPixel / math.cos(pitch * math.pi / 180);
    final angle = bearing * math.pi / 180;
    final east = across * math.cos(angle) - back * math.sin(angle);
    final north = -across * math.sin(angle) - back * math.cos(angle);
    return keepInView((
      point.$1 + east / (111320 * latitudeScale),
      point.$2 + north / 111132,
    ), zoom: zoom);
  }

  /// [point] if it's inside the counterclockwise convex [polygon], otherwise
  /// the closest point on its edge.
  static (double, double) _nearestInside(
    (double, double) point,
    List<(double, double)> polygon,
  ) {
    // A degree of longitude is shorter than one of latitude here.
    const stretch = 0.701;
    var inside = true;
    var nearest = point;
    var best = double.infinity;
    for (var i = 0; i < polygon.length; i++) {
      final from = polygon[i];
      final to = polygon[(i + 1) % polygon.length];
      final (dx, dy) = ((to.$1 - from.$1) * stretch, to.$2 - from.$2);
      final (px, py) = ((point.$1 - from.$1) * stretch, point.$2 - from.$2);
      if (dx * py - dy * px < -1e-12) inside = false;
      final t = ((px * dx + py * dy) / (dx * dx + dy * dy)).clamp(0.0, 1.0);
      final (ex, ey) = (px - dx * t, py - dy * t);
      if (ex * ex + ey * ey < best) {
        best = ex * ex + ey * ey;
        nearest = (
          from.$1 + (to.$1 - from.$1) * t,
          from.$2 + (to.$2 - from.$2) * t,
        );
      }
    }
    return inside ? point : nearest;
  }
}

/// One map pin: every RSVPed event at the same spot.
class CampusPin {
  CampusPin(this.longitude, this.latitude, List<ClubEvent> events)
    : events = List.unmodifiable(events);

  final double longitude;
  final double latitude;
  final List<ClubEvent> events;

  String get key => '$longitude,$latitude';

  Map<String, Object> toFeature() => {
    'type': 'Feature',
    'geometry': {
      'type': 'Point',
      'coordinates': [longitude, latitude],
    },
    'properties': {
      'key': key,
      'count': events.length > 1 ? '${events.length}' : '',
    },
  };
}

/// Pins for events that have coordinates on campus. Others can't be shown.
List<CampusPin> campusPins(Iterable<ClubEvent> events) {
  final bySpot = <(double, double), List<ClubEvent>>{};
  for (final event in events) {
    final latitude = event.latitude;
    final longitude = event.longitude;
    if (latitude == null ||
        longitude == null ||
        longitude < CampusCamera.southwest.$1 ||
        longitude > CampusCamera.northeast.$1 ||
        latitude < CampusCamera.southwest.$2 ||
        latitude > CampusCamera.northeast.$2) {
      continue;
    }
    // About 10 m: the same building entrance.
    double round(double value) => (value * 1e4).round() / 1e4;
    (bySpot[(round(longitude), round(latitude))] ??= []).add(event);
  }
  return [
    for (final MapEntry(key: (longitude, latitude), value: events)
        in bySpot.entries)
      CampusPin(longitude, latitude, events),
  ];
}

Map<String, Object> campusPinCollection(Iterable<CampusPin> pins) => {
  'type': 'FeatureCollection',
  'features': [for (final pin in pins) pin.toFeature()],
};
