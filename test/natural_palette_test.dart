import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mcmap/data/campus_buildings.dart';
import 'package:mcmap/data/campus_map.dart';
import 'package:mcmap/data/clubs.dart';
import 'package:mcmap/data/interests.dart';
import 'package:mcmap/theme/app_theme.dart';
import 'package:mcmap/widgets/group_type_badge.dart';
import 'package:mcmap/widgets/initials_avatar.dart';
import 'package:mcmap/widgets/interest_pin.dart';

double _contrast(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  return x > y ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05);
}

Color _css(Object? value) =>
    Color(0xFF000000 | int.parse((value! as String).substring(1), radix: 16));

void main() {
  group('map greenery', () {
    test('is on, with trees', () {
      expect(campusBasemap['theme'], 'default');
      expect(campusBasemap['show3dTrees'], isTrue);
      for (final ground in ['colorGreenspace', 'colorEducation']) {
        final hue = HSLColor.fromColor(_css(campusBasemap[ground]));
        expect(hue.hue, inInclusiveRange(80, 140), reason: ground);
        expect(hue.saturation, greaterThan(0.2), reason: ground);
      }
    });

    test('leaves the highlighted buildings and pins standing out', () {
      for (final ground in ['colorGreenspace', 'colorEducation']) {
        final green = _css(campusBasemap[ground]);
        for (final highlight in BuildingHighlight.values) {
          final color = Color(0xFF000000 | highlight.color);
          expect(
            _contrast(color, green),
            greaterThan(2),
            reason: '${highlight.label} on $ground',
          );
        }
        expect(_contrast(McMapColors.red, green), greaterThan(2.5));
      }
    });
  });

  test('accents are readable on their tints and under white', () {
    for (final accent in McMapAccent.values) {
      expect(
        _contrast(accent.deep, accent.tint),
        greaterThanOrEqualTo(4.5),
        reason: accent.name,
      );
      expect(
        _contrast(accent.deep, McMapColors.white),
        greaterThanOrEqualTo(4.5),
        reason: accent.name,
      );
      expect(
        _contrast(McMapColors.ink, accent.tint),
        greaterThanOrEqualTo(7),
        reason: accent.name,
      );
    }
  });

  test('a name keeps its accent', () {
    expect(McMapAccent.of('Chess Club'), McMapAccent.of(' chess club '));
    final used = {for (final club in clubCatalog) McMapAccent.of(club.name)};
    expect(used, McMapAccent.values.toSet());
  });

  test('every interest has its own symbol, in varied colours', () {
    expect(
      {for (final interest in allInterests) interest.icon}.length,
      allInterests.length,
    );
    expect({
      for (final interest in allInterests) interest.accent,
    }, McMapAccent.values.toSet());
    for (var i = 1; i < allInterests.length; i++) {
      expect(
        allInterests[i].accent,
        isNot(allInterests[i - 1].accent),
        reason: allInterests[i].name,
      );
    }
  });

  testWidgets('interest pins keep their symbol inside the pin', (tester) async {
    for (final height in [40.0, 72.0, 160.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: InterestPin(allInterests.first, height: height)),
        ),
      );
      final pin = tester.getRect(find.byType(InterestPin));
      final icon = tester.getRect(find.byType(Icon));
      expect(pin.height, closeTo(height, 0.01));
      expect(icon.center.dx, closeTo(pin.center.dx, 0.5));
      expect(icon.top, greaterThan(pin.top));
      // The head is the top 28/50 or so.
      expect(icon.bottom, lessThan(pin.top + height * 0.62));
    }
  });

  testWidgets('badges and initials pass AA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            for (final type in OrganizationType.values) GroupTypeBadge(type),
            const InitialsAvatar(name: 'Chess Club'),
          ],
        ),
      ),
    );
    for (final badge in tester.widgetList<Container>(
      find.descendant(
        of: find.byType(GroupTypeBadge),
        matching: find.byType(Container),
      ),
    )) {
      final background = (badge.decoration! as BoxDecoration).color!;
      final label = (badge.child! as Text).style!.color!;
      expect(_contrast(background, label), greaterThanOrEqualTo(4.5));
    }
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(
      _contrast(avatar.backgroundColor!, avatar.foregroundColor!),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('choices are pine, actions stay McGill red', (tester) async {
    final theme = buildMcMapTheme();
    expect(theme.chipTheme.selectedColor, McMapAccent.pine.tint);
    expect(theme.colorScheme.primary, McMapColors.redFill);
    expect(theme.navigationBarTheme.indicatorColor, McMapColors.redTint);
    final label = theme.chipTheme.secondaryLabelStyle!.color!;
    expect(
      _contrast(label, theme.chipTheme.selectedColor!),
      greaterThanOrEqualTo(4.5),
    );
  });
}
