import '../models/user_profile.dart';
import 'academics.dart';
import 'club_catalog_data.dart';

const _undergrad = {DegreeLevel.undergraduate};
const _graduate = {DegreeLevel.masters, DegreeLevel.doctorate};
const _professional = {DegreeLevel.undergraduate, DegreeLevel.professional};

const _aes = 'Agricultural & Environmental Sciences';
const _arts = 'Arts';
const _artsScience = 'Arts & Science';
const _education = 'Education';
const _engineering = 'Engineering';
const _health = 'Medicine & Health Sciences';
const _management = 'Desautels Management';
const _music = 'Music';
const _science = 'Science';
const _continuing = 'Continuing Studies';
const _dental = 'Dental Medicine & Oral Health Sciences';
const _computingFaculties = {_science, _arts, _artsScience};
const _computerScience = {
  'Computer Science',
  'Computer Science (Arts)',
  'Computing Science',
};
const _ecse = {
  'Software Engineering',
  'Electrical Engineering',
  'Computer Engineering',
};
const _spot = {'Physical Therapy', 'Occupational Therapy', 'Physiotherapy'};
const _macSpecific = {_bioresource, _dhn, _foodScience, _fmt};
const _bioresource = {
  'Bioresource Engineering',
  'Biological Engineering (Bioresource Engineering)',
};
const _dhn = {
  'Dietetics',
  'Human Nutrition',
  'Nutrition',
  'Dietetics and Human Nutrition',
};
const _foodScience = {'Food Science', 'Food Science and Nutritional Sciences'};
const _fmt = {
  'Farm Management and Technology',
  'Farm Management & Technology',
  'FMT',
};
const _aesGeneral = {
  'Agricultural Economics',
  'Animal Science',
  'Environmental Biology',
  'Global Food Security',
  'Plant Science',
  'Agro-Environmental Sciences',
  'Agricultural and Environmental Sciences',
  'Life Sciences (Biological and Agricultural)',
  undeclaredMajor,
};

/// A representative association, with exact normalized academic eligibility.
class AcademicFollowRule {
  const AcademicFollowRule(
    this.organizationId,
    this.sourceKey,
    this.rationale, {
    this.degrees = _undergrad,
    this.faculties = const {},
    this.programs = const {},
    this.excludedPrograms = const {},
    this.campus,
    this.firstYearOnly = false,
  });

  final String organizationId;
  final int sourceKey;
  final String rationale;
  final Set<DegreeLevel> degrees;
  final Set<String> faculties;
  final Set<String> programs;
  final Set<String> excludedPrograms;
  final AcademicCampus? campus;
  final bool firstYearOnly;

  String get sourceUrl => clubCatalogSources[sourceKey]!.$2;
}

const academicFollowRules = <AcademicFollowRule>[
  AcademicFollowRule(
    'mcgill-ssmu',
    11,
    'Downtown undergraduate student society.',
    campus: AcademicCampus.downtown,
  ),
  AcademicFollowRule(
    'mcgill-mcss',
    11,
    'Macdonald undergraduate student society.',
    campus: AcademicCampus.macdonald,
  ),
  AcademicFollowRule(
    'mcgill-pgss',
    33,
    'University-wide graduate student representation.',
    degrees: _graduate,
  ),
  AcademicFollowRule(
    'mcgill-mcgss',
    11,
    'Additional representation for Macdonald graduate students.',
    degrees: _graduate,
    campus: AcademicCampus.macdonald,
  ),
  AcademicFollowRule(
    'mcgill-maces',
    11,
    'School of Continuing Studies representation.',
    degrees: {
      DegreeLevel.exchangeOrContinuing,
      DegreeLevel.undergraduate,
      DegreeLevel.professional,
    },
    faculties: {_continuing},
  ),

  AcademicFollowRule(
    'engineering-engineering-undergraduate-society-eus',
    12,
    'Engineering undergraduate faculty society.',
    faculties: {_engineering},
    excludedPrograms: _bioresource,
  ),
  AcademicFollowRule(
    'engineering-electrical-computer-software-engineering-student-society-ecsess',
    12,
    'Represents the three ECSE engineering programs.',
    faculties: {_engineering},
    programs: _ecse,
  ),
  AcademicFollowRule(
    'engineering-mcgill-association-of-mechanical-engineers-mame',
    12,
    'Mechanical Engineering representation.',
    faculties: {_engineering},
    programs: {'Mechanical Engineering'},
  ),
  AcademicFollowRule(
    'engineering-chemical-engineering-students-society-chess',
    12,
    'Chemical Engineering representation.',
    faculties: {_engineering},
    programs: {'Chemical Engineering'},
  ),
  AcademicFollowRule(
    'engineering-civil-engineering-undergraduate-society-ceus',
    12,
    'Civil Engineering representation.',
    faculties: {_engineering},
    programs: {'Civil Engineering'},
  ),
  AcademicFollowRule(
    'engineering-materials-engineering-undergraduate-society-meus',
    12,
    'Materials Engineering representation.',
    faculties: {_engineering},
    programs: {
      'Materials Engineering',
      'Materials and Metallurgical Engineering',
    },
  ),
  AcademicFollowRule(
    'engineering-co-op-mining-engineering-undergraduate-society',
    12,
    'Mining Engineering undergraduate representation.',
    faculties: {_engineering},
    programs: {
      'Mining Engineering',
      'Co-op Mining Engineering',
      'Mining Engineering Co-op',
    },
  ),
  AcademicFollowRule(
    'engineering-bioengineering-undergraduate-students-society-buss',
    12,
    'Bioengineering undergraduate representation.',
    faculties: {_engineering},
    programs: {'Bioengineering', 'Bioengineering (BEng)'},
  ),
  AcademicFollowRule(
    'engineering-architecture-students-society-asa',
    12,
    'Undergraduate architecture representation.',
    faculties: {_engineering},
    programs: {'Architecture', 'Architecture (BSc)'},
  ),
  AcademicFollowRule(
    'engineering-eegss',
    34,
    'Electrical and Computer Engineering graduate representation.',
    degrees: _graduate,
    faculties: {_engineering},
    programs: {
      'Electrical and Computer Engineering',
      'Electrical Engineering',
      'Computer Engineering',
      'ECE',
    },
  ),
  AcademicFollowRule(
    'engineering-chegss',
    38,
    'Chemical Engineering graduate representation.',
    degrees: _graduate,
    faculties: {_engineering},
    programs: {'Chemical Engineering'},
  ),
  AcademicFollowRule(
    'engineering-games',
    38,
    'Mechanical Engineering graduate representation.',
    degrees: _graduate,
    faculties: {_engineering},
    programs: {'Mechanical Engineering'},
  ),
  AcademicFollowRule(
    'engineering-mmgesa',
    38,
    'Mining and Materials Engineering graduate representation.',
    degrees: _graduate,
    faculties: {_engineering},
    programs: {
      'Mining and Materials Engineering',
      'Mining Engineering',
      'Materials Engineering',
    },
  ),

  AcademicFollowRule(
    'sus',
    28,
    'Science undergraduate faculty society.',
    faculties: {_science},
  ),
  AcademicFollowRule(
    'science-csus',
    18,
    'Computer Science representation across eligible faculties.',
    faculties: _computingFaculties,
    programs: _computerScience,
  ),
  AcademicFollowRule(
    'science-mbsu',
    18,
    'Biology undergraduate representation.',
    faculties: {_science},
    programs: {'Biology'},
  ),
  AcademicFollowRule(
    'science-bugs',
    18,
    'Biochemistry undergraduate representation.',
    faculties: {_science},
    programs: {'Biochemistry'},
  ),
  AcademicFollowRule(
    'science-cuss',
    18,
    'Chemistry undergraduate representation.',
    faculties: {_science},
    programs: {'Chemistry'},
  ),
  AcademicFollowRule(
    'science-mpsa',
    18,
    'Psychology undergraduate representation in Arts and Science.',
    faculties: _computingFaculties,
    programs: {'Psychology', 'Psychology (Arts)'},
  ),
  AcademicFollowRule(
    'science-msps',
    18,
    'Physics undergraduate representation.',
    faculties: {_science},
    programs: {'Physics'},
  ),
  AcademicFollowRule(
    'science-sums',
    18,
    'Mathematics and Statistics undergraduate representation.',
    faculties: {_science, _arts},
    programs: {'Mathematics', 'Statistics', 'Mathematics and Statistics'},
  ),
  AcademicFollowRule(
    'science-misa',
    18,
    'Microbiology and Immunology undergraduate representation.',
    faculties: {_science},
    programs: {'Microbiology & Immunology'},
  ),
  AcademicFollowRule(
    'science-num',
    18,
    'Neuroscience undergraduate representation.',
    faculties: {_science},
    programs: {'Neuroscience'},
  ),
  AcademicFollowRule(
    'science-puls',
    18,
    'Physiology undergraduate representation.',
    faculties: {_science},
    programs: {'Physiology'},
  ),
  AcademicFollowRule(
    'science-pils',
    18,
    'Pharmacology undergraduate representation.',
    faculties: {_science},
    programs: {'Pharmacology'},
  ),
  AcademicFollowRule(
    'science-macss',
    18,
    'Anatomy and Cell Biology undergraduate representation.',
    faculties: {_science},
    programs: {'Anatomy & Cell Biology'},
  ),
  AcademicFollowRule(
    'science-monty',
    39,
    'Earth and Planetary Sciences and Earth System Science representation.',
    faculties: {_science},
    programs: {'Earth & Planetary Sciences', 'Earth System Science'},
  ),
  AcademicFollowRule(
    'science-mess',
    18,
    'Environment program representation.',
    faculties: {_science, _arts, _artsScience},
    programs: {'Environment', 'Bieler School of Environment'},
  ),
  AcademicFollowRule(
    'science-aossum',
    18,
    'Atmospheric and Oceanic Sciences representation.',
    faculties: {_science},
    programs: {
      'Atmospheric Science',
      'Atmospheric Sciences',
      'Atmospheric and Oceanic Sciences',
      'Earth System Science',
    },
  ),
  AcademicFollowRule(
    'science-mugs',
    39,
    'Geography and Earth System Science representation.',
    faculties: {_science, _arts},
    programs: {'Geography', 'Earth System Science'},
  ),

  AcademicFollowRule(
    'aus',
    28,
    'Arts undergraduate faculty society.',
    faculties: {_arts},
  ),
  AcademicFollowRule(
    'arts-anthropology-asa',
    29,
    'Anthropology undergraduate representation.',
    faculties: {_arts},
    programs: {'Anthropology'},
  ),
  AcademicFollowRule(
    'arts-ahcssa',
    29,
    'Art History and Communication Studies representation.',
    faculties: {_arts},
    programs: {
      'Art History',
      'Communication Studies',
      'Art History and Communication Studies',
    },
  ),
  AcademicFollowRule(
    'arts-esa',
    29,
    'Economics undergraduate representation.',
    faculties: {_arts},
    programs: {'Economics'},
  ),
  AcademicFollowRule(
    'arts-desa',
    40,
    'Department of English undergraduate representation.',
    faculties: {_arts},
    programs: {
      'English',
      'English Literature',
      'English: Literature',
      'English: Cultural Studies',
      'English: Drama & Theatre',
    },
  ),
  AcademicFollowRule(
    'arts-hsa',
    29,
    'History undergraduate representation.',
    faculties: {_arts},
    programs: {'History'},
  ),
  AcademicFollowRule(
    'arts-idssa',
    29,
    'International Development Studies representation.',
    faculties: {_arts},
    programs: {
      'International Development Studies',
      'International Development',
    },
  ),
  AcademicFollowRule(
    'arts-lingua',
    29,
    'Linguistics undergraduate representation.',
    faculties: {_arts},
    programs: {'Linguistics'},
  ),
  AcademicFollowRule(
    'arts-psa',
    29,
    'Philosophy undergraduate representation.',
    faculties: {_arts},
    programs: {'Philosophy'},
  ),
  AcademicFollowRule(
    'arts-pssa',
    29,
    'Political Science undergraduate representation.',
    faculties: {_arts},
    programs: {'Political Science'},
  ),
  AcademicFollowRule(
    'arts-sociology-ssa',
    29,
    'Sociology undergraduate representation.',
    faculties: {_arts},
    programs: {'Sociology'},
  ),
  AcademicFollowRule(
    'arts-egsa',
    41,
    'Department of English graduate representation.',
    degrees: _graduate,
    faculties: {_arts},
    programs: {'English', 'English Literature'},
  ),

  AcademicFollowRule(
    'arts-agelf',
    29,
    'Represents students in the named academic program.',
    faculties: {_arts},
    programs: {
      'French Language and Literature',
      'Langue et littérature françaises',
    },
  ),
  AcademicFollowRule(
    'arts-assa',
    29,
    'Represents students in the named academic program.',
    faculties: {_arts},
    programs: {'African Studies'},
  ),
  AcademicFollowRule(
    'arts-clashsa',
    29,
    'Represents students in the named academic program.',
    faculties: {_arts},
    programs: {
      'Caribbean Studies',
      'Latin American Studies',
      'Latin American and Caribbean Studies',
      'Hispanic Studies',
    },
  ),
  AcademicFollowRule(
    'arts-csa',
    29,
    'Represents students in the named academic program.',
    faculties: {_arts},
    programs: {'Classics', 'Classical Studies'},
  ),
  AcademicFollowRule(
    'arts-csaus',
    29,
    'Represents students in the named academic program.',
    faculties: {_arts},
    programs: {'Canadian Studies'},
  ),
  AcademicFollowRule(
    'arts-eassa',
    29,
    'Represents students in the named academic program.',
    faculties: {_arts},
    programs: {'East Asian Studies'},
  ),
  AcademicFollowRule(
    'arts-gsa',
    29,
    'Represents students in the named academic program.',
    faculties: {_arts},
    programs: {'German Studies'},
  ),
  AcademicFollowRule(
    'arts-gsfssa',
    29,
    'Represents students in the named academic program.',
    faculties: {_arts},
    programs: {'Gender, Sexuality, Feminist, and Social Justice Studies'},
  ),
  AcademicFollowRule(
    'arts-issa',
    29,
    'Represents students in the named academic program.',
    faculties: {_arts},
    programs: {'Italian Studies'},
  ),
  AcademicFollowRule(
    'arts-jssa',
    29,
    'Represents students in the named academic program.',
    faculties: {_arts},
    programs: {'Jewish Studies'},
  ),
  AcademicFollowRule(
    'arts-lapsa',
    29,
    'Represents students in the named academic program.',
    faculties: {_arts},
    programs: {'Liberal Arts'},
  ),
  AcademicFollowRule(
    'arts-mira',
    29,
    'Represents students in the named academic program.',
    faculties: {_arts},
    programs: {'Industrial Relations'},
  ),
  AcademicFollowRule(
    'arts-rsus',
    29,
    'Represents students in the named academic program.',
    faculties: {_arts},
    programs: {'Religious Studies'},
  ),
  AcademicFollowRule(
    'arts-russ',
    29,
    'Represents students in the named academic program.',
    faculties: {_arts},
    programs: {'Russian', 'Russian Studies'},
  ),
  AcademicFollowRule(
    'arts-sassa',
    29,
    'Represents students in the named academic program.',
    faculties: {_arts},
    programs: {'South Asian Studies'},
  ),
  AcademicFollowRule(
    'arts-qssa',
    29,
    'Represents students in the named academic program.',
    faculties: {_arts},
    programs: {'Québec Studies', 'Quebec Studies'},
  ),
  AcademicFollowRule(
    'arts-wimessa',
    29,
    'Represents students in the named academic program.',
    faculties: {_arts},
    programs: {'World Islamic and Middle East Studies'},
  ),
  AcademicFollowRule(
    'engineering-gasa',
    44,
    'Represents students in the named academic program.',
    degrees: _graduate,
    faculties: {_engineering},
    programs: {'Architecture', 'Master of Architecture', 'MArch'},
  ),
  AcademicFollowRule(
    'engineering-oups',
    45,
    'Represents students in the named academic program.',
    degrees: _graduate,
    faculties: {_engineering},
    programs: {'Urban Planning', 'Master of Urban Planning', 'MUP'},
  ),
  AcademicFollowRule(
    'arts-mgapss',
    45,
    'Represents students in the named academic program.',
    degrees: _graduate,
    faculties: {_arts},
    programs: {'Political Science'},
  ),
  AcademicFollowRule(
    'arts-science-asus',
    42,
    'Arts and Science faculty representation.',
    faculties: {_artsScience},
  ),
  AcademicFollowRule(
    'arts-science-sacs',
    36,
    'Cognitive Science undergraduate representation.',
    faculties: {_artsScience},
    programs: {'Cognitive Science'},
  ),
  AcademicFollowRule(
    'arts-science-sasss',
    42,
    'Sustainability, Science and Society program representation.',
    faculties: {_artsScience},
    programs: {'Sustainability, Science and Society'},
  ),
  AcademicFollowRule(
    'science-mugs',
    42,
    'Sustainability, Science and Society students also belong to MUGS.',
    faculties: {_artsScience},
    programs: {'Sustainability, Science and Society'},
  ),

  AcademicFollowRule(
    'education-edus',
    30,
    'Education undergraduate faculty society.',
    faculties: {_education},
  ),
  AcademicFollowRule(
    'education-sapek',
    30,
    'Kinesiology and Physical Education representation.',
    faculties: {_education},
    programs: {
      'Kinesiology',
      'Physical Education',
      'Physical & Health Education',
    },
  ),
  AcademicFollowRule(
    'education-medusa',
    30,
    'Music Education undergraduate representation.',
    faculties: {_education, _music},
    programs: {'Music Education', 'Concurrent Music and Education'},
  ),
  AcademicFollowRule(
    'education-egss',
    30,
    'Education graduate faculty society.',
    degrees: _graduate,
    faculties: {_education},
  ),
  AcademicFollowRule(
    'desautels-mus',
    13,
    'BCom undergraduate faculty society.',
    faculties: {_management},
  ),
  AcademicFollowRule(
    'law-lsa',
    28,
    'McGill Law first-degree representation.',
    degrees: _professional,
    faculties: {'Law'},
    programs: {
      'BCL/JD',
      'BCL/LLB',
      'Law',
      'Bachelor of Civil Law and Juris Doctor',
    },
  ),
  AcademicFollowRule(
    'music-musa',
    28,
    'Schulich undergraduate faculty society.',
    faculties: {_music},
  ),
  AcademicFollowRule(
    'music-mgss',
    35,
    'Schulich graduate faculty society.',
    degrees: _graduate,
    faculties: {_music},
  ),
  AcademicFollowRule(
    'medicine-mss',
    28,
    'Medical student representation for Medicine and MDCM.',
    degrees: _professional,
    faculties: {_health},
    programs: {'Medicine', 'MDCM', 'Doctor of Medicine and Master of Surgery'},
  ),
  AcademicFollowRule(
    'nursing-nus',
    32,
    'Ingram School undergraduate Nursing representation.',
    faculties: {_health},
    programs: {'Nursing', 'BScN', 'BNI'},
  ),
  AcademicFollowRule(
    'nursing-ngsa',
    32,
    'Ingram School graduate Nursing representation.',
    degrees: _graduate,
    faculties: {_health},
    programs: {'Nursing', 'Nursing Science', 'Direct Entry Nursing'},
  ),
  AcademicFollowRule(
    'spot-potus',
    37,
    'Physical and Occupational Therapy undergraduate representation.',
    faculties: {_health},
    programs: _spot,
  ),
  AcademicFollowRule(
    'spot-gsa',
    37,
    'Physical and Occupational Therapy professional master’s representation.',
    degrees: {DegreeLevel.masters},
    faculties: {_health},
    programs: _spot,
  ),
  AcademicFollowRule(
    'dentistry-dss',
    28,
    'Dental Medicine first-degree representation.',
    degrees: _professional,
    faculties: {_dental},
    programs: {'Dental Medicine', 'Dentistry', 'DMD'},
  ),

  AcademicFollowRule(
    'macdonald-aesus',
    31,
    'General Agricultural and Environmental Sciences undergraduate representation.',
    faculties: {_aes},
    programs: _aesGeneral,
    campus: AcademicCampus.macdonald,
  ),
  AcademicFollowRule(
    'engineering-bioresource-engineering-students-society-bess',
    31,
    'Macdonald Bioresource Engineering undergraduate representation.',
    faculties: {_aes, _engineering},
    programs: _bioresource,
    campus: AcademicCampus.macdonald,
  ),
  AcademicFollowRule(
    'macdonald-dhnus',
    31,
    'Macdonald Dietetics and Human Nutrition representation.',
    faculties: {_aes},
    programs: _dhn,
    campus: AcademicCampus.macdonald,
  ),
  AcademicFollowRule(
    'macdonald-fsa',
    31,
    'Macdonald Food Science undergraduate representation.',
    faculties: {_aes},
    programs: _foodScience,
    campus: AcademicCampus.macdonald,
  ),
  AcademicFollowRule(
    'macdonald-fmt',
    31,
    'Macdonald Farm Management and Technology representation.',
    faculties: {_aes},
    programs: _fmt,
    campus: AcademicCampus.macdonald,
  ),

  AcademicFollowRule(
    'ssmu-first-year-council',
    46,
    'First-year undergraduate representation at SSMU.',
    campus: AcademicCampus.downtown,
    firstYearOnly: true,
  ),
  AcademicFollowRule(
    'eus-junior-council',
    16,
    'First-year Engineering representation.',
    faculties: {_engineering},
    excludedPrograms: _bioresource,
    firstYearOnly: true,
  ),
  AcademicFollowRule(
    'ecsess-bits',
    20,
    'First-year ECSE representation.',
    faculties: {_engineering},
    programs: _ecse,
    firstYearOnly: true,
  ),
  AcademicFollowRule(
    'csus-first-year-council',
    19,
    'Community for new Computer Science students.',
    faculties: _computingFaculties,
    programs: _computerScience,
    firstYearOnly: true,
  ),
  AcademicFollowRule(
    'buss-first-year-council',
    21,
    'First-year Bioengineering representation.',
    faculties: {_engineering},
    programs: {'Bioengineering', 'Bioengineering (BEng)'},
    firstYearOnly: true,
  ),
  AcademicFollowRule(
    'mame-first-year-council',
    22,
    'First-year Mechanical Engineering representation.',
    faculties: {_engineering},
    programs: {'Mechanical Engineering'},
    firstYearOnly: true,
  ),
  AcademicFollowRule(
    'sus-fuss',
    18,
    'First-year Science representation.',
    faculties: {_science},
    firstYearOnly: true,
  ),
  AcademicFollowRule(
    'aus-fearc',
    17,
    'First-year Arts representation for U0 and new U1.',
    faculties: {_arts},
    firstYearOnly: true,
  ),
  AcademicFollowRule(
    'edus-fyre',
    24,
    'First-year Education representation for U0 and new U1.',
    faculties: {_education},
    firstYearOnly: true,
  ),
  AcademicFollowRule(
    'mus-first-year-involvement-team',
    23,
    'First-year Management programming.',
    faculties: {_management},
    firstYearOnly: true,
  ),
  AcademicFollowRule(
    'pssa-first-year-council',
    25,
    'First-year Political Science programming.',
    faculties: {_arts},
    programs: {'Political Science'},
    firstYearOnly: true,
  ),
];

String _normalize(String text) => text
    .toLowerCase()
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c')
    .replaceAll('&', ' and ')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

String _facultyKey(String input) {
  final key = _normalize(input).replaceFirst(RegExp(r'^faculty of '), '');
  return switch (key) {
    'desautels faculty of management' ||
    'management' ||
    'desautels' => _normalize(_management),
    'schulich school of music' || 'schulich' => _normalize(_music),
    'school of continuing studies' => _normalize(_continuing),
    'ingram school of nursing' => _normalize(_health),
    'dental medicine' || 'dentistry' => _normalize(_dental),
    _ => key,
  };
}

bool _includes(Set<String> values, String key) =>
    values.isEmpty || values.any((value) => _normalize(value) == key);

AcademicCampus? _campusFor(
  UserProfile profile,
  String faculty,
  String program,
) {
  if (profile.campus != null) return profile.campus;
  if (faculty == _normalize(_aes) &&
      (_includes(_aesGeneral, program) ||
          _macSpecific.any((programs) => _includes(programs, program)))) {
    return AcademicCampus.macdonald;
  }
  if (faculty == _normalize(_engineering) && _includes(_bioresource, program)) {
    return AcademicCampus.macdonald;
  }
  // Shared and satellite programs need an explicit campus. Unknown faculty
  // and program values never default to Downtown.
  if (const {
    'environment',
    'bieler school of environment',
    'medicine',
    'mdcm',
    'doctor of medicine and master of surgery',
    'interfaculty program',
  }.contains(program)) {
    return null;
  }
  const downtown = {
    _arts,
    _artsScience,
    _engineering,
    _management,
    _music,
    _science,
    _dental,
    'Law',
  };
  if (downtown.any((name) => _normalize(name) == faculty) &&
      majorsByFaculty.entries.any(
        (entry) =>
            _normalize(entry.key) == faculty &&
            (_includes(entry.value.toSet(), program) ||
                program == _normalize(undeclaredMajor) ||
                academicFollowRules.any(
                  (rule) =>
                      rule.programs.isNotEmpty &&
                      _includes(rule.faculties, faculty) &&
                      _includes(rule.programs, program),
                )),
      )) {
    return AcademicCampus.downtown;
  }
  // These programs are explicitly Downtown rather than relying on their
  // multi-campus faculty as a whole.
  if ((faculty == _normalize(_education) &&
          _includes({
            'Kinesiology',
            'Physical & Health Education',
            'Music Education',
          }, program)) ||
      (faculty == _normalize(_health) &&
          _includes({'Nursing', ..._spot}, program))) {
    return AcademicCampus.downtown;
  }
  return null;
}

/// Defaults are evaluated only while reviewing onboarding selections.
Set<String> academicAutoFollowIds(UserProfile profile) {
  final program = _normalize(profile.major ?? '');
  final faculty = _facultyKey(profile.faculty);
  final campus = faculty == _normalize(_continuing)
      ? null
      : _campusFor(profile, faculty, program);
  return {
    for (final rule in academicFollowRules)
      if (rule.degrees.contains(profile.degreeLevel) &&
          (rule.campus == null || rule.campus == campus) &&
          _includes(rule.faculties, faculty) &&
          _includes(rule.programs, program) &&
          (!rule.firstYearOnly || profile.isFroshie) &&
          (rule.excludedPrograms.isEmpty ||
              !_includes(rule.excludedPrograms, program)))
        rule.organizationId,
  };
}
