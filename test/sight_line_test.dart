import 'package:flutter_test/flutter_test.dart';
import 'package:mcmap/data/campus_buildings.dart';
import 'package:mcmap/data/campus_map.dart';
import 'package:mcmap/data/sight_line.dart';

const _center = CampusCamera.center;

SightLine _line(
  double x,
  double y, {
  double pitch = 0,
  double bearing = 0,
  double zoom = 17,
  (double, double) center = _center,
}) => SightLine.through(
  x: x,
  y: y,
  width: 1000,
  height: 800,
  center: center,
  zoom: zoom,
  pitch: pitch,
  bearing: bearing,
);

/// A square of [size] metres, [east] and [north] of the middle of the map.
List<List<List<double>>> _block(double east, double north, double size) {
  List<double> at(double e, double n) => [
    _center.$1 + (east + e) / 78027,
    _center.$2 + (north + n) / 111319.5,
  ];
  final h = size / 2;
  return [
    [at(-h, -h), at(h, -h), at(h, h), at(-h, h), at(-h, -h)],
  ];
}

void main() {
  test('straight down hits the roof at camera height minus its own', () {
    final down = _line(500, 400);
    // Camera is 1.5 screen heights up: 1200 px at 0.4186 m each.
    final ground = down.distanceTo(_block(0, 0, 10), base: 0, top: 0)!;
    expect(ground, closeTo(1200 * 0.4186, 1));
    final roof = down.distanceTo(_block(0, 0, 10), base: 0, top: 40)!;
    expect(ground - roof, closeTo(40, 0.01));
    expect(down.distanceTo(_block(50, 0, 10), base: 0, top: 40), isNull);
  });

  test('screen directions follow the bearing', () {
    // 100 px right of centre is about 42 m.
    expect(
      _line(600, 400).distanceTo(_block(42, 0, 8), base: 0, top: 1),
      isNotNull,
    );
    expect(
      _line(500, 300).distanceTo(_block(0, 42, 8), base: 0, top: 1),
      isNotNull,
    );
    // Facing east, up the screen is east.
    expect(
      _line(
        500,
        300,
        bearing: 90,
      ).distanceTo(_block(42, 0, 8), base: 0, top: 1),
      isNotNull,
    );
  });

  test('tilted, a tall block hides the one behind it', () {
    final line = _line(500, 400, pitch: 60);
    final near = line.distanceTo(_block(0, -60, 20), base: 0, top: 60)!;
    final far = line.distanceTo(_block(0, 10, 20), base: 0, top: 60)!;
    expect(near, lessThan(far - 20));
    // A low one doesn't reach the line of sight.
    expect(line.distanceTo(_block(0, -60, 20), base: 0, top: 5), isNull);
    // Nor does one floating above it.
    expect(line.distanceTo(_block(0, -60, 20), base: 80, top: 90), isNull);
  });

  test('courtyards are open', () {
    final courtyard = [..._block(0, 0, 40), ..._block(0, 0, 20)];
    final down = _line(500, 400);
    expect(down.distanceTo(courtyard, base: 0, top: 20), isNull);
    expect(_line(535, 400).distanceTo(courtyard, base: 0, top: 20), isNotNull);
    expect(isInside(_center.$1, _center.$2, courtyard), isFalse);
  });

  test('every building is found from straight above and from an angle', () {
    for (final building in campusBuildings) {
      final center = building.shape.center;
      for (final pitch in [0.0, 25.0]) {
        final distance = building.shape.distanceOn(
          _line(500, 400, center: center, zoom: 18, pitch: pitch),
        );
        expect(distance, isNotNull, reason: '${building.id} at $pitch');
      }
      // Pointing at the sky-side corner of the screen finds nothing here.
      expect(
        building.shape.distanceOn(_line(5, 795, center: center, zoom: 19)),
        isNull,
        reason: building.id,
      );
    }
  });

  test('replaced basemap buildings are recognized by id or position', () {
    expect(isReplacedBasemapBuilding(30176564, const []), isTrue);
    expect(isReplacedBasemapBuilding('30176564', const []), isTrue);
    expect(isReplacedBasemapBuilding(1, const []), isFalse);
    final leacock = campusBuildingsById['leacock']!.shape;
    final tower = leacock.parts.last['rings'] as List;
    expect(isReplacedBasemapBuilding(1, tower), isTrue);
    expect(isReplacedBasemapBuilding(1, _block(0, -400, 20)), isFalse);
  });
}
