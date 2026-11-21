import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:mcmap/main.dart';
import 'package:mcmap/models/club_event.dart';
import 'package:mcmap/models/user_profile.dart';
import 'package:mcmap/pages/home_page.dart';
import 'package:mcmap/theme/app_theme.dart';
import 'package:mcmap/pages/student/settings_page.dart';

/// Login, select Engineering / Software Engineering / U2, then open interests.
Future<void> _goToInterests(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const McMapApp());
  expect(find.text('Welcome to McMap'), findsOneWidget);

  await tester.tap(find.text('Continue with Microsoft'));
  await tester.pumpAndSettle();
  expect(find.text('What do you study?'), findsOneWidget);

  await tester.tap(find.text('Engineering'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Software Engineering').last);
  await tester.pumpAndSettle();
  expect(
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
        .onPressed,
    isNull,
  );
  await tester.tap(find.byType(DropdownButtonFormField<String>).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('U2').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  expect(find.text('What are you into?'), findsOneWidget);
}

const _esports = 'McGill Esports Student’s Association';
const _esportsId = 'ssmu-mcgill-e-sports-students-society';
const _boardGames = 'Mcgill Board Game Students’ Society';

Future<void> _searchClubs(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(SearchBar), query);
  await tester.pumpAndSettle();
}

Future<void> _revealHome(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the McMap home page', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildMcMapTheme(), home: const HomePage()),
    );

    expect(find.text('McMap'), findsOneWidget);
    expect(find.text('Find club events'), findsOneWidget);
    expect(find.text('Club events'), findsOneWidget);
    final header = tester.element(find.text('McMap'));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final titleStyle = DefaultTextStyle.of(header).style;
    final gear = tester.element(find.byIcon(Icons.settings_outlined));
    expect(appBar.backgroundColor, const Color(0xFFED1B2F));
    expect(titleStyle.color, McMapColors.white);
    expect(titleStyle.fontFamily, McMapFonts.serif);
    expect(titleStyle.fontSize, 26);
    expect(IconTheme.of(gear).color, McMapColors.white);
    await _revealHome(tester, find.text('Board Game Night'));
    expect(find.text('Board Game Night'), findsOneWidget);
    final rsvp = tester.element(
      find.widgetWithText(FilledButton, 'RSVP').first,
    );
    final buttonStyle = FilledButtonTheme.of(rsvp).style!;
    final buttonFill = buttonStyle.backgroundColor!.resolve({})!;
    final buttonText = buttonStyle.foregroundColor!.resolve({})!;
    expect(buttonFill, const Color(0xFFE81B2F));
    expect(buttonText, McMapColors.white);
    expect(
      (buttonText.computeLuminance() + 0.05) /
          (buttonFill.computeLuminance() + 0.05),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('filters events by club and shows an empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildMcMapTheme(), home: const HomePage()),
    );

    final search = find.byType(SearchBar);
    await tester.enterText(search, '  PHOTOGRAPHY  ');
    await tester.pumpAndSettle();
    await _revealHome(tester, find.text('Photo Walk'));
    expect(find.text('Photo Walk'), findsOneWidget);
    expect(find.text('Board Game Night'), findsNothing);

    final feed = tester.state<ScrollableState>(find.byType(Scrollable).first);
    feed.position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.enterText(search, 'no matching club');
    await tester.pumpAndSettle();
    await _revealHome(tester, find.text('No club events match your search.'));
    expect(find.text('No club events match your search.'), findsOneWidget);
  });

  testWidgets('the club feed ends after events at four viewport widths', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 390.0, 768.0, 1280.0]) {
      await tester.binding.setSurfaceSize(Size(width, 600));
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(width),
          theme: buildMcMapTheme(),
          home: const HomePage(),
        ),
      );
      await tester.pumpAndSettle();
      final feed = find.byType(ListView).first;
      final lastEvent = find.text('Campus Coding Meetup');
      final feedScroll = find
          .descendant(of: feed, matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(lastEvent, 200, scrollable: feedScroll);
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(feedScroll);
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();

      for (final label in [
        'Explore campus',
        'Campus map',
        'Buildings',
        'Dining',
        'Parking',
      ]) {
        expect(find.text(label), findsNothing);
      }
      expect(lastEvent.hitTestable(), findsOneWidget);
      final lastCard = find.ancestor(
        of: lastEvent,
        matching: find.byType(Card),
      );
      expect(tester.getRect(feed).bottom - tester.getRect(lastCard).bottom, 24);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('shows an RSVP in Profile and syncs cancellation to Home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildMcMapTheme(), home: const HomePage()),
    );

    await _revealHome(tester, find.text('Board Game Night'));
    final firstCard = find.ancestor(
      of: find.text('Board Game Night'),
      matching: find.byType(Card),
    );
    final rsvp = find.descendant(of: firstCard, matching: find.text('RSVP'));
    await tester.ensureVisible(rsvp);
    await tester.pumpAndSettle();
    await tester.tap(rsvp);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Sample profile').hitTestable(), findsOneWidget);
    final profileScroll = find.descendant(
      of: find.byType(ListView).last,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Going · Demo visibility: Private'),
      220,
      scrollable: profileScroll,
    );
    await tester.pumpAndSettle();
    expect(find.text('Board Game Night'), findsWidgets);
    await tester.ensureVisible(find.text('Cancel RSVP').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel RSVP').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('You have no RSVPs yet.'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel RSVP'), findsNothing);
  });

  testWidgets('validates, saves, and cancels profile edits on mobile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: buildMcMapTheme(), home: const HomePage()),
    );
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    final major = find.byType(TextFormField).first;
    final bio = find.byType(TextFormField).last;
    final save = find.text('Save Changes');
    final editorScroll = find.byType(Scrollable).first;
    Future<void> scrollTo(Finder target, double delta) async {
      for (var attempt = 0; attempt < 20; attempt++) {
        if (target.hitTestable().evaluate().isNotEmpty) return;
        await tester.drag(editorScroll, Offset(0, -delta));
        await tester.pumpAndSettle();
      }
      expect(target.hitTestable(), findsOneWidget);
    }

    await tester.enterText(major, '   ');
    await scrollTo(save, 250);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await scrollTo(find.text('Enter your major or program.'), -250);
    expect(find.text('Enter your major or program.'), findsOneWidget);

    await tester.drag(editorScroll, const Offset(0, 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Faculty of Engineering'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Faculty of Science').last);
    await tester.pumpAndSettle();
    await tester.enterText(major, '  Computer Science  ');
    await tester.ensureVisible(find.text('U0'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('U0'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('U2').last);
    await tester.pumpAndSettle();
    await tester.enterText(bio, '  I like campus events.  ');
    await scrollTo(find.text('Programming'), 150);
    await tester.tap(find.text('Programming'));
    await tester.pumpAndSettle();
    await scrollTo(save, 200);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Computer Science · U2'), findsOneWidget);
    expect(find.text('Faculty of Science'), findsOneWidget);
    expect(find.text('I like campus events.'), findsOneWidget);
    expect(find.text('Froshie'), findsNothing);
    expect(find.text('Programming'), findsOneWidget);

    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();
    await tester.enterText(major, 'Discard me');
    await scrollTo(find.text('Programming'), 150);
    final chip = find.widgetWithText(FilterChip, 'Programming');
    expect(tester.widget<FilterChip>(chip).selected, isTrue);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(chip).selected, isFalse);
    await scrollTo(find.text('Cancel'), 200);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Computer Science · U2'), findsOneWidget);
    expect(find.text('Programming'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps privacy choices independent and preserves RSVP visibility',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(theme: buildMcMapTheme(), home: const HomePage()),
      );

      await tester.tap(find.text('RSVP').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      List<RadioGroup<StudentVisibility>> groups() => tester
          .widgetList<RadioGroup<StudentVisibility>>(
            find.byType(RadioGroup<StudentVisibility>),
          )
          .toList();
      expect(groups().map((group) => group.groupValue?.name), [
        'private',
        'private',
      ]);
      await tester.tap(find.text('Public').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Friends').last);
      await tester.pumpAndSettle();
      expect(groups().map((group) => group.groupValue?.name), [
        'public',
        'friends',
      ]);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('RSVP').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(
        find.text('Campus map is coming soon.').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(
        find.text('Going · Demo visibility: Private').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.text('Going · Demo visibility: Public').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(groups().map((group) => group.groupValue?.name), [
        'public',
        'friends',
      ]);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Your profile').hitTestable(), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('picking interests carries them to home', (tester) async {
    await _goToInterests(tester);

    for (final name in ['Music', 'Coding', 'Coffee']) {
      await tester.tap(
        find.ancestor(
          of: find.text(name),
          matching: find.byType(GestureDetector),
        ),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Skip for now'), findsNothing);
    await tester.tap(find.text('Continue · 3 selected'));
    await tester.pumpAndSettle();
    expect(find.text('Step 3 of 3'), findsOneWidget);
    await _searchClubs(tester, 'MESA');
    await tester.tap(find.text(_esports));
    await tester.pumpAndSettle();
    await _searchClubs(tester, 'board game');
    await tester.tap(find.text(_boardGames));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Software Engineering · Engineering'), findsOneWidget);
    expect(find.text('Coding').hitTestable(), findsOneWidget);
    expect(find.text('Board Game Night'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Coding').hitTestable(), findsOneWidget);
    expect(find.text('Software Engineering · U2'), findsOneWidget);
    await tester.tap(find.text('2 Club Memberships'));
    await tester.pumpAndSettle();
    expect(find.text('Your Club Memberships'), findsOneWidget);
    expect(find.text(_esports).hitTestable(), findsOneWidget);
    expect(find.text(_boardGames).hitTestable(), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Engineering'), findsOneWidget);
    final coding = find.widgetWithText(FilterChip, 'Coding');
    await tester.scrollUntilVisible(
      coding,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilterChip>(coding).selected, isTrue);
    final year = find.byType(DropdownButtonFormField<String>).last;
    expect(tester.state<FormFieldState<String>>(year).value, 'U2');
    await tester.tap(year);
    await tester.pumpAndSettle();
    await tester.tap(find.text('U3').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Software Engineering · U3'), findsOneWidget);
    await tester.tap(find.text('2 Club Memberships'));
    await tester.pumpAndSettle();
    expect(find.text(_esports).hitTestable(), findsOneWidget);
    expect(find.text(_boardGames).hitTestable(), findsOneWidget);
  });

  testWidgets('interests step can be skipped with none selected', (
    tester,
  ) async {
    await _goToInterests(tester);

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(find.text('Step 3 of 3'), findsOneWidget);
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(find.text('Software Engineering · Engineering'), findsOneWidget);
    expect(find.text('Add interests later from Edit Profile.'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0 Club Memberships'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('You have no club memberships.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Add Clubs'));
    await tester.pumpAndSettle();
    await _searchClubs(tester, "McGill Esports Student's Association");
    await tester.tap(find.text(_esports));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Clubs'));
    await tester.pumpAndSettle();
    expect(find.text(_esports).hitTestable(), findsOneWidget);
  });

  testWidgets(
    'private club management keeps hiding separate from RSVP opt-in and removal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final publications = StreamController<ClubEvent>();
      addTearDown(publications.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMcMapTheme(),
          home: HomePage(
            profile: const UserProfile(
              faculty: 'Engineering',
              major: 'Software Engineering',
              year: 'U2',
              memberships: {_esportsId: ClubMembership()},
            ),
            publications: publications.stream,
          ),
        ),
      );
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 Club Memberships'));
      await tester.pumpAndSettle();
      final visibility = find.widgetWithText(
        SwitchListTile,
        'Show membership on profile',
      );
      final auto = find.widgetWithText(
        SwitchListTile,
        "Auto-RSVP to this club's events",
      );
      expect(tester.widget<SwitchListTile>(visibility).value, isFalse);
      expect(tester.widget<SwitchListTile>(auto).value, isFalse);
      await tester.tap(visibility);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(visibility).value, isTrue);
      await tester.tap(auto);
      await tester.pumpAndSettle();
      await tester.tap(visibility);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(visibility).value, isFalse);
      expect(tester.widget<SwitchListTile>(auto).value, isTrue);
      expect(find.text(_esports).hitTestable(), findsOneWidget);

      ClubEvent published(String id) => ClubEvent(
        id,
        id,
        _esports,
        'Tomorrow',
        'Campus',
        clubId: _esportsId,
        publishedAt: DateTime.now(),
        startsAt: DateTime.now().add(const Duration(days: 1)),
        supportsUnrestrictedRsvp: true,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      final first = published('New club event');
      publications.add(first);
      publications.add(first);
      await tester.pumpAndSettle();
      expect(
        find.text('Going · Demo visibility: Private').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('1 Club Memberships'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove club'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('You have no club memberships.').hitTestable(),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      publications.add(published('After removal'));
      await tester.pumpAndSettle();
      expect(
        find.text('Going · Demo visibility: Private').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('After removal').hitTestable(), findsNothing);
      await tester.tap(find.text('Cancel RSVP').hitTestable());
      await tester.pumpAndSettle();
      publications.add(first);
      await tester.pumpAndSettle();
      expect(find.text('You have no RSVPs yet.').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
