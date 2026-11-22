import 'package:material_ui/material_ui.dart';

/// McMap colour tokens, anchored on McGill Red.
///
/// Contrast ratios (WCAG 2.1) are noted where text sits on a colour.
/// AA needs 4.5:1 for normal text, 3:1 for large text and non-text UI.
abstract final class McMapColors {
  // Brand reds
  /// McGill Red. Pins, icons, active indicators, focus rings, badges without
  /// text. White text on it is only 4.38:1, so don't use it behind body text.
  static const red = Color(0xFFED1B2F);

  /// Near-brand red for fills with white labels (4.54:1 contrast).
  static const redFill = Color(0xFFE81B2F);

  /// Deeper red for small text and links on light surfaces.
  static const redStrong = Color(0xFFC8102E);

  /// Burgundy: hover/pressed state of red buttons, text on tinted red
  /// surfaces (7.64:1 on [redTint]).
  static const burgundy = Color(0xFF9E0B0F);

  /// Soft red tint for the selected nav item and highlight banners.
  static const redTint = Color(0xFFFDF2F3);

  // Surfaces
  static const white = Color(0xFFFFFFFF);
  static const background = Color(0xFFF8F9FA);
  static const surfaceMuted = Color(0xFFF4F4F5);

  // Text
  /// Primary text, 17.4:1 on white. Never pure black.
  static const ink = Color(0xFF1A1A1A);

  /// Secondary text, timestamps, metadata. 6.2:1 on white.
  static const slate = Color(0xFF5B6170);

  /// Disabled text/icons and placeholder hints (decorative only).
  static const slateLight = Color(0xFF8A909C);

  // Borders
  static const border = Color(0xFFE4E5E9);
  static const borderStrong = Color(0xFFD9DCE1);

  // Froshie tag (first-years / Frosh events): the one deliberate off-brand
  // accent. Neon on obsidian is 13.9:1.
  static const froshObsidian = Color(0xFF111114);
  static const froshNeon = Color(0xFF39FF14);
  static const froshGlow = Color(0x4039FF14); // 25% neon, static glow only

  // Status
  static const success = Color(0xFF1E7B4F);
  static const error = burgundy;
}

/// Natural accents for everything that isn't a brand anchor: avatars, tags,
/// choices and interests. McGill red stays for the header, the main action on
/// a screen, navigation, unread badges and map pins.
///
/// Every [deep] is at least 5.0:1 on its [tint] and 5.6:1 under white.
enum McMapAccent {
  /// Mount Royal's pines. Selected chips, radios and switches use this one.
  pine(Color(0xFF2F6B4F), Color(0xFFE4F0E8)),
  moss(Color(0xFF566E28), Color(0xFFEDF2DF)),
  spruce(Color(0xFF1F6B69), Color(0xFFDFF0EE)),

  /// The St. Lawrence.
  lake(Color(0xFF266A8A), Color(0xFFE1F0F6)),
  sky(Color(0xFF3A62A6), Color(0xFFE6EDF9)),
  heather(Color(0xFF6A579B), Color(0xFFEEEAF7)),
  plum(Color(0xFF87426F), Color(0xFFF6E8F1)),

  /// Brick.
  clay(Color(0xFFA04C2B), Color(0xFFF9EAE2)),

  /// Maple syrup.
  amber(Color(0xFF86600F), Color(0xFFF8F0DA)),

  /// Montréal greystone.
  stone(Color(0xFF59606C), Color(0xFFECEEF1));

  const McMapAccent(this.deep, this.tint);

  /// Text, icons and solid fills.
  final Color deep;

  /// Backgrounds behind [deep].
  final Color tint;

  /// The same one every time for a given [name].
  static McMapAccent of(String name) {
    var hash = 7;
    for (final unit in name.trim().toLowerCase().codeUnits) {
      hash = (hash * 31 + unit) & 0x3FFFFFFF;
    }
    return values[hash % values.length];
  }
}

/// McMap type system.
///
/// Serif ([serif]) for brand moments: screen titles, app bar, featured event
/// headers. Sans ([sans]) for everything you read or tap: body, metadata,
/// tags, buttons, map labels. Both are bundled in assets/fonts so they render
/// the same everywhere; the fallbacks only apply if an asset fails to load.
abstract final class McMapFonts {
  static const serif = 'SourceSerif4';
  static const serifFallback = ['Georgia', 'Times New Roman', 'serif'];
  static const sans = 'Inter';
  static const sansFallback = ['Helvetica Neue', 'Arial', 'sans-serif'];

  static TextStyle _serif(double size, double height, FontWeight weight) =>
      TextStyle(
        fontFamily: serif,
        fontFamilyFallback: serifFallback,
        fontSize: size,
        height: height,
        fontWeight: weight,
        letterSpacing: -0.2,
        color: McMapColors.ink,
      );

  static TextStyle _sans(
    double size,
    double height,
    FontWeight weight, {
    Color color = McMapColors.ink,
    double letterSpacing = 0,
  }) => TextStyle(
    fontFamily: sans,
    fontFamilyFallback: sansFallback,
    fontSize: size,
    height: height,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    color: color,
  );

  static final textTheme = TextTheme(
    // Serif: brand / editorial
    displayLarge: _serif(48, 1.1, FontWeight.w700),
    displayMedium: _serif(40, 1.15, FontWeight.w700),
    displaySmall: _serif(34, 1.15, FontWeight.w700),
    headlineLarge: _serif(30, 1.2, FontWeight.w700),
    headlineMedium: _serif(26, 1.25, FontWeight.w700), // screen titles
    headlineSmall: _serif(22, 1.3, FontWeight.w600), // featured event header
    titleLarge: _serif(20, 1.3, FontWeight.w600), // app bar, card section
    // Sans: UI / reading
    titleMedium: _sans(16, 1.4, FontWeight.w600), // event card title
    titleSmall: _sans(14, 1.4, FontWeight.w600),
    bodyLarge: _sans(16, 1.5, FontWeight.w400), // descriptions
    bodyMedium: _sans(14, 1.5, FontWeight.w400),
    bodySmall: _sans(12, 1.4, FontWeight.w400, color: McMapColors.slate),
    labelLarge: _sans(14, 1.2, FontWeight.w600), // buttons
    labelMedium: _sans(12, 1.2, FontWeight.w600, letterSpacing: 0.2), // tags
    labelSmall: _sans(11, 1.2, FontWeight.w500, letterSpacing: 0.3), // map
  );
}

/// Map-specific tokens. Read with `Theme.of(context).extension<McMapMapStyle>()!`.
@immutable
class McMapMapStyle extends ThemeExtension<McMapMapStyle> {
  const McMapMapStyle({
    this.pin = McMapColors.red,
    this.pinBorder = McMapColors.white,
    this.pinActive = McMapColors.burgundy,
    this.pinActiveHalo = const Color(0x33ED1B2F),
    this.pinPast = McMapColors.slateLight,
    this.clusterFill = McMapColors.ink,
    this.clusterText = McMapColors.white,
    this.clusterBorder = McMapColors.red,
    this.userLocation = const Color(0xFF2B6CB0),
  });

  /// RSVPed event pin. Always draw with a 2px [pinBorder] and a soft shadow
  /// so it separates from any tile colour.
  final Color pin;
  final Color pinBorder;

  /// Selected pin: scale up ~1.25x, fill burgundy, add [pinActiveHalo] ring.
  final Color pinActive;
  final Color pinActiveHalo;

  /// Events that already happened.
  final Color pinPast;

  /// Cluster bubble: charcoal with a red ring, so clusters read as "many"
  /// and don't compete with individual red pins.
  final Color clusterFill;
  final Color clusterText;
  final Color clusterBorder;

  /// The one non-red marker, so "you are here" is never confused with an event.
  final Color userLocation;

  @override
  McMapMapStyle copyWith() => this;

  @override
  McMapMapStyle lerp(ThemeExtension<McMapMapStyle>? other, double t) => this;
}

/// Button styles that sit outside the default (red) filled button.
abstract final class McMapButtonStyles {
  /// Instagram-style neutral grey button ("Edit Profile", "Share Profile"),
  /// for actions on your own stuff where red would shout.
  static final neutral = ButtonStyle(
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    minimumSize: const WidgetStatePropertyAll(Size.fromHeight(40)),
    elevation: const WidgetStatePropertyAll(0),
    foregroundColor: const WidgetStatePropertyAll(McMapColors.ink),
    backgroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.pressed) || s.contains(WidgetState.hovered)
          ? McMapColors.borderStrong
          : McMapColors.surfaceMuted,
    ),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}

ThemeData buildMcMapTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: McMapColors.redFill,
    onPrimary: McMapColors.white,
    primaryContainer: McMapColors.redTint,
    onPrimaryContainer: McMapColors.burgundy,
    secondary: McMapColors.slate,
    onSecondary: McMapColors.white,
    secondaryContainer: McMapColors.surfaceMuted,
    onSecondaryContainer: McMapColors.ink,
    tertiary: McMapColors.burgundy,
    onTertiary: McMapColors.white,
    tertiaryContainer: McMapColors.redTint,
    onTertiaryContainer: McMapColors.burgundy,
    error: McMapColors.error,
    onError: McMapColors.white,
    surface: McMapColors.white,
    onSurface: McMapColors.ink,
    onSurfaceVariant: McMapColors.slate,
    surfaceContainerLowest: McMapColors.white,
    surfaceContainerLow: McMapColors.background,
    surfaceContainer: McMapColors.background,
    surfaceContainerHigh: McMapColors.surfaceMuted,
    surfaceContainerHighest: McMapColors.surfaceMuted,
    outline: McMapColors.borderStrong,
    outlineVariant: McMapColors.border,
    surfaceTint: Colors.transparent,
  );

  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

  final selection = WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return McMapColors.slateLight;
    return states.contains(WidgetState.selected)
        ? McMapAccent.pine.deep
        : McMapColors.slate;
  });

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: McMapColors.background,
    fontFamily: McMapFonts.sans,
    fontFamilyFallback: McMapFonts.sansFallback,
    textTheme: McMapFonts.textTheme,
    extensions: const [McMapMapStyle()],

    // Header: clean white bar, ink title, hairline divider instead of colour.
    appBarTheme: AppBarTheme(
      backgroundColor: McMapColors.white,
      foregroundColor: McMapColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: const Border(bottom: BorderSide(color: McMapColors.border)),
      titleTextStyle: McMapFonts.textTheme.titleLarge,
    ),

    // Event cards: white, hairline border, no tinted elevation.
    cardTheme: CardThemeData(
      color: McMapColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: McMapColors.border),
      ),
    ),

    searchBarTheme: SearchBarThemeData(
      backgroundColor: const WidgetStatePropertyAll(McMapColors.white),
      elevation: const WidgetStatePropertyAll(0),
      shape: const WidgetStatePropertyAll(
        StadiumBorder(side: BorderSide(color: McMapColors.border)),
      ),
      textStyle: WidgetStatePropertyAll(McMapFonts.textTheme.bodyLarge),
      hintStyle: WidgetStatePropertyAll(
        McMapFonts.textTheme.bodyLarge!.copyWith(color: McMapColors.slate),
      ),
    ),

    // Primary actions use an accessible near-match to the brand red.
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(shape),
        textStyle: WidgetStatePropertyAll(
          McMapFonts.textTheme.labelLarge!.copyWith(fontSize: 16),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? McMapColors.slate
              : McMapColors.white,
        ),
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return McMapColors.surfaceMuted;
          if (s.contains(WidgetState.pressed) ||
              s.contains(WidgetState.hovered)) {
            return McMapColors.burgundy;
          }
          return colorScheme.primary;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),

    // Secondary action ("Details", "Share"): outlined, ink text.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: McMapColors.ink,
        side: const BorderSide(color: McMapColors.borderStrong),
        shape: shape,
        textStyle: McMapFonts.textTheme.labelLarge!.copyWith(fontSize: 16),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: McMapColors.redStrong,
        textStyle: McMapFonts.textTheme.labelLarge,
      ),
    ),

    // Choices are pine green, so red is left for actions.
    radioTheme: RadioThemeData(fillColor: selection),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? selection.resolve(states)
            : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(McMapColors.white),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) &&
                !states.contains(WidgetState.disabled)
            ? McMapAccent.pine.deep
            : null,
      ),
    ),

    // Category tags / filters: selected ones turn pine green.
    chipTheme: ChipThemeData(
      backgroundColor: McMapColors.white,
      selectedColor: McMapAccent.pine.tint,
      labelStyle: McMapFonts.textTheme.bodyMedium!.copyWith(
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: McMapFonts.textTheme.bodyMedium!.copyWith(
        color: McMapAccent.pine.deep,
        fontWeight: FontWeight.w600,
      ),
      checkmarkColor: McMapAccent.pine.deep,
      side: WidgetStateBorderSide.resolveWith(
        (s) => BorderSide(
          color: s.contains(WidgetState.selected)
              ? McMapAccent.pine.deep
              : McMapColors.borderStrong,
        ),
      ),
      shape: const StadiumBorder(),
    ),

    // Bottom nav: white bar, red-tint pill behind the active tab.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: McMapColors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: McMapColors.redTint,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? McMapColors.red
              : McMapColors.slate,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => McMapFonts.textTheme.labelMedium!.copyWith(
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected)
              ? McMapColors.burgundy
              : McMapColors.slate,
        ),
      ),
    ),

    tabBarTheme: const TabBarThemeData(
      labelColor: McMapColors.ink,
      unselectedLabelColor: McMapColors.slate,
      indicatorColor: McMapColors.red,
      dividerColor: McMapColors.border,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: McMapColors.white,
      hintStyle: McMapFonts.textTheme.bodyLarge!.copyWith(
        color: McMapColors.slate,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: McMapColors.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: McMapColors.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: McMapColors.red, width: 2),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: McMapColors.red,
    ),
    dividerTheme: const DividerThemeData(color: McMapColors.border),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: McMapColors.ink,
      contentTextStyle: McMapFonts.textTheme.bodyMedium!.copyWith(
        color: McMapColors.white,
      ),
      actionTextColor: const Color(0xFFFF8A95),
    ),
  );
}
