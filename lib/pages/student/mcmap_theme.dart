import 'package:material_ui/material_ui.dart';

/// Student preview of the theme proposed for global registration.
final mcMapTheme = _buildTheme();

ThemeData _buildTheme() {
  const mcGillRed = Color(0xFFED1B2F);
  const darkRed = Color(0xFF9E0918);
  const white = Color(0xFFFFFFFF);
  const offWhite = Color(0xFFFAFAFA);
  const lightRed = Color(0xFFFFF1F2);
  const charcoal = Color(0xFF202124);
  const border = Color(0xFFE5E7EB);

  final colors = ColorScheme.fromSeed(seedColor: mcGillRed).copyWith(
    primary: darkRed,
    onPrimary: white,
    primaryContainer: lightRed,
    onPrimaryContainer: darkRed,
    secondaryContainer: lightRed,
    onSecondaryContainer: darkRed,
    tertiaryContainer: lightRed,
    onTertiaryContainer: darkRed,
    surface: white,
    onSurface: charcoal,
    onSurfaceVariant: const Color(0xFF49454A),
    outlineVariant: border,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: colors);
  final text = base.textTheme;

  return base.copyWith(
    scaffoldBackgroundColor: offWhite,
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarThemeData(
      backgroundColor: darkRed,
      foregroundColor: white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: white,
        fontSize: 24,
        fontWeight: FontWeight.w800,
      ),
    ),
    searchBarTheme: const SearchBarThemeData(
      backgroundColor: WidgetStatePropertyAll(lightRed),
      elevation: WidgetStatePropertyAll(0),
    ),
    cardTheme: CardThemeData(
      color: white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: white,
      indicatorColor: lightRed,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colors.primary
              : colors.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? colors.primary
              : colors.onSurfaceVariant,
        ),
      ),
    ),
    inputDecorationTheme: const InputDecorationThemeData(
      border: OutlineInputBorder(),
    ),
  );
}
