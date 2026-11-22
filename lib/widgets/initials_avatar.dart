import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

const _skipWords = {'of', 'the', 'and', '&', 'de', 'des', 'du', 'la', 'le'};

/// Up to two initials: "SSMU Frosh Committee" → "SF",
/// "Faculty of Engineering" → "FE".
String initialsFor(String name) {
  final words = name
      .split(RegExp(r'[\s\-–·/]+'))
      .where((w) => w.isNotEmpty && !_skipWords.contains(w.toLowerCase()))
      .toList();
  if (words.isEmpty) return '?';
  return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
}

/// Circle with initials on an accent tint that stays the same for each name.
/// Used when a club or student has no photo yet. Passes WCAG AA at every size.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.diameter = 44,
    this.image,
    this.onTap,
    this.semanticLabel,
  });

  final String name;
  final double diameter;

  /// Shown over the initials once loaded (club logo, profile photo).
  final ImageProvider? image;

  /// Makes the avatar its own tap target (it won't trigger a parent's tap).
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final accent = McMapAccent.of(name);
    final avatar = CircleAvatar(
      radius: diameter / 2,
      backgroundColor: accent.tint,
      foregroundColor: accent.deep,
      foregroundImage: image,
      onForegroundImageError: image == null ? null : (_, _) {},
      child: Text(
        initialsFor(name),
        style: TextStyle(
          fontFamily: McMapFonts.sans,
          fontFamilyFallback: McMapFonts.sansFallback,
          fontWeight: FontWeight.w700,
          fontSize: diameter * 0.36,
          letterSpacing: 0.3,
        ),
      ),
    );
    final onTap = this.onTap;
    if (onTap == null) {
      return Semantics(
        label: semanticLabel,
        excludeSemantics: semanticLabel != null,
        child: avatar,
      );
    }
    return Semantics(
      button: true,
      label: semanticLabel ?? name,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: avatar),
      ),
    );
  }
}
