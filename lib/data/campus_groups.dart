import 'clubs.dart';

/// A campus organization outside the sourced club catalog (`groups` in
/// Supabase): research groups, newer clubs, faculties, committees...
class CampusGroup {
  const CampusGroup({
    required this.id,
    required this.name,
    this.type,
    this.shortName,
    this.handle,
    this.facultyAffiliation,
    this.description,
    this.avatarUrl,
    this.sourceUrl,
  });

  /// From a `groups` row. Reads optional columns defensively so the app still
  /// works before the group details migration has been run.
  factory CampusGroup.fromRow(Map<String, dynamic> row) => CampusGroup(
    id: row['slug'] as String,
    name: row['name'] as String,
    type: OrganizationType.fromDb(row['type']),
    shortName: row['short_name'] as String?,
    handle: row['handle'] as String?,
    facultyAffiliation: row['faculty_affiliation'] as String?,
    description: row['description'] as String?,
    avatarUrl: row['avatar_url'] as String?,
    sourceUrl: row['website_url'] as String?,
  );

  /// `groups.slug`.
  final String id;
  final String name;

  /// Null when the server sends a type this version doesn't know.
  final OrganizationType? type;
  final String? shortName;

  /// Without the "@".
  final String? handle;
  final String? facultyAffiliation;
  final String? description;
  final String? avatarUrl;

  /// A public page showing the group exists. Null = not verified.
  final String? sourceUrl;

  /// 0 exact, 1 word match, 2 partial match, null no match.
  int? searchRank(String query) {
    final q = normalizeClubSearch(query).replaceFirst(RegExp('^@'), '');
    if (q.isEmpty) return 2;
    final rank = organizationSearchRank(
      [name, ?shortName, ?handle].map(normalizeClubSearch),
      q,
    );
    if (rank != null && (rank < 2 || q.length > 2)) return rank;
    // "society" or "research" finds groups of that type.
    final label = type == null ? '' : normalizeClubSearch(type!.label);
    return q.length > 2 && organizationSearchRank([label], q) != null
        ? 1
        : null;
  }
}

/// A search result: either a catalog [club] or another campus [group].
class OrganizationMatch {
  const OrganizationMatch.club(ClubOrganization this.club) : group = null;
  const OrganizationMatch.group(CampusGroup this.group) : club = null;

  final ClubOrganization? club;
  final CampusGroup? group;

  OrganizationType? get type => club?.type ?? group!.type;
}

/// Catalog clubs and other campus groups together, best match first.
List<OrganizationMatch> searchOrganizations(
  String query,
  Iterable<CampusGroup> others,
) {
  final clubs = searchClubCatalog(query);
  final q = normalizeClubSearch(query);
  if (q.isEmpty) {
    return [
      for (final club in clubs) OrganizationMatch.club(club),
      for (final group in others) OrganizationMatch.group(group),
    ];
  }
  final ranked = <(int, OrganizationMatch)>[
    for (final group in others)
      if (group.searchRank(q) case final rank?)
        (rank, OrganizationMatch.group(group)),
    for (final club in clubs)
      (club.searchRank(q) ?? 2, OrganizationMatch.club(club)),
  ];
  return [
    for (var rank = 0; rank <= 2; rank++)
      for (final (r, match) in ranked)
        if (r == rank) match,
  ];
}

/// Supplemental seed metadata for groups already represented in the catalog.
const catalogGroupDetails = {
  'science-csus': CampusGroup(
    id: 'science-csus',
    name: 'Computer Science Undergraduate Society',
    type: OrganizationType.studentSociety,
    shortName: 'CSUS',
    facultyAffiliation: 'Science',
    description: 'Represents McGill undergraduate computer science students.',
    sourceUrl: 'https://mcgill-csus.ca/get-involved',
  ),
};

/// Groups added on top of the catalog. The offline demo shows these, and
/// tool/generate_seed.dart writes them into supabase/seed.sql.
///
/// Entries without a [CampusGroup.sourceUrl] were requested for McMap but no
/// public page confirming them was found: check them before launch.
const campusGroups = [
  CampusGroup(
    id: 'mcgill-ml',
    name: 'mcgill.ml',
    type: OrganizationType.club,
    shortName: 'mcgill.ml',
    handle: 'mcgill.ml',
    facultyAffiliation: 'Cross-Faculty',
    description: 'McGill Machine Learning Club.',
  ),
  CampusGroup(
    id: 'hackmcgill',
    name: 'HackMcGill',
    type: OrganizationType.club,
    handle: 'hackmcgill',
    facultyAffiliation: 'Cross-Faculty',
    description: 'Student hacker collective behind the McHacks hackathon.',
    sourceUrl: 'https://mcgill-csus.ca/get-involved',
  ),
  CampusGroup(
    id: 'mcgill-ai-society',
    name: 'McGill AI Society',
    type: OrganizationType.studentSociety,
    shortName: 'MAIS',
    handle: 'mcgillai',
    facultyAffiliation: 'Cross-Faculty',
    description:
        'Student society making AI more accessible through workshops, the '
        'MAIS 202 bootcamp and MAIS Hacks.',
    sourceUrl:
        'https://euswiki.mcgilleus.ca/McGill_Artificial_Intelligence_Society',
  ),
  CampusGroup(
    id: 'mcgill-pre-med-society',
    name: 'McGill Pre-Med Society',
    type: OrganizationType.studentSociety,
    facultyAffiliation: 'Cross-Faculty',
  ),
  CampusGroup(
    id: 'mcgill-finance-society',
    name: 'McGill Finance Society',
    type: OrganizationType.studentSociety,
    facultyAffiliation: 'Desautels Management',
  ),
  CampusGroup(
    id: 'mcgill-ai-lab',
    name: 'McGill AI Lab',
    type: OrganizationType.researchGroup,
    shortName: 'mcgillailab',
    handle: 'mcgillailab',
    facultyAffiliation: 'Cross-Faculty',
  ),
  CampusGroup(
    id: 'mcgill-autonomous-vehicles-perception-lab',
    name: 'McGill Autonomous Vehicles & Perception Lab',
    type: OrganizationType.researchGroup,
    facultyAffiliation: 'Engineering',
  ),
  CampusGroup(
    id: 'mcgill-computational-biology-research-group',
    name: 'McGill Computational Biology Research Group',
    type: OrganizationType.researchGroup,
    facultyAffiliation: 'Science',
  ),
];
