import 'club_catalog_data.dart';

/// What kind of organization a group is. [dbValue] is `groups.type`.
enum OrganizationType {
  club('Club', 'club'),
  designTeam('Design Team', 'design_team'),
  studentSociety('Society', 'society'),
  campusSociety('Campus Society', 'campus_society'),
  facultyAssociation('Faculty Association', 'faculty_association'),
  researchGroup('Research Group', 'research_group'),
  firstYearCouncil('First-Year Council', 'first_year_council'),
  firstYearCommittee('First-Year Committee', 'first_year_committee'),
  firstYearSociety('First-Year Society', 'first_year_society'),
  studentAssociation('Student Association', 'student_association'),
  facultyAffiliation('Faculty Association', 'faculty_affiliation'),
  faculty('Faculty', 'faculty');

  const OrganizationType(this.label, this.dbValue);
  final String label;
  final String dbValue;

  static OrganizationType? fromDb(Object? value) =>
      values.where((type) => type.dbValue == value).firstOrNull;
}

/// Quick filters for browsing organizations.
enum OrganizationFilter {
  all('All', {}),
  clubs('Clubs', {OrganizationType.club, OrganizationType.designTeam}),
  societies('Societies', {
    OrganizationType.studentSociety,
    OrganizationType.campusSociety,
    OrganizationType.studentAssociation,
  }),
  research('Research Groups', {OrganizationType.researchGroup}),
  faculty('Faculty Associations', {
    OrganizationType.facultyAssociation,
    OrganizationType.facultyAffiliation,
    OrganizationType.faculty,
  }),
  firstYear('First-Year', {
    OrganizationType.firstYearCouncil,
    OrganizationType.firstYearCommittee,
    OrganizationType.firstYearSociety,
  });

  const OrganizationFilter(this.label, this.types);
  final String label;
  final Set<OrganizationType> types;

  bool matches(OrganizationType? type) => this == all || types.contains(type);
}

/// 0 exact, 1 a word starts with the query, 2 contained anywhere, null none.
/// Inputs must already be normalized.
int? organizationSearchRank(Iterable<String> terms, String query) {
  int? best;
  for (final term in terms) {
    final rank = term == query
        ? 0
        : term.startsWith(query) || term.contains(' $query')
        ? 1
        : term.contains(query)
        ? 2
        : null;
    if (rank != null && (best == null || rank < best)) best = rank;
  }
  return best;
}

class ClubOrganization {
  ClubOrganization._(List<String> fields)
    : id = fields[0],
      name = fields[1],
      sourceKeys = List.unmodifiable(fields[2].split(',').map(int.parse)),
      type = OrganizationType.values.byName(fields[3]),
      aliases = List.unmodifiable(fields.skip(4)),
      _searchTerms = [
        fields[1],
        ...fields.skip(4),
      ].map(normalizeClubSearch).toList(growable: false);

  final String id;
  final String name;
  final List<int> sourceKeys;
  final OrganizationType type;
  final List<String> aliases;
  final List<String> _searchTerms;

  String get category => clubCatalogSources[sourceKeys.first]!.$1;
  Iterable<String> get sourceUrls =>
      sourceKeys.map((key) => clubCatalogSources[key]!.$2);

  int? searchRank(String normalizedQuery) =>
      organizationSearchRank(_searchTerms, normalizedQuery);

  bool matches(String normalizedQuery) =>
      _searchTerms.any((term) => term.contains(normalizedQuery));
}

final clubCatalog = List<ClubOrganization>.unmodifiable(
  clubCatalogRows
      .trim()
      .split('\n')
      .map((row) => ClubOrganization._(row.split('|'))),
);

/// Macdonald Campus societies. They stay searchable for students who follow
/// them, but signup and suggestions only offer downtown organizations.
const macdonaldOrganizationIds = {
  'engineering-bioresource-engineering-students-society-bess',
  'macdonald-aesus',
  'macdonald-dhnus',
  'macdonald-fmt',
  'macdonald-fsa',
  'mcgill-mcgss',
  'mcgill-mcss',
};

/// What signup and suggestions offer.
final downtownClubCatalog = List<ClubOrganization>.unmodifiable(
  clubCatalog.where((club) => !macdonaldOrganizationIds.contains(club.id)),
);

final clubsById = Map<String, ClubOrganization>.unmodifiable({
  for (final club in clubCatalog) club.id: club,
});

/// Exact name and alias matches come first, followed by partial matches in
/// catalog order.
List<ClubOrganization> searchClubCatalog(String query) {
  final normalized = normalizeClubSearch(query);
  if (normalized.isEmpty) return clubCatalog;
  final exact = <ClubOrganization>[];
  final partial = <ClubOrganization>[];
  for (final club in clubCatalog) {
    if (club._searchTerms.contains(normalized)) {
      exact.add(club);
    } else if (club.matches(normalized)) {
      partial.add(club);
    }
  }
  return [...exact, ...partial];
}

/// Lets users find accented names and use either style of apostrophe.
String normalizeClubSearch(String text) => text
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[àâäáãå]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[îïíì]'), 'i')
    .replaceAll(RegExp('[ôöóòõ]'), 'o')
    .replaceAll(RegExp('[ùûüú]'), 'u')
    .replaceAll('ç', 'c')
    .replaceAll('ñ', 'n')
    .replaceAll('œ', 'oe')
    .replaceAll(RegExp("[’']"), '')
    .replaceAll(RegExp('[-‐‑‒–—]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
