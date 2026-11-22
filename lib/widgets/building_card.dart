import 'package:material_ui/material_ui.dart';

import '../data/campus_buildings.dart';
import '../theme/app_theme.dart';

/// Everything inside one highlighted building.
class BuildingCard extends StatelessWidget {
  const BuildingCard({
    super.key,
    required this.building,
    required this.onClose,
    this.onOpenOrganization,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  final CampusBuilding building;
  final VoidCallback onClose;

  /// Opens a society's page, by catalog id.
  final ValueChanged<String>? onOpenOrganization;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: McMapColors.slate);
    final highlight = building.highlight;
    return Semantics(
      container: true,
      label: 'Building details',
      child: Material(
        color: McMapColors.white,
        elevation: 8,
        shadowColor: McMapColors.ink.withValues(alpha: 0.3),
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: Color(0xFF000000 | highlight.color)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(building.name, style: text.titleLarge),
                          const SizedBox(height: 2),
                          Text(building.address, style: muted),
                          const SizedBox(height: 8),
                          _CategoryBadge(building),
                          if (building.hours case final hours?) ...[
                            const SizedBox(height: 8),
                            _Detail(Icons.schedule_rounded, hours),
                          ],
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: McMapColors.border),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                primary: false,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  for (final (index, space) in building.spaces.indexed) ...[
                    if (index > 0)
                      const Divider(height: 1, color: McMapColors.border),
                    _SpaceTile(
                      space: space,
                      // One link per society.
                      onOpenOrganization:
                          building.spaces
                              .take(index)
                              .any((other) => other.clubId == space.clubId)
                          ? null
                          : onOpenOrganization,
                    ),
                  ],
                  Text(
                    'Rooms and hours can change. Check with the society first.',
                    style: muted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge(this.building);

  final CampusBuilding building;

  @override
  Widget build(BuildContext context) {
    final highlight = building.highlight;
    final category = building.category.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: McMapColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: McMapColors.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HighlightDot(highlight),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              highlight.isFaculty ? '${highlight.label} · $category' : category,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// A swatch of a building's map colour.
class HighlightDot extends StatelessWidget {
  const HighlightDot(this.highlight, {super.key, this.size = 12});

  final BuildingHighlight highlight;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Color(0xFF000000 | highlight.color),
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

class _SpaceTile extends StatelessWidget {
  const _SpaceTile({required this.space, this.onOpenOrganization});

  final BuildingSpace space;
  final ValueChanged<String>? onOpenOrganization;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final clubId = space.clubId;
    final open = onOpenOrganization;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(space.name, style: text.titleSmall),
              SpaceTypeBadge(space.type),
            ],
          ),
          const SizedBox(height: 4),
          _Detail(
            Icons.place_outlined,
            space.roomOrFloor ?? 'Room not published',
          ),
          if (space.hours case final hours?)
            _Detail(Icons.schedule_rounded, hours),
          if (space.description case final description?)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(description, style: text.bodyMedium),
            ),
          if (clubId != null && open != null)
            TextButton(
              onPressed: () => open(clubId),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 40),
              ),
              child: Text('View ${space.organization} page'),
            ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 15, color: McMapColors.slate),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: McMapColors.slate),
        ),
      ),
    ],
  );
}

/// "Faculty Office", "Student Lounge" or "Campus Society". AA contrast.
class SpaceTypeBadge extends StatelessWidget {
  const SpaceTypeBadge(this.type, {super.key});

  final SpaceType type;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (type) {
      SpaceType.facultyOffice => (McMapColors.redTint, McMapColors.burgundy),
      SpaceType.studentLounge => (McMapColors.surfaceMuted, McMapColors.ink),
      SpaceType.campusSociety => (McMapColors.ink, McMapColors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
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
