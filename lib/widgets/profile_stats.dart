import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Instagram-style stat: bold serif number stacked over a small label.
class ProfileStat extends StatelessWidget {
  const ProfileStat({
    super.key,
    required this.value,
    required this.label,
    this.onTap,
  });

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: onTap != null,
      label: '$value $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: text.headlineSmall!.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium!.copyWith(color: McMapColors.slate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top row of a profile: avatar on the left, stats spread across the right.
class ProfileTopRow extends StatelessWidget {
  const ProfileTopRow({super.key, required this.avatar, required this.stats});

  final Widget avatar;
  final List<Widget> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        avatar,
        const SizedBox(width: 16),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final stat in stats) Flexible(child: stat)],
          ),
        ),
      ],
    );
  }
}

/// Circular avatar with a thin McGill red ring and a white gap, 80px total
/// by default.
class RingedAvatar extends StatelessWidget {
  const RingedAvatar({super.key, required this.child, this.diameter = 80});

  /// Should be a circle that fills the space (e.g. CircleAvatar).
  final Widget child;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: McMapColors.white,
        border: Border.all(color: McMapColors.red, width: 2),
      ),
      child: child,
    );
  }
}
