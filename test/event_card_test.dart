import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mcmap/pages/event_details_page.dart';
import 'package:mcmap/pages/home_page.dart';
import 'package:mcmap/pages/organization_page.dart';
import 'package:mcmap/theme/app_theme.dart';
import 'package:mcmap/widgets/initials_avatar.dart';

Future<void> _pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(theme: buildMcMapTheme(), home: const HomePage()),
  );
  await tester.pumpAndSettle();
}

Finder _card(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(Card)).first;

void main() {
  test('initials skip filler words', () {
    expect(initialsFor('SSMU Frosh Committee'), 'SF');
    expect(initialsFor('Faculty of Engineering'), 'FE');
    expect(initialsFor('chess'), 'C');
  });

  testWidgets('cards show the club avatar and summary without a label', (
    tester,
  ) async {
    await _pumpHome(tester);
    final card = _card('Photo Walk');
    expect(
      find.descendant(of: card, matching: find.byType(InitialsAvatar)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('AI SUMMARY')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.byIcon(Icons.auto_awesome_rounded),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('golden-hour')),
      findsOneWidget,
    );
  });

  testWidgets('club avatar opens the organization page', (tester) async {
    await _pumpHome(tester);
    await tester.tap(
      find.descendant(
        of: _card('Frosh Week Kickoff'),
        matching: find.byType(InitialsAvatar),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OrganizationPage), findsOneWidget);
    expect(find.byType(EventDetailsPage), findsNothing);
    expect(find.textContaining('Coming soon'), findsOneWidget);
  });

  testWidgets('card body opens full details with a map slot', (tester) async {
    await _pumpHome(tester);
    await tester.tap(find.text('Photo Walk'));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailsPage), findsOneWidget);
    expect(find.textContaining('Kondiaronk Belvedere'), findsOneWidget);
    expect(find.text('AI SUMMARY'), findsNothing);
    expect(
      find.text('Interactive Map View — Ready for Map Integration'),
      findsOneWidget,
    );

    // RSVP from details, and the club avatar still works here.
    await tester.tap(find.text('RSVP'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel RSVP'), findsOneWidget);
    await tester.tap(find.byType(InitialsAvatar));
    await tester.pumpAndSettle();
    expect(find.byType(OrganizationPage), findsOneWidget);
  });

  testWidgets('RSVP on a card does not open details', (tester) async {
    await _pumpHome(tester);
    await tester.tap(
      find.descendant(of: _card('Photo Walk'), matching: find.text('RSVP')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailsPage), findsNothing);
    expect(
      find.descendant(
        of: _card('Photo Walk'),
        matching: find.text('Cancel RSVP'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('search pills appear on focus and Cancel collapses them', (
    tester,
  ) async {
    await _pumpHome(tester);
    expect(find.widgetWithText(ChoiceChip, 'McGillians'), findsNothing);
    expect(find.text('Cancel'), findsNothing);

    await tester.tap(find.byType(SearchBar));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'McGillians'));
    await tester.pumpAndSettle();
    expect(find.text('Suggested McGillians'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'McGillians'), findsNothing);
    expect(find.text('Suggested McGillians'), findsNothing);
    expect(find.text('Board Game Night'), findsOneWidget);
  });
}
