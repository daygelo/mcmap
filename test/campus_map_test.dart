import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mcmap/data/campus_map.dart';
import 'package:mcmap/models/club_event.dart';
import 'package:mcmap/theme/app_theme.dart';
import 'package:mcmap/widgets/map_compass.dart';

ClubEvent _event(String id, double? latitude, double? longitude) => ClubEvent(
  id,
  id,
  'Club',
  '',
  'Place',
  latitude: latitude,
  longitude: longitude,
);

void main() {
  test('the default view is inside its own limits', () {
    expect(
      CampusCamera.zoom,
      inInclusiveRange(CampusCamera.minZoom, CampusCamera.maxZoom),
    );
    expect(
      CampusCamera.pitch,
      inInclusiveRange(CampusCamera.minPitch, CampusCamera.maxPitch),
    );
    for (final zoom in [CampusCamera.minZoom, CampusCamera.zoom, 19.0]) {
      expect(
        CampusCamera.keepInView(CampusCamera.center, zoom: zoom),
        CampusCamera.center,
      );
    }
  });

  test('the edges pull back when zoomed out but not when zoomed in', () {
    const corner = CampusCamera.southwest;
    final out = CampusCamera.keepInView(corner, zoom: CampusCamera.minZoom);
    expect(out.$1, greaterThan(corner.$1));
    expect(out.$2, greaterThan(corner.$2));
    // Settling somewhere never triggers another noticeable move.
    for (final zoom in [CampusCamera.minZoom, 16.5, 17.4]) {
      for (final start in [
        corner,
        CampusCamera.northeast,
        (corner.$1, CampusCamera.northeast.$2),
        (CampusCamera.northeast.$1, corner.$2),
      ]) {
        final once = CampusCamera.keepInView(start, zoom: zoom);
        final twice = CampusCamera.keepInView(once, zoom: zoom);
        expect(twice.$1, closeTo(once.$1, 1e-9));
        expect(twice.$2, closeTo(once.$2, 1e-9));
      }
    }
    // Downtown, inside the box but off campus: back to Sherbrooke.
    final downtown = CampusCamera.keepInView((
      -73.5700,
      45.5005,
    ), zoom: CampusCamera.minZoom);
    expect(downtown.$2, greaterThan(45.5024));
    expect(downtown.$1, lessThan(-73.5734));
    expect(CampusCamera.keepInView(corner, zoom: CampusCamera.maxZoom), corner);
    final montRoyal = CampusCamera.keepInView((-73.60, 45.52), zoom: 19);
    expect(montRoyal, (CampusCamera.southwest.$1, CampusCamera.northeast.$2));
  });

  test('pins group events at one spot and skip ones not on campus', () {
    final pins = campusPins([
      _event('a', 45.5059, -73.5761),
      _event('b', 45.50591, -73.57612),
      _event('c', 45.5076, -73.5790),
      _event('no coordinates', null, null),
      _event('toronto', 43.65, -79.38),
    ]);
    expect(pins.map((pin) => pin.events.map((e) => e.id).join(',')), [
      'a,b',
      'c',
    ]);
    expect(pins.map((pin) => pin.key).toSet(), hasLength(2));
    final features = campusPinCollection(pins)['features']! as List;
    expect(features.map((f) => f['properties']['count']), ['2', '']);
    expect(features.last['geometry']['coordinates'], [-73.5790, 45.5076]);
  });

  testWidgets('compass needle follows the map and resets the view', (
    tester,
  ) async {
    final bearing = ValueNotifier(0.0);
    addTearDown(bearing.dispose);
    var resets = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMcMapTheme(),
        home: MapCompass(bearing: bearing, onPressed: () => resets++),
      ),
    );
    bearing.value = 90;
    await tester.pump();
    final needle = tester.widget<Transform>(
      find.descendant(
        of: find.byType(MapCompass),
        matching: find.byWidgetPredicate(
          (w) => w is Transform && w.transform.storage[1].abs() > 0.5,
        ),
      ),
    );
    // Facing east, north is to the left.
    expect(math.asin(needle.transform.storage[1]), closeTo(-math.pi / 2, 1e-6));
    await tester.tap(find.byTooltip('Reset campus view'));
    expect(resets, 1);
  });
}
