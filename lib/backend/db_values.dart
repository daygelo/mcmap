// App ↔ database value mapping. Plain Dart (no Flutter), so
// tool/generate_seed.dart can use it too.

import '../data/academics.dart';
import '../models/student_visibility.dart';

// ---------------------------------------------------------------------------

const degreeLevelDbValues = {
  DegreeLevel.undergraduate: 'undergraduate',
  DegreeLevel.masters: 'masters',
  DegreeLevel.doctorate: 'doctorate',
  DegreeLevel.professional: 'professional',
  DegreeLevel.exchangeOrContinuing: 'exchange_continuing',
};

DegreeLevel? degreeLevelFromDb(Object? value) => degreeLevelDbValues.entries
    .where((e) => e.value == value)
    .map((e) => e.key)
    .firstOrNull;

/// 'U4+' ↔ 'U4_plus'; other U-years are the same.
String? uYearToDb(String? year) => year == 'U4+' ? 'U4_plus' : year;
String? uYearFromDb(Object? value) =>
    value == 'U4_plus' ? 'U4+' : value as String?;

/// Edit Profile's single "Year / degree level" value → (degree, U-year).
(DegreeLevel, String?) standingToDb(String standing) {
  if (academicYears.contains(standing)) {
    return (DegreeLevel.undergraduate, standing);
  }
  final level = DegreeLevel.values.firstWhere(
    (l) => l.shortLabel == standing,
    orElse: () => DegreeLevel.undergraduate,
  );
  return (level, level.hasUYear ? 'U0' : null);
}

String visibilityToDb(StudentVisibility v) => v.name;
StudentVisibility visibilityFromDb(Object? value) =>
    StudentVisibility.values.firstWhere(
      (v) => v.name == value,
      orElse: () => StudentVisibility.private,
    );
