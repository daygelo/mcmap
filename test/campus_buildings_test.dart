import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mcmap/data/campus_buildings.dart';
import 'package:mcmap/data/campus_map.dart';
import 'package:mcmap/data/clubs.dart';
import 'package:mcmap/theme/app_theme.dart';
import 'package:mcmap/widgets/building_card.dart';
import 'package:mcmap/widgets/map_legend.dart';

CampusBuilding _building(String id) => campusBuildingsById[id]!;

Future<void> _pump(WidgetTester tester, Widget child, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildMcMapTheme(),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
}

void main() {
  group('dataset', () {
    test('every building is complete and links to real societies', () {
      expect(campusBuildingsById, hasLength(campusBuildings.length));
      expect(
        campusBuildingShapes.keys.toSet(),
        campusBuildingsById.keys.toSet(),
      );
      for (final building in campusBuildings) {
        expect(building.spaces, isNotEmpty, reason: building.id);
        for (final space in building.spaces) {
          expect(space.source, startsWith('https://'), reason: space.name);
          if (space.clubId case final id?) {
            expect(clubsById, contains(id), reason: space.name);
            expect(space.organization, isNotNull, reason: space.name);
          }
        }
      }
      expect(
        campusBuildings.map((b) => b.featureId).toSet(),
        hasLength(campusBuildings.length),
      );
    });

    test('categories follow from the spaces inside', () {
      BuildingCategory of(String id) => _building(id).category;
      expect(of('university-centre'), BuildingCategory.ssmu);
      expect(of('mcconnell'), BuildingCategory.mixed);
      expect(of('chancellor-day'), BuildingCategory.facultyOffice);
      expect(of('trottier'), BuildingCategory.lounge);
      // A society's office alone doesn't make a faculty hub.
      expect(of('rutherford'), BuildingCategory.lounge);
      for (final building in campusBuildings) {
        expect(
          building.highlight.isFaculty,
          building.spaces.any((s) => s.type == SpaceType.facultyOffice),
          reason: building.id,
        );
      }
      expect(_building('mcconnell').spaces, hasLength(4));
    });

    test('shapes are closed, on campus and stacked upwards', () {
      for (final building in campusBuildings) {
        final shape = building.shape;
        final rings = [
          for (final polygon in [...shape.outline, ...shape.basemap])
            ...polygon as List,
          for (final part in shape.parts) ...part['rings'] as List,
        ];
        for (final ring in rings.cast<List>()) {
          expect(ring.length, greaterThanOrEqualTo(4));
          expect(ring.first, ring.last);
          for (final point in ring.cast<List>()) {
            expect(
              point[0],
              inInclusiveRange(
                CampusCamera.southwest.$1,
                CampusCamera.northeast.$1,
              ),
            );
            expect(
              point[1],
              inInclusiveRange(
                CampusCamera.southwest.$2,
                CampusCamera.northeast.$2,
              ),
            );
          }
        }
        expect(shape.parts.first['base'], 0);
        for (final part in shape.parts) {
          expect(part['top'] as num, greaterThan(part['base'] as num));
          expect(part['top'] as num, lessThan(80));
        }
      }
    });

    test('map colours are distinct and selecting darkens them', () {
      double brightness(int rgb) => Color(0xFF000000 | rgb).computeLuminance();
      expect(
        BuildingHighlight.values.map((h) => h.color).toSet(),
        hasLength(BuildingHighlight.values.length),
      );
      for (final highlight in BuildingHighlight.values) {
        expect(
          brightness(highlight.selected),
          lessThan(brightness(highlight.color)),
        );
        expect(
          brightness(highlight.hover),
          greaterThan(brightness(highlight.color)),
        );
        // Swatches stand out on white (WCAG 1.4.11).
        expect(
          1.05 / (brightness(highlight.color) + 0.05),
          greaterThanOrEqualTo(3),
          reason: highlight.label,
        );
      }
      expect(BuildingHighlight.css(BuildingHighlight.ssmu.color), '#ed1b2f');
      expect(BuildingHighlight.css(0x00A0FF), '#00a0ff');
    });

    test('map features carry the building and its state id', () {
      final features = campusBuildingCollection()['features']! as List;
      final leacock = _building('leacock');
      final parts = features.where(
        (f) => f['properties']['building'] == 'leacock',
      );
      expect(parts, hasLength(leacock.shape.parts.length));
      expect(parts.map((f) => f['id']).toSet(), {leacock.featureId});
      for (final collection in [
        campusOutlineCollection(),
        campusBasemapCollection(),
      ]) {
        expect(
          {for (final f in collection['features']! as List) f['id']},
          {for (final b in campusBuildings) b.featureId},
        );
      }
    });
  });

  test('focusing moves the camera so a card leaves the building visible', () {
    const point = CampusCamera.center;
    (double, double) focus({double left = 0, double up = 0}) =>
        CampusCamera.focusOn(
          point,
          zoom: 18,
          bearing: 0,
          pitch: 45,
          left: left,
          up: up,
        );
    final centred = focus();
    expect(centred.$1, closeTo(point.$1, 1e-9));
    expect(centred.$2, closeTo(point.$2, 1e-9));
    // Facing north: building to the left means looking further east.
    expect(focus(left: 200).$1, greaterThan(point.$1));
    expect(focus(left: 200).$2, closeTo(point.$2, 1e-9));
    // Building higher up means looking further south.
    expect(focus(up: 200).$2, lessThan(point.$2));
  });

  for (final size in const [Size(320, 900), Size(800, 1200)]) {
    testWidgets('card lists every space at ${size.width}', (tester) async {
      final opened = <String>[];
      var closed = 0;
      await _pump(
        tester,
        BuildingCard(
          building: _building('mcconnell'),
          onClose: () => closed++,
          onOpenOrganization: opened.add,
        ),
        size,
      );
      expect(find.text('McConnell Engineering Building'), findsOneWidget);
      expect(find.text('3480 University Street'), findsOneWidget);
      expect(
        find.text('Engineering · Faculty office & lounge'),
        findsOneWidget,
      );
      for (final (name, room) in [
        ('EUS Office', 'Room 7'),
        ('Engineering Common Room', 'Basement, below the EUS Mall'),
        ('Bioengineering Lounge', 'Room 030'),
        ('Mechanical Engineering Lounge', 'Room 120'),
      ]) {
        await tester.scrollUntilVisible(find.text(name), 100);
        expect(find.text(name), findsOneWidget);
        expect(find.text(room), findsOneWidget);
      }
      // EUS runs two of them but gets one link.
      await tester.drag(find.byType(ListView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(find.text('View EUS page'), findsOneWidget);
      await tester.tap(find.text('View EUS page'));
      expect(opened, ['engineering-engineering-undergraduate-society-eus']);
      await tester.tap(find.byTooltip('Close'));
      expect(closed, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unknown rooms say so instead of guessing', (tester) async {
    await _pump(
      tester,
      BuildingCard(building: _building('strathcona-music'), onClose: () {}),
      const Size(400, 900),
    );
    expect(find.text('Room not published'), findsOneWidget);
    expect(find.textContaining('View'), findsNothing);
  });

  testWidgets('legend opens and closes', (tester) async {
    await _pump(tester, const MapLegend(), const Size(320, 640));
    expect(find.text('Engineering'), findsNothing);
    await tester.tap(find.text('Map key'));
    await tester.pumpAndSettle();
    for (final label in ['SSMU', 'Faculty offices', 'Engineering', 'Law']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Student lounge only'), findsOneWidget);
    expect(find.text('Your RSVPs'), findsOneWidget);
    expect(find.textContaining('Ville de Montréal'), findsOneWidget);
    expect(find.textContaining('Open Government'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Map key'));
    await tester.pumpAndSettle();
    expect(find.text('Engineering'), findsNothing);
  });
}
