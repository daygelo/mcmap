import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:mcmap/main.dart';
import 'package:mcmap/pages/home_page.dart';
import 'package:mcmap/pages/map_page.dart';
import 'package:mcmap/pages/student/suggested_clubs.dart';
import 'package:mcmap/widgets/mcmap_logo.dart';
import 'package:mcmap/theme/app_theme.dart';
import 'package:mcmap/models/student_visibility.dart';
import 'package:mcmap/pages/student/student_profile.dart';
import 'package:mcmap/social/mcgillian_widgets.dart';
import 'package:mcmap/widgets/profile_stats.dart';
import 'package:mcmap/widgets/froshie_tag.dart';

Future<void> _goToAcademicInfo(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // No Supabase keys in tests, so this goes through the offline demo.
  await tester.pumpWidget(const McMapApp());
  expect(find.text('Supabase configuration required'), findsOneWidget);

  await tester.tap(find.text('Explore the offline demo'));
  await tester.pumpAndSettle();
  expect(find.text('What do you study?'), findsOneWidget);
}

FilledButton _continueButton(WidgetTester tester) =>
    tester.widget(find.widgetWithText(FilledButton, 'Continue'));

Future<void> _pickMajor(WidgetTester tester, String search, String pick) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(DropdownMenu<String>),
      matching: find.byType(TextField),
    ),
    search,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(pick).last);
  await tester.pumpAndSettle();
}

/// Login → Undergraduate / U2 / Engineering / Software Engineering → interests.
Future<void> _goToInterests(WidgetTester tester) async {
  await _goToAcademicInfo(tester);

  await tester.tap(find.text('Undergraduate'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('U2'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Engineering'));
  await tester.pumpAndSettle();
  expect(_continueButton(tester).onPressed, isNull);
  await _pickMajor(tester, 'Software', 'Software Engineering');
  expect(_continueButton(tester).onPressed, isNotNull);

  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await tester.pumpAndSettle();
  expect(find.text('What are you into?'), findsOneWidget);
}

Future<void> _skipClubs(WidgetTester tester) async {
  expect(find.text('Step 3 of 3'), findsOneWidget);
  await tester.tap(
    find.textContaining(RegExp(r'^Skip (for now|optional groups)$')),
  );
  await tester.pumpAndSettle();
}

Future<void> _revealFeed(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
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
    expect(find.text('Find club events'), findsNothing);
    final search = find.byType(SearchBar);
    expect(search.hitTestable(), findsOneWidget);
    expect(
      tester.getTopLeft(search).dy -
          tester.getBottomLeft(find.byType(AppBar)).dy,
      inInclusiveRange(0, 20),
    );
    final wordmark = find.byType(McMapWordmark);
    final logo = find.descendant(
      of: wordmark,
      matching: find.byType(McMapLogo),
    );
    expect(logo, findsOneWidget);
    expect(tester.getSize(logo), const Size.square(32));
    expect(
      tester.getTopRight(logo).dx,
      lessThan(tester.getTopLeft(find.text('McMap')).dx),
    );
    final header = tester.element(find.text('McMap'));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final titleStyle = DefaultTextStyle.of(header).style;
    final gear = tester.element(find.byIcon(Icons.settings_outlined));
    expect(appBar.backgroundColor, const Color(0xFFED1B2F));
    expect(titleStyle.color, McMapColors.white);
    expect(titleStyle.fontFamily, McMapFonts.serif);
    expect(titleStyle.fontSize, 26);
    expect(IconTheme.of(gear).color, McMapColors.white);
    await _revealFeed(tester, find.text('Club events'));
    expect(find.text('Club events'), findsOneWidget);
    await _revealFeed(tester, find.text('Board Game Night'));
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
    await _revealFeed(tester, find.text('Photo Walk'));
    expect(find.text('Photo Walk'), findsOneWidget);
    expect(find.text('Board Game Night'), findsNothing);

    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.enterText(search, 'no matching club');
    await tester.pumpAndSettle();
    await _revealFeed(tester, find.text('No club events match your search.'));
    expect(find.text('No club events match your search.'), findsOneWidget);
  });

  testWidgets(
    'the Home feed ends with View All Events at four viewport widths',
    (tester) async {
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
        final header = tester.getRect(find.byType(AppBar));
        expect(
          header.contains(tester.getCenter(find.byType(McMapLogo))),
          isTrue,
        );
        expect(header.contains(tester.getCenter(find.text('McMap'))), isTrue);
        final feed = find.byType(ListView).first;
        final lastEvent = find.text('Campus Coding Meetup');
        final scrollable = tester.state<ScrollableState>(
          find.descendant(of: feed, matching: find.byType(Scrollable)).first,
        );
        // The lazy list only estimates its length until the last cards are
        // built, so keep jumping to the end until the extent stops growing.
        double? extent;
        while (extent != scrollable.position.maxScrollExtent) {
          extent = scrollable.position.maxScrollExtent;
          scrollable.position.jumpTo(extent);
          await tester.pumpAndSettle();
        }

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
        final viewAll = find.widgetWithText(FilledButton, 'View All Events');
        expect(viewAll.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(viewAll).top,
          greaterThan(tester.getRect(lastCard).bottom),
        );
        expect(
          tester.getRect(feed).bottom - tester.getRect(viewAll).bottom,
          24,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('shows an RSVP in Profile and syncs cancellation to Home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildMcMapTheme(), home: const HomePage()),
    );

    await _revealFeed(tester, find.text('Board Game Night'));
    final boardCard = find.ancestor(
      of: find.text('Board Game Night'),
      matching: find.byType(Card),
    );
    final rsvp = find.descendant(of: boardCard, matching: find.text('RSVP'));
    await tester.ensureVisible(rsvp);
    await tester.pumpAndSettle();
    await tester.tap(rsvp);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Sample profile').hitTestable(), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ProfileHeader),
        matching: find.byType(FroshieTag),
      ),
      findsOneWidget,
      reason: 'sample profile is U0',
    );
    await tester.scrollUntilVisible(
      find.text('Going · Demo visibility: Private'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView).last,
        matching: find.byType(Scrollable),
      ),
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
    expect(
      find.descendant(
        of: find.byType(ProfileHeader),
        matching: find.byType(FroshieTag),
      ),
      findsNothing,
      reason: 'no longer U0 after switching to U2',
    );
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
    'offers only RSVP privacy and preserves existing RSVP visibility',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1150));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(theme: buildMcMapTheme(), home: const HomePage()),
      );

      await tester.tap(find.text('RSVP').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      final radioGroup = find.byType(RadioGroup<StudentVisibility>);
      StudentVisibility? selected() =>
          tester.widget<RadioGroup<StudentVisibility>>(radioGroup).groupValue;
      expect(radioGroup, findsOneWidget);
      expect(find.text('Who can see my RSVPs?'), findsOneWidget);
      expect(find.text('Who can view my profile?'), findsNothing);
      for (final option in StudentVisibility.values) {
        expect(find.text(option.label), findsOneWidget);
      }
      expect(selected(), StudentVisibility.private);
      await tester.tap(find.text('Friends'));
      await tester.pumpAndSettle();
      expect(selected(), StudentVisibility.friends);
      await tester.tap(find.text('Public'));
      await tester.pumpAndSettle();
      expect(selected(), StudentVisibility.public);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('RSVP').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(find.byType(McGillMapPage).hitTestable(), findsOneWidget);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(
        find.text('Going · Demo visibility: Private').hitTestable(),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Going · Demo visibility: Public'));
      await tester.pumpAndSettle();
      expect(
        find.text('Going · Demo visibility: Public').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(selected(), StudentVisibility.public);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Your profile'),
        -300,
        scrollable: find
            .ancestor(
              of: find.text('Going · Demo visibility: Public'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
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
    for (final (query, club) in [
      ('MESA', 'McGill Esports Student’s Association'),
      ('Board Game', 'Mcgill Board Game Students’ Society'),
    ]) {
      await tester.enterText(find.byType(SearchBar), query);
      await tester.pumpAndSettle();
      await tester.tap(find.text(club));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Software Engineering · Engineering'), findsNothing);
    expect(find.text('Coding').hitTestable(), findsNothing);
    expect(find.text('Board Game Night'), findsOneWidget);
    await tester.tap(find.text('Discover Clubs'));
    await tester.pumpAndSettle();
    final recommendations = tester.widget<SuggestedClubs>(
      find.byType(SuggestedClubs),
    );
    expect(recommendations.faculty, 'Engineering');
    expect(recommendations.major, 'Software Engineering');
    expect(recommendations.interests, contains('Coding'));
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Coding').hitTestable(), findsOneWidget);
    await tester.tap(find.text('5 Following'));
    await tester.pumpAndSettle();
    expect(find.text('McGill Esports Student’s Association'), findsOneWidget);
    expect(find.text('Mcgill Board Game Students’ Society'), findsOneWidget);
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
  });

  testWidgets('interests step can be skipped with none selected', (
    tester,
  ) async {
    await _goToInterests(tester);

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    await _skipClubs(tester);

    expect(find.text('Software Engineering · Engineering'), findsNothing);
    expect(find.textContaining('Showing events for'), findsNothing);
    expect(find.text('Suggested events'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Software Engineering · U2'), findsOneWidget);
    expect(find.text('3 Following'), findsOneWidget);
    expect(find.text('Your Club Memberships'), findsNothing);
    expect(find.text('Add Clubs'), findsNothing);
    await tester.tap(find.text('3 Following'));
    await tester.pumpAndSettle();
    expect(find.text('Students’ Society of McGill University'), findsOneWidget);
    expect(find.text('Browse Clubs'), findsOneWidget);
  });

  testWidgets('U-year only appears for undergraduates', (tester) async {
    await _goToAcademicInfo(tester);

    expect(find.text('U0'), findsNothing);
    expect(find.text('Faculty'), findsNothing);
    await tester.tap(find.text('Undergraduate'));
    await tester.pumpAndSettle();
    expect(find.text('U0'), findsOneWidget);
    expect(find.text('Faculty'), findsNothing, reason: 'year comes first');

    await tester.tap(find.text('U1'));
    await tester.tap(find.text("Master's"));
    await tester.pumpAndSettle();
    expect(find.text('U0'), findsNothing);
    expect(find.text('Faculty'), findsOneWidget);
  });

  testWidgets('graduate standing survives optional onboarding steps', (
    tester,
  ) async {
    await _goToAcademicInfo(tester);
    await tester.tap(find.text("Master's"));
    await tester.pumpAndSettle();
    expect(find.text('U0'), findsNothing);
    await tester.tap(find.text('Engineering'));
    await tester.pumpAndSettle();
    await _pickMajor(tester, 'Software', 'Software Engineering');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    await _skipClubs(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text("Software Engineering · Master's"), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ProfileHeader),
        matching: find.byType(FroshieTag),
      ),
      findsNothing,
    );
  });

  testWidgets('U0 student can pick Undeclared', (tester) async {
    await _goToAcademicInfo(tester);

    await tester.tap(find.text('Undergraduate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('U0'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Science'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Haven't declared yet?"), findsOneWidget);
    await _pickMajor(tester, 'Undecl', 'Undeclared / Freshman Program');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    await _skipClubs(tester);

    expect(find.text('Undeclared / Freshman Program · Science'), findsNothing);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Undeclared / Freshman Program · U0'), findsOneWidget);
    expect(find.text('Science'), findsOneWidget);
  });

  testWidgets('exchange students can continue without a major', (tester) async {
    await _goToAcademicInfo(tester);

    await tester.tap(find.text('Exchange / Continuing Studies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arts'));
    await tester.pumpAndSettle();
    expect(find.text('Program / major (optional)'), findsOneWidget);
    expect(_continueButton(tester).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    await _skipClubs(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(
      find.text('Program not specified · Exchange / Cont. Ed.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('U1 first-year follow-up makes you a Froshie', (tester) async {
    await _goToAcademicInfo(tester);

    await tester.tap(find.text('Undergraduate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('U1'));
    await tester.pumpAndSettle();
    expect(find.text('Is this your first year at McGill?'), findsOneWidget);
    expect(find.text('Faculty'), findsNothing, reason: 'must answer first');

    await tester.tap(find.text("Yes, it's my first year"));
    await tester.pumpAndSettle();
    expect(find.byType(FroshieTag), findsOneWidget);
    await tester.tap(find.text('Arts'));
    await tester.pumpAndSettle();
    await _pickMajor(tester, 'Hist', 'History');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    await _skipClubs(tester);

    expect(find.text('Recommended for you'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ProfileHeader),
        matching: find.byType(FroshieTag),
      ),
      findsOneWidget,
    );
  });

  testWidgets('returning U1 students are not Froshies', (tester) async {
    await _goToAcademicInfo(tester);

    await tester.tap(find.text('Undergraduate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('U1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No, returning student'));
    await tester.pumpAndSettle();
    expect(find.byType(FroshieTag), findsNothing);
    expect(find.text('Faculty'), findsOneWidget);
  });

  group('McGillians', () {
    int statCount(WidgetTester tester) => tester
        .widget<ProfileStat>(find.widgetWithText(ProfileStat, 'McGillians'))
        .value;

    Future<void> pumpHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: buildMcMapTheme(), home: const HomePage()),
      );
    }

    testWidgets('search finds students by major and adds them', (tester) async {
      await pumpHome(tester);
      expect(find.byType(McGillianTile), findsNothing);

      await tester.enterText(find.byType(SearchBar), 'software');
      await tester.pumpAndSettle();
      final amir = find.widgetWithText(McGillianTile, 'Amir Haddad');
      expect(amir, findsOneWidget);
      expect(find.text('No club events match your search.'), findsOneWidget);

      await tester.tap(
        find.descendant(of: amir, matching: find.text('Add Friend')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: amir, matching: find.text('Following')),
        findsOneWidget,
      );

      await tester.enterText(find.byType(SearchBar), '@dan');
      await tester.pumpAndSettle();
      final dan = find.widgetWithText(McGillianTile, 'Daniel Okafor');
      await tester.tap(
        find.descendant(of: dan, matching: find.text('Add Friend')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: dan, matching: find.text('Requested')),
        findsOneWidget,
        reason: 'private profile',
      );
    });

    testWidgets('filter tabs switch between events and students', (
      tester,
    ) async {
      await pumpHome(tester);

      // Pills are hidden until the search bar is focused.
      expect(find.widgetWithText(ChoiceChip, 'McGillians'), findsNothing);
      await tester.tap(find.byType(SearchBar));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'McGillians'));
      await tester.pumpAndSettle();
      expect(find.text('Suggested McGillians'), findsOneWidget);
      expect(find.text('Board Game Night'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Events'));
      await tester.enterText(find.byType(SearchBar), 'maya');
      await tester.pumpAndSettle();
      expect(find.byType(McGillianTile), findsNothing);
    });

    testWidgets('McGillians count opens a manageable list', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(statCount(tester), 3);
      await tester.tap(find.widgetWithText(ProfileStat, 'McGillians'));
      await tester.pumpAndSettle();
      expect(find.text('3 McGillians'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Search your McGillians'),
        'leo',
      );
      await tester.pumpAndSettle();
      expect(find.byType(McGillianTile), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('2 McGillians'), findsOneWidget);
    });

    testWidgets('student profile shows count and friend state', (tester) async {
      await pumpHome(tester);
      await tester.enterText(find.byType(SearchBar), 'chlo');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chloé Gagnon'));
      await tester.pumpAndSettle();

      expect(find.text('@chloe.g'), findsNothing);
      expect(find.text('Chloé Gagnon'), findsOneWidget);
      expect(find.byType(FroshieTag), findsOneWidget, reason: 'U1 first-year');
      expect(statCount(tester), 31);
      await tester.tap(find.text('Add Friend'));
      await tester.pumpAndSettle();
      expect(statCount(tester), 32);

      await tester.tap(find.text('Following'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Add Friend'), findsOneWidget);
    });

    testWidgets('student rows fit on a small phone', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: buildMcMapTheme(), home: const HomePage()),
      );
      await tester.tap(find.byType(SearchBar));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'McGillians'));
      await tester.pumpAndSettle();
      expect(find.byType(McGillianTile), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('profile header puts avatar beside the stats', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('RSVP').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      int stat(String label) => tester
          .widget<ProfileStat>(find.widgetWithText(ProfileStat, label))
          .value;
      expect(stat('Events'), 1);
      expect(stat('Clubs'), 1);

      final avatar = tester.getRect(find.byType(EditableProfileAvatar));
      final mcgillians = tester.getRect(
        find.widgetWithText(ProfileStat, 'McGillians'),
      );
      expect(mcgillians.left, greaterThan(avatar.right));
      expect(mcgillians.center.dy, closeTo(avatar.center.dy, 2));
      expect(find.text('Share Profile'), findsOneWidget);
    });

    testWidgets('tapping the avatar opens the photo options', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(EditableProfileAvatar));
      await tester.pumpAndSettle();
      expect(find.text('Choose from library'), findsOneWidget);
      expect(
        find.text('Remove current photo'),
        findsNothing,
        reason: 'no photo yet',
      );
    });

    testWidgets('profile header fits on a small phone', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: buildMcMapTheme(), home: const HomePage()),
      );
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(NavigationDestination).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(SearchBar), 'chlo');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chloé Gagnon'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
