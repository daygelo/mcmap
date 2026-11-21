import 'club_catalog_data.dart';

enum OrganizationType {
  club('Club'),
  designTeam('Design team'),
  studentSociety('Student society');

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
      _searchTerms = normalizeClubSearch(
        [fields[1], ...fields.skip(4)].join(' '),
      );

  final String id;
  final String name;
  final List<int> sourceKeys;
  final OrganizationType type;
  final List<String> aliases;
  final String _searchTerms;

  String get category => clubCatalogSources[sourceKeys.first]!.$1;
  Iterable<String> get sourceUrls =>
      sourceKeys.map((key) => clubCatalogSources[key]!.$2);

  bool matches(String normalizedQuery) =>
      _searchTerms.contains(normalizedQuery);
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
    .replaceAll(RegExp(r'\s+'), ' ');
