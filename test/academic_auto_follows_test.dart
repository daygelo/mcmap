import 'package:flutter_test/flutter_test.dart';
import 'package:mcmap/data/academic_auto_follows.dart';
import 'package:mcmap/data/academics.dart';
import 'package:mcmap/data/clubs.dart';
import 'package:mcmap/models/user_profile.dart';

const ssmu = 'mcgill-ssmu';
const fyc = 'ssmu-first-year-council';
const pgss = 'mcgill-pgss';
const eus = 'engineering-engineering-undergraduate-society-eus';
const ecsess =
    'engineering-electrical-computer-software-engineering-student-society-ecsess';
const csus = 'science-csus';

UserProfile profile(
  String faculty,
  String? program, {
  DegreeLevel degree = DegreeLevel.undergraduate,
  String year = 'U2',
  bool newU1 = false,
}) => UserProfile(
  degreeLevel: degree,
  faculty: faculty,
  major: program,
  year: degree.hasUYear ? year : null,
  firstYearAtMcGill: newU1,
);

void main() {
  final examples = <(String, UserProfile, Set<String>)>[
    (
      'U0 Software Engineering',
      profile('Engineering', 'Software Engineering', year: 'U0'),
      {ssmu, eus, ecsess, fyc, 'eus-junior-council', 'ecsess-bits'},
    ),
    (
      'U2 Software Engineering',
      profile('Engineering', 'Software Engineering'),
      {ssmu, eus, ecsess},
    ),
    (
      'U1 returning',
      profile('Engineering', 'Computer Engineering', year: 'U1'),
      {ssmu, eus, ecsess},
    ),
    (
      'U1 new',
      profile('Engineering', 'Electrical Engineering', year: 'U1', newU1: true),
      {ssmu, eus, ecsess, fyc, 'eus-junior-council', 'ecsess-bits'},
    ),
    (
      'Science Computer Science',
      profile('Science', 'Computer Science'),
      {ssmu, 'sus', csus},
    ),
    (
      'Arts Computer Science',
      profile('Arts', 'Computer Science (Arts)'),
      {ssmu, 'aus', csus},
    ),
    (
      'first-year Arts Political Science',
      profile('Arts', 'Political Science', year: 'U0'),
      {ssmu, 'aus', 'arts-pssa', fyc, 'aus-fearc', 'pssa-first-year-council'},
    ),
    (
      'Arts Political Science',
      profile('Arts', 'Political Science'),
      {ssmu, 'aus', 'arts-pssa'},
    ),
    (
      'Science Physics',
      profile('Science', 'Physics'),
      {ssmu, 'sus', 'science-msps'},
    ),
    (
      'Arts and Science Cognitive Science',
      profile('Arts & Science', 'Cognitive Science'),
      {ssmu, 'arts-science-asus', 'arts-science-sacs'},
    ),
    (
      'Education Kinesiology variation',
      profile('Faculty of Education', 'Kinesiology'),
      {ssmu, 'education-edus', 'education-sapek'},
    ),
    (
      'Management undergraduate variation',
      profile('Desautels Faculty of Management', 'Finance'),
      {ssmu, 'desautels-mus'},
    ),
    (
      'Bioresource Engineering typed under Engineering',
      profile('Engineering', 'Bioresource Engineering', year: 'U0'),
      {},
    ),
    (
      'A faculty signup no longer offers',
      profile('Agricultural & Environmental Sciences', 'Animal Science'),
      {},
    ),
    (
      'Continuing Studies',
      profile(
        'School of Continuing Studies',
        null,
        degree: DegreeLevel.exchangeOrContinuing,
      ),
      {'mcgill-maces'},
    ),
    (
      'Exchange in another faculty',
      profile('Engineering', null, degree: DegreeLevel.exchangeOrContinuing),
      {},
    ),
    (
      'Graduate Nursing',
      profile(
        'Medicine & Health Sciences',
        'Nursing',
        degree: DegreeLevel.masters,
      ),
      {pgss, 'nursing-ngsa'},
    ),
    (
      'Graduate ECE',
      profile(
        'Faculty of Engineering',
        'Electrical & Computer Engineering',
        degree: DegreeLevel.doctorate,
      ),
      {pgss, 'engineering-eegss'},
    ),
    (
      'Undeclared Science freshman',
      profile('Faculty of Science', undeclaredMajor, year: 'U0'),
      {ssmu, 'sus', fyc, 'sus-fuss'},
    ),
    (
      'Environment in a downtown faculty',
      profile('Arts & Science', 'Environment'),
      {ssmu, 'arts-science-asus', 'science-mess'},
    ),
    (
      'Education',
      profile('Education', 'Secondary Education'),
      {ssmu, 'education-edus'},
    ),
    (
      'Medicine is also taught in Gatineau',
      profile('Medicine & Health Sciences', 'Medicine'),
      {'medicine-mss'},
    ),
    ('No substring matching', profile('Arts', 'Computer Engineering'), {'aus'}),
    (
      'Unknown faculty and program',
      profile('Unknown faculty', 'Unknown program'),
      {},
    ),
    (
      'Professional Medicine',
      profile(
        'Faculty of Medicine and Health Sciences',
        'MDCM',
        degree: DegreeLevel.professional,
      ),
      {'medicine-mss'},
    ),
    (
      'Professional Law',
      profile('Faculty of Law', 'BCL/JD', degree: DegreeLevel.professional),
      {'law-lsa'},
    ),
    (
      'Professional Dental',
      profile(
        'Faculty of Dental Medicine and Oral Health Sciences',
        'DMD',
        degree: DegreeLevel.professional,
      ),
      {'dentistry-dss'},
    ),
    (
      'Nursing undergraduate is not Medicine',
      profile('Medicine & Health Sciences', 'Nursing'),
      {ssmu, 'nursing-nus'},
    ),
  ];
  for (final (label, student, expected) in examples) {
    test(label, () => expect(academicAutoFollowIds(student), expected));
  }

  test(
    'all rules reference unique, verified representative catalog records',
    () {
      final ids = <String>{};
      for (final rule in academicFollowRules) {
        final club = clubsById[rule.organizationId];
        expect(club, isNotNull, reason: rule.organizationId);
        expect(
          club!.type,
          isNot(anyOf(OrganizationType.club, OrganizationType.designTeam)),
          reason: rule.organizationId,
        );
        expect(Uri.parse(rule.sourceUrl).scheme, 'https');
        expect(rule.rationale, isNotEmpty);
        ids.add(rule.organizationId);
      }
      expect(
        ids.length,
        academicFollowRules.length - 1,
        reason: 'MUGS has two separately sourced eligibility rules.',
      );
    },
  );

  test('matching defaults does not mutate follows or preferences', () {
    final input = profile('Engineering', 'Software Engineering');
    final edited = input.copyWith(followedClubIds: {'manual', ssmu});
    final selected = {
      ...edited.followedClubIds,
      ...academicAutoFollowIds(edited),
    };
    expect(selected, {'manual', ssmu, eus, ecsess});
    expect(edited.followedClubIds, {'manual', ssmu});
    expect(edited.clubAutoRsvpOptIns, isEmpty);
    expect(edited.clubNotificationOptIns, isEmpty);
  });

  test(
    'every curated program can be evaluated against verified catalog IDs',
    () {
      for (final entry in majorsByFaculty.entries) {
        for (final program in [...entry.value, undeclaredMajor]) {
          final ids = academicAutoFollowIds(profile(entry.key, program));
          expect(
            ids.every(clubsById.containsKey),
            isTrue,
            reason: '${entry.key}: $program',
          );
        }
      }
    },
  );

  test('signup offers nothing from Macdonald Campus', () {
    expect(
      majorsByFaculty.keys,
      isNot(contains('Agricultural & Environmental Sciences')),
    );
    expect(
      {for (final majors in majorsByFaculty.values) ...majors}.intersection({
        'Agricultural Economics',
        'Animal Science',
        'Bioresource Engineering',
        'Dietetics',
        'Environmental Biology',
        'Farm Management and Technology',
        'Food Science',
        'Global Food Security',
        'Nutrition',
        'Plant Science',
      }),
      isEmpty,
    );
    expect(
      {for (final rule in academicFollowRules) rule.organizationId}
          .intersection(macdonaldOrganizationIds),
      isEmpty,
    );
    // Every Macdonald society in the catalog is accounted for, and stays there
    // for students who already follow one.
    expect(clubsById.keys, containsAll(macdonaldOrganizationIds));
    expect(
      {
        for (final club in clubCatalog)
          if (club.sourceKeys.contains(31) || club.name.contains('Macdonald'))
            club.id,
      }.difference(macdonaldOrganizationIds),
      isEmpty,
    );
    expect(
      downtownClubCatalog.length,
      clubCatalog.length - macdonaldOrganizationIds.length,
    );
  });
}
