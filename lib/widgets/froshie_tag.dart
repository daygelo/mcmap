import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Black-and-neon "FROSHIE" pill for U0 students and first-year / Frosh
/// events. Deliberately the one non-McGill-red accent in the app, so it reads
/// as special without competing with red CTAs. Static glow, no animation.
///
/// Contrast: neon lime on obsidian is 13.9:1 (AA needs 4.5).
class FroshieTag extends StatelessWidget {
  const FroshieTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Froshie: first-year',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: McMapColors.froshObsidian,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: McMapColors.froshNeon),
          boxShadow: const [
            BoxShadow(color: McMapColors.froshGlow, blurRadius: 8),
          ],
        ),
        child: Text(
          'FROSHIE',
          style: TextStyle(
            fontFamily: McMapFonts.sans,
            fontFamilyFallback: McMapFonts.sansFallback,
            color: McMapColors.froshNeon,
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: 11 * 0.06,
          ),
        ),
      ),
    );
  }
}
