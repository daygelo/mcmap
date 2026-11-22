import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mcmap/data/campus_groups.dart';
import 'package:mcmap/data/club_event_feed.dart';
import 'package:mcmap/data/clubs.dart';
import 'package:mcmap/models/club_event.dart';
import 'package:mcmap/pages/home_page.dart';
import 'package:mcmap/pages/organization_page.dart';
import 'package:mcmap/pages/student/club_discovery.dart';
import 'package:mcmap/theme/app_theme.dart';
import 'package:mcmap/widgets/group_type_badge.dart';

List<String> _search(String query) => [
  for (final match in searchOrganizations(query, campusGroups))
    match.group?.id ?? match.club!.id,
];

Future<void> _pumpHome(WidgetTester tester, {double width = 800}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(theme: buildMcMapTheme(), home: const HomePage()),
  );
  await tester.pumpAndSettle();
}

Finder _badge(Type row, String name, String label) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(row)),
  matching: find.widgetWithText(GroupTypeBadge, label),
);

void main() {
  test('campus groups are unique, valid and not already in the catalog', () {
    final ids = campusGroups.map((g) => g.id).toSet();
    expect(ids, hasLength(campusGroups.length));
    expect(ids.where(clubsById.containsKey), isEmpty);
    final handles = campusGroups.map((g) => g.handle).nonNulls.toList();
    expect(handles.toSet(), hasLength(handles.length));
    for (final group in campusGroups) {
      expect(group.id, matches(RegExp(r'^[a-z0-9-]+$')));
      expect(group.type, isNotNull);
      if (group.handle case final handle?) {
        expect(handle, matches(RegExp(r'^[a-z0-9._]{2,30}$')));
      }
    }
  });

  test('the seed never repeats a catalog club under another id', () {
    String key(String name) =>
        normalizeClubSearch(name.replaceAll(RegExp(r'\s*\([^)]*\)'), ''));
    final catalogNames = {for (final club in clubCatalog) key(club.name)};
    final rows = RegExp(
      r"^  \('([a-z0-9%-]+)', '((?:[^']|'')*)', .*",
      multiLine: true,
    ).allMatches(File('supabase/seed.sql').readAsStringSync());
    final others = {
      for (final row in rows)
        if (!clubsById.containsKey(row[1]))
          row[1]!: row[2]!.replaceAll("''", "'"),
    };
    expect(others, contains('ssmu-frosh-committee'));
    expect(
      others.entries.where((e) => catalogNames.contains(key(e.value))),
      isEmpty,
    );
  });

  test(
    'seed contains each catalog and campus slug once with its classification',
    () {
      final seed = File('supabase/seed.sql').readAsStringSync();
      final groupStatements = RegExp(r'insert into public\.groups [^;]+;')
          .allMatches(seed)
          .map((match) => match[0]!)
          .join('\n');
      final rows = RegExp(
        r"^  \('([^']+)', (.*)$",
        multiLine: true,
      ).allMatches(groupStatements).toList();
      final bySlug = {for (final row in rows) row[1]!: row[2]!};
      expect(bySlug, hasLength(rows.length));
      for (final club in clubCatalog) {
        expect(
          bySlug[club.id],
          contains("'${club.type.dbValue}'"),
          reason: club.id,
        );
      }
      for (final group in campusGroups) {
        final row = bySlug[group.id];
        expect(row, contains("'${group.type!.dbValue}'"), reason: group.id);
        expect(row, contains('{"verified": ${group.sourceUrl != null}}'));
        if (group.handle case final handle?) expect(row, contains("'$handle'"));
        if (group.facultyAffiliation case final faculty?) {
          expect(row, contains("'$faculty'"));
        }
      }
      expect(bySlug, isNot(contains('mcgill-csus')));
      expect(bySlug['science-csus'], contains("'CSUS'"));
      expect(bySlug['science-csus'], contains("'Science'"));
      expect(
        bySlug['science-csus'],
        contains('Represents McGill undergraduate computer science students.'),
      );
      expect(
        bySlug['science-csus'],
        contains('https://mcgill-csus.ca/get-involved'),
      );
      expect(bySlug['science-csus'], contains('{"verified": true}'));
      expect(bySlug['aus'], contains("'faculty_association'"));
      expect(bySlug['sus'], contains("'faculty_association'"));
    },
  );

  test('group types round-trip and unknown types are ignored', () {
    final values = OrganizationType.values.map((t) => t.dbValue).toSet();
    expect(values, hasLength(OrganizationType.values.length));
    for (final type in OrganizationType.values) {
      expect(OrganizationType.fromDb(type.dbValue), type);
    }
    expect(OrganizationType.fromDb('something_new'), isNull);
    // A row from a database without the new columns still loads.
    final group = CampusGroup.fromRow({'slug': 'x', 'name': 'X', 'type': '?'});
    expect((group.type, group.handle, group.shortName), (null, null, null));
  });

  test('search finds groups by name, handle and type', () {
    expect(_search('mcgill.ml').first, 'mcgill-ml');
    expect(_search('@mcgill.ml'), ['mcgill-ml']);
    expect(_search('mcgillailab').first, 'mcgill-ai-lab');
    expect(_search('MAIS').first, 'mcgill-ai-society');
    expect(_search('AI').take(2), ['mcgill-ai-society', 'mcgill-ai-lab']);
    expect(_search('lab'), contains('mcgill-ai-lab'));
    expect(_search('society').take(5), contains('mcgill-ai-society'));
    expect(_search('CSUS').first, 'science-csus');
    expect(_search('CSUS'), isNot(contains('mcgill-csus')));
    expect(
      _search('research group').take(3),
      containsAll([
        'mcgill-ai-lab',
        'mcgill-autonomous-vehicles-perception-lab',
        'mcgill-computational-biology-research-group',
      ]),
    );
    // Short queries don't match the middle of unrelated words.
    expect(_search('ai'), isNot(contains('mcgill-finance-society')));
  });

  test('searching a handle finds its events, newest created first', () {
    final now = DateTime.utc(2026, 11, 21);
    ClubEvent event(String id, String clubId, int createdHoursAgo) => ClubEvent(
      id,
      id,
      clubId,
      '',
      '',
      clubId: clubId,
      startsAt: now.add(const Duration(days: 3)),
      createdAt: now.subtract(Duration(hours: createdHoursAgo)),
      tags: const ['ai'],
    );
    List<String> feed(String query) => [
      for (final entry in buildClubEventFeed(
        [
          event('workshop', 'mcgill-ml', 2),
          event('mixer', 'mcgill-ai-society', 8),
          event('project night', 'mcgill-ml', 72),
        ],
        now: now,
        query: query,
        matchesOrganization: (id) =>
            campusGroups.any((g) => g.id == id && g.searchRank(query) != null),
      ))
        entry.event.id,
    ];
    expect(feed('@mcgill.ml'), ['workshop', 'project night']);
    expect(feed('mcgillai'), ['mixer']);
    expect(feed('ai'), ['workshop', 'mixer', 'project night']);
  });

  for (final width in [320.0, 800.0]) {
    testWidgets('badges show in search and on the page at $width', (
      tester,
    ) async {
      await _pumpHome(tester, width: width);
      await tester.enterText(find.byType(SearchBar), 'mcgill ai');
      await tester.pumpAndSettle();
      expect(
        _badge(OrganizationRow, 'McGill AI Society', 'Society'),
        findsOneWidget,
      );
      expect(
        _badge(OrganizationRow, 'McGill AI Lab', 'Research Group'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('McGill AI Lab'));
      await tester.pumpAndSettle();
      expect(find.byType(OrganizationPage), findsOneWidget);
      expect(find.text('@mcgillailab'), findsOneWidget);
      expect(
        find.widgetWithText(GroupTypeBadge, 'Research Group'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Browse Clubs filters by type at $width', (tester) async {
      await _pumpHome(tester, width: width);
      await tester.tap(find.text('Discover Clubs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See all clubs'));
      await tester.pumpAndSettle();
      final research = find.widgetWithText(ChoiceChip, 'Research Groups');
      await tester.ensureVisible(research);
      await tester.tap(research);
      await tester.pumpAndSettle();
      expect(find.byType(OrganizationRow), findsNWidgets(3));
      expect(find.byType(ClubRow), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
