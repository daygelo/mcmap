import '../data/campus_groups.dart';
import '../data/clubs.dart';

enum OrganizerCategory {
  faculty('Faculty', {OrganizationType.faculty}),
  association('Student association / society', {
    OrganizationType.studentAssociation,
    OrganizationType.studentSociety,
    OrganizationType.campusSociety,
    OrganizationType.facultyAssociation,
    OrganizationType.facultyAffiliation,
    OrganizationType.firstYearSociety,
    OrganizationType.firstYearCouncil,
  }),
  club('Club', {OrganizationType.club, OrganizationType.designTeam}),
  other('Other recognized organization', {});

  const OrganizerCategory(this.label, this.types);

  final String label;
  final Set<OrganizationType> types;

  bool matches(OrganizationType? type) => this == other
      ? !values.any((category) => category.types.contains(type))
      : types.contains(type);
}

enum ExecutiveRole {
  president('President', 'president'),
  coordinator('Coordinator', 'coordinator'),
  facultyRepresentative('Faculty representative', 'faculty_representative'),
  delegatedPublisher('Delegated publisher', 'delegated_publisher');

  const ExecutiveRole(this.label, this.dbValue);
  final String label;
  final String dbValue;
}

enum OrganizerStatus {
  verifyEmail('Verify your executive email', 'verify_email'),
  pendingReview('Awaiting approval', 'pending_review'),
  approved('Verified organizer', 'approved'),
  rejected('Application rejected', 'rejected'),
  revoked('Publishing access revoked', 'revoked');

  const OrganizerStatus(this.label, this.dbValue);
  final String label;
  final String dbValue;
}

typedef ExecutiveDetails = ({
  String groupId,
  String fullName,
  String email,
  ExecutiveRole role,
});

class OrganizerApplication {
  const OrganizerApplication({
    required this.id,
    required this.details,
    required this.organization,
    required this.status,
    this.reviewNote,
  });

  final String id;
  final ExecutiveDetails details;
  final String organization;
  final OrganizerStatus status;
  final String? reviewNote;
}

class OrganizerRequestError implements Exception {
  const OrganizerRequestError(this.message);
  final String message;
}

abstract interface class OrganizerBackend {
  Future<List<CampusGroup>> fetchOrganizerDirectory();
  Future<List<OrganizerApplication>> fetchOrganizerApplications();
  Future<String> sendExecutiveCode(ExecutiveDetails details);
  Future<void> verifyExecutiveCode({
    required String applicationId,
    required String groupId,
    required String code,
  });
  Future<void> requestOrganization(String name, OrganizerCategory category);
  Future<void> completeOrganizerOnboarding();
}
