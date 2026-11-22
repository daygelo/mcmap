/// Downtown faculties and a selection of undergraduate majors in each.
/// Not exhaustive; edit freely.
const Map<String, List<String>> majorsByFaculty = {
  'Arts': [
    'Anthropology',
    'Art History',
    'Communication Studies',
    'Computer Science (Arts)',
    'Economics',
    'Environment',
    'Geography',
    'English Literature',
    'History',
    'International Development Studies',
    'Linguistics',
    'Philosophy',
    'Political Science',
    'Psychology (Arts)',
    'Sociology',
  ],
  'Arts & Science': [
    'Cognitive Science',
    'Environment',
    'Interfaculty Program',
    'Sustainability, Science and Society',
  ],
  'Education': [
    'Kindergarten & Elementary Education',
    'Kinesiology',
    'Music Education',
    'Physical & Health Education',
    'Secondary Education',
  ],
  'Engineering': [
    'Architecture',
    'Chemical Engineering',
    'Civil Engineering',
    'Computer Engineering',
    'Electrical Engineering',
    'Materials Engineering',
    'Mechanical Engineering',
    'Mining Engineering',
    'Software Engineering',
    'Urban Planning',
  ],
  'Law': ['BCL/JD'],
  'Desautels Management': [
    'Accounting',
    'Finance',
    'Information Systems',
    'Marketing',
    'Organizational Behaviour',
    'Retail Management',
  ],
  'Medicine & Health Sciences': [
    'Medicine',
    'Nursing',
    'Occupational Therapy',
    'Physical Therapy',
  ],
  'Dental Medicine & Oral Health Sciences': ['Dental Medicine'],
  'Continuing Studies': [
    'Certificate Program',
    'Diploma Program',
    'Language & Intercultural Studies',
    'Individual Courses',
  ],
  'Music': [
    'Composition',
    'Jazz Performance',
    'Music Technology',
    'Musicology',
    'Performance',
  ],
  'Science': [
    'Anatomy & Cell Biology',
    'Atmospheric and Oceanic Sciences',
    'Biochemistry',
    'Biology',
    'Chemistry',
    'Computer Science',
    'Earth & Planetary Sciences',
    'Earth System Science',
    'Environment',
    'Geography',
    'Mathematics',
    'Microbiology & Immunology',
    'Neuroscience',
    'Pharmacology',
    'Physics',
    'Physiology',
    'Psychology',
    'Statistics',
  ],
};

/// Shown first in every faculty's major list, mainly for U0 students who
/// haven't declared yet.
const undeclaredMajor = 'Undeclared / Freshman Program';

/// Degree levels offered at onboarding. Only undergraduates pick a U-year.
enum DegreeLevel {
  undergraduate('Undergraduate', 'Undergrad'),
  masters("Master's", "Master's"),
  doctorate('Doctorate (Ph.D.)', 'Ph.D.'),
  professional('Professional / Law / Medicine', 'Professional'),
  exchangeOrContinuing('Exchange / Continuing Studies', 'Exchange / Cont. Ed.');

  const DegreeLevel(this.label, this.shortLabel);

  final String label;

  /// Compact form used where a U-year would otherwise go (e.g. "Ph.D.").
  final String shortLabel;

  bool get hasUYear => this == undergraduate;

  /// Exchange and continuing-studies students often have no declared program.
  bool get requiresMajor => this != exchangeOrContinuing;
}

/// McGill undergraduate U-years.
const List<String> academicYears = ['U0', 'U1', 'U2', 'U3', 'U4+'];

/// Froshie = new to McGill: every U0, plus U1s in their first year (entering
/// from CEGEP or with AP/IB transfer credits). Drives the Froshie badge and
/// Frosh event recommendations.
bool isFroshieStanding(String? year, {required bool firstYearAtMcGill}) =>
    year == 'U0' || (year == 'U1' && firstYearAtMcGill);

/// Everything that can fill the "year" slot on a profile: a U-year for
/// undergrads, otherwise the degree level. Used by Edit Profile.
final List<String> academicStandings = [
  ...academicYears,
  for (final level in DegreeLevel.values)
    if (!level.hasUYear) level.shortLabel,
];
