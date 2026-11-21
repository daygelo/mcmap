import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:mcmap/main.dart';
import 'package:mcmap/pages/student/settings_page.dart';

void main() {
  testWidgets('shows the McMap home page', (WidgetTester tester) async {
    await tester.pumpWidget(const McMapApp());

    expect(find.text('McMap'), findsOneWidget);
    expect(find.text('Find club events'), findsOneWidget);
    expect(find.text('Club events'), findsOneWidget);
    expect(find.text('Board Game Night'), findsOneWidget);
    final header = tester.element(find.text('McMap'));
    final search = tester.element(find.byType(SearchBar));
    expect(AppBarTheme.of(header).backgroundColor, const Color(0xFF9E0918));
    expect(DefaultTextStyle.of(header).style.fontWeight, FontWeight.w800);
    expect(
      SearchBarTheme.of(search).backgroundColor?.resolve({}),
      const Color(0xFFFFF1F2),
    );
  });

  testWidgets('filters events by club and shows an empty state', (
    tester,
  ) async {
    await tester.pumpWidget(const McMapApp());

    final search = find.byType(SearchBar);
    await tester.enterText(search, '  PHOTOGRAPHY  ');
    await tester.pumpAndSettle();
    expect(find.text('Photo Walk'), findsOneWidget);
    expect(find.text('Board Game Night'), findsNothing);

    await tester.enterText(search, 'no matching club');
    await tester.pumpAndSettle();
    expect(find.text('No club events match your search.'), findsOneWidget);
  });

  testWidgets('shows an RSVP in Profile and syncs cancellation to Home', (
    tester,
  ) async {
    await tester.pumpWidget(const McMapApp());

    await tester.tap(find.text('RSVP').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Sample profile').hitTestable(), findsOneWidget);
    expect(find.text('Board Game Night').hitTestable(), findsOneWidget);
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
    await tester.pumpWidget(const McMapApp());
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    final major = find.byType(TextFormField).first;
    final bio = find.byType(TextFormField).last;
    final save = find.text('Save Changes');
    final editorScroll = find.byType(Scrollable).first;
    Future<void> scrollTo(Finder target, double delta) =>
        tester.scrollUntilVisible(target, delta, scrollable: editorScroll);

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
      await tester.binding.setSurfaceSize(const Size(1280, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const McMapApp());

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
}
