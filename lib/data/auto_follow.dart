import '../models/user_profile.dart';
import 'academics.dart';

/// A group every matching student follows automatically when they finish
/// onboarding. These are the single source of truth: the offline demo uses
/// them directly, and tool/generate_seed.dart writes them into the
/// `auto_follow_rules` table that the Supabase trigger reads.
class AutoFollowRule {
  const AutoFollowRule(
    this.clubId, {
    this.faculties,
    this.degreeLevels,
    this.froshieOnly = false,
    this.enroll = false,
  });

  /// Catalog id, e.g. `mcgill-ssmu`.
  final String clubId;

  /// Null = any faculty.
  final Set<String>? faculties;

  /// Null = any degree level.
  final Set<DegreeLevel>? degreeLevels;

  /// First-Year Councils: only U0s and first-year U1s.
  final bool froshieOnly;

  /// Also adds a (private) club membership, for societies every student in
  /// that group belongs to (campus society, faculty association). Councils
  /// are elected, so they're followed only.
  final bool enroll;

  bool appliesTo(UserProfile p) =>
      (faculties == null || faculties!.contains(p.faculty)) &&
      (degreeLevels == null || degreeLevels!.contains(p.degreeLevel)) &&
      (!froshieOnly || p.isFroshie);
}

/// Campus societies: what each student is a member of by default.
const campusSocietyIds = {
  'mcgill-ssmu',
  'mcgill-mcss',
  'mcgill-maces',
  'mcgill-pgss',
};

/// Undergraduate faculty associations.
const facultyAssociationIds = {
  'mcgill-aus',
  'mcgill-basic',
  'mcgill-sus',
  'engineering-engineering-undergraduate-society-eus',
  'desautels-mus',
  'mcgill-edus',
  'mcgill-lsa',
  'mcgill-musa',
};

/// Faculty → First-Year Council (or first-year committee).
const firstYearCouncilByFaculty = {
  'Arts': 'aus-fearc',
  'Science': 'sus-fuss',
  'Engineering': 'eus-junior-council',
  'Desautels Management': 'mus-first-year-involvement-team',
  'Education': 'edus-fyre',
};

const _macdonald = 'Agricultural & Environmental Sciences';
const _continuing = 'Continuing Studies';

/// Downtown faculties: SSMU members (Macdonald campus has MCSS instead,
/// Continuing Studies has MACES).
final _ssmuFaculties = {
  for (final faculty in majorsByFaculty.keys)
    if (faculty != _macdonald && faculty != _continuing) faculty,
};

const _undergradLike = {
  DegreeLevel.undergraduate,
  DegreeLevel.professional,
  DegreeLevel.exchangeOrContinuing,
};

final autoFollowRules = <AutoFollowRule>[
  // Campus society.
  AutoFollowRule(
    'mcgill-ssmu',
    faculties: _ssmuFaculties,
    degreeLevels: _undergradLike,
    enroll: true,
  ),
  const AutoFollowRule(
    'mcgill-mcss',
    faculties: {_macdonald},
    degreeLevels: _undergradLike,
    enroll: true,
  ),
  const AutoFollowRule('mcgill-maces', faculties: {_continuing}, enroll: true),
  const AutoFollowRule(
    'mcgill-pgss',
    degreeLevels: {DegreeLevel.masters, DegreeLevel.doctorate},
    enroll: true,
  ),

  // Faculty association (undergrads; Law includes the professional BCL/JD).
  for (final (faculty, id) in [
    ('Arts', 'mcgill-aus'),
    ('Arts & Science', 'mcgill-basic'),
    ('Science', 'mcgill-sus'),
    ('Engineering', 'engineering-engineering-undergraduate-society-eus'),
    ('Desautels Management', 'desautels-mus'),
    ('Education', 'mcgill-edus'),
    ('Music', 'mcgill-musa'),
  ])
    AutoFollowRule(
      id,
      faculties: {faculty},
      degreeLevels: const {DegreeLevel.undergraduate},
      enroll: true,
    ),
  const AutoFollowRule(
    'mcgill-lsa',
    faculties: {'Law'},
    degreeLevels: {DegreeLevel.undergraduate, DegreeLevel.professional},
    enroll: true,
  ),

  // First-Year Councils: SSMU's campus-wide one plus the faculty's own.
  AutoFollowRule(
    'ssmu-first-year-council',
    faculties: _ssmuFaculties,
    froshieOnly: true,
  ),
  for (final MapEntry(key: faculty, value: id)
      in firstYearCouncilByFaculty.entries)
    AutoFollowRule(id, faculties: {faculty}, froshieOnly: true),
];

/// Adds the automatic follows (and memberships) to a freshly onboarded
/// profile. Existing choices are kept.
UserProfile applyAutoFollows(UserProfile profile) {
  final rules = autoFollowRules.where((r) => r.appliesTo(profile));
  return profile.copyWith(
    followedClubIds: {
      ...profile.followedClubIds,
      for (final rule in rules) rule.clubId,
    },
    memberships: {
      for (final rule in rules)
        if (rule.enroll) rule.clubId: const ClubMembership(),
      ...profile.memberships,
    },
  );
}

/// The groups whose events lead "Suggested events" on Home: the student's
/// campus society (SSMU, or PGSS for grad students), faculty association
/// and, for Froshies, First-Year Councils. Same groups as the automatic
/// follows, so it still works for students who unfollowed them.
Set<String> priorityClubIdsFor(UserProfile profile) => {
  for (final rule in autoFollowRules)
    if (rule.appliesTo(profile)) rule.clubId,
};
