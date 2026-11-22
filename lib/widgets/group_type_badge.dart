import 'package:material_ui/material_ui.dart';

import '../data/clubs.dart';
import '../theme/app_theme.dart';

/// Small label saying what kind of organization this is. Governance is
/// McGill red on tint, research is charcoal, and the rest have natural accents.
/// Every pairing passes WCAG AA.
class GroupTypeBadge extends StatelessWidget {
  const GroupTypeBadge(this.type, {super.key});

  final OrganizationType type;

  static (Color, Color, Color) _natural(McMapAccent accent) =>
      (accent.tint, accent.deep, accent.deep.withValues(alpha: 0.25));

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch (type) {
      OrganizationType.campusSociety ||
      OrganizationType.facultyAssociation ||
      OrganizationType.facultyAffiliation ||
      OrganizationType.studentAssociation ||
      OrganizationType.faculty => (
        McMapColors.redTint,
        McMapColors.burgundy,
        McMapColors.burgundy.withValues(alpha: 0.25),
      ),
      OrganizationType.researchGroup => (
        McMapColors.ink,
        McMapColors.white,
        McMapColors.ink,
      ),
      OrganizationType.club => _natural(McMapAccent.moss),
      OrganizationType.designTeam => _natural(McMapAccent.lake),
      OrganizationType.studentSociety => _natural(McMapAccent.heather),
      OrganizationType.firstYearCouncil ||
      OrganizationType.firstYearCommittee ||
      OrganizationType.firstYearSociety => _natural(McMapAccent.amber),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontFamily: McMapFonts.sans,
          fontFamilyFallback: McMapFonts.sansFallback,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
