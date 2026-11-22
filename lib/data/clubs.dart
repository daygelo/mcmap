import 'club_catalog_data.dart';

enum OrganizationType {
  club('Club'),
  designTeam('Design team'),
  studentSociety('Student society'),
  firstYearCouncil('First-year council'),
  firstYearCommittee('First-year committee'),
  firstYearSociety('First-year society');

  const OrganizationType(this.label);
  final String label;
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

  bool matches(String normalizedQuery) =>
      _searchTerms.any((term) => term.contains(normalizedQuery));
}

final clubCatalog = List<ClubOrganization>.unmodifiable(
  clubCatalogRows
      .trim()
      .split('\n')
      .map((row) => ClubOrganization._(row.split('|'))),
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
