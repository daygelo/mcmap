import 'package:material_ui/material_ui.dart';

import '../data/campus_buildings.dart';
import '../theme/app_theme.dart';
import 'building_card.dart';

/// Collapsible key to the building colours.
class MapLegend extends StatefulWidget {
  const MapLegend({super.key});

  @override
  State<MapLegend> createState() => _MapLegendState();
}

class _MapLegendState extends State<MapLegend> {
  bool _open = false;

  static const _preview = [
    BuildingHighlight.ssmu,
    BuildingHighlight.engineering,
    BuildingHighlight.lounge,
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: McMapColors.white,
      elevation: 4,
      shadowColor: McMapColors.ink.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_open) ...[
                      for (final highlight in _preview) ...[
                        HighlightDot(highlight),
                        const SizedBox(width: 4),
                      ],
                      const SizedBox(width: 4),
                    ],
                    Text('Map key', style: text.labelLarge),
                    const SizedBox(width: 4),
                    Icon(
                      _open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Row(HighlightDot(BuildingHighlight.ssmu), 'SSMU'),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 2),
                    child: Text(
                      'Faculty offices',
                      style: text.bodySmall?.copyWith(color: McMapColors.slate),
                    ),
                  ),
                  for (final highlight in BuildingHighlight.values)
                    if (highlight.isFaculty)
                      _Row(HighlightDot(highlight), highlight.label),
                  const SizedBox(height: 6),
                  _Row(
                    const HighlightDot(BuildingHighlight.lounge),
                    BuildingHighlight.lounge.label,
                  ),
                  const _Row(
                    Icon(Icons.place_rounded, size: 14, color: McMapColors.red),
                    'Your RSVPs',
                  ),
                  const SizedBox(height: 8),
                  // Their licences ask for this.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Text(
                      'Building shapes: Ville de Montréal (CC BY 4.0, '
                      'adapted), © OpenStreetMap contributors. Contains '
                      'information licensed under the Open Government '
                      'Licence – Canada.',
                      style: text.bodySmall?.copyWith(
                        color: McMapColors.slate,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.swatch, this.label);

  final Widget swatch;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 14, child: Center(child: swatch)),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
