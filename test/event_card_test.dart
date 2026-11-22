import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mcmap/data/academics.dart';
import 'package:mcmap/models/user_profile.dart';
import 'package:mcmap/pages/all_events_page.dart';
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

  testWidgets('cards show the club avatar and an AI summary', (tester) async {
    await _pumpHome(tester);
    final card = _card('Photo Walk');
    expect(
      find.descendant(of: card, matching: find.byType(InitialsAvatar)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('AI SUMMARY')),
      findsOneWidget,
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

  testWidgets('no follows: only Suggested events, then View All Events', (
    tester,
  ) async {
    await _pumpHome(tester);
    // The demo profile follows nothing: no followed section or placeholder,
    // straight into Suggested events.
    expect(find.text('From clubs you follow'), findsNothing);
    expect(find.textContaining('not following'), findsNothing);
    expect(find.text('Suggested events'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Suggested events')).dy,
      lessThan(tester.getTopLeft(find.text('Board Game Night')).dy),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'View All Events'));
    await tester.pumpAndSettle();
    expect(find.byType(AllEventsPage), findsOneWidget);
    expect(find.text('4 of 4 events'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Froshie'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 4 events'), findsOneWidget);
    expect(find.text('Frosh Week Kickoff'), findsOneWidget);
    expect(find.text('Board Game Night'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AllEventsPage), findsNothing);
  });

  testWidgets('Home tab clears an active search, even from another tab', (
    tester,
  ) async {
    await _pumpHome(tester);
    await tester.tap(find.byType(SearchBar));
    await tester.enterText(find.byType(SearchBar), 'photo');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'McGillians'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SearchBar>(find.byType(SearchBar)).controller!.text,
      '',
    );
    expect(find.widgetWithText(ChoiceChip, 'McGillians'), findsNothing);
    expect(find.text('Suggested events'), findsOneWidget);
  });

  testWidgets('followed clubs without events: section hidden, no blank card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMcMapTheme(),
        home: const HomePage(
          profile: UserProfile(
            degreeLevel: DegreeLevel.undergraduate,
            year: 'U2',
            faculty: 'Science',
            major: 'Biology',
            // Follows SSMU, but the sample feed has no SSMU events.
            followedClubIds: {'mcgill-ssmu'},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('From clubs you follow'), findsNothing);
    expect(find.text('Suggested events'), findsOneWidget);
    expect(find.text('Board Game Night'), findsOneWidget);
  });
}
