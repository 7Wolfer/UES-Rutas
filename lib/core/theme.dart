import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'brand.dart';

/// Tema de la app derivado de la identidad gráfica UES.
///
/// - `primary` = naranja institucional → acentos, navegación activa, ruta, FAB.
/// - Botón principal (CTA) = vino, por contraste y peso institucional.
/// - Tipografía: Montserrat (títulos) + Source Sans 3 (cuerpo).
abstract final class UesTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final cs = isLight ? _lightScheme : _darkScheme;

    final typo = Typography.material2021(platform: TargetPlatform.iOS);
    final baseText = isLight ? typo.black : typo.white;
    final headings = GoogleFonts.montserratTextTheme(baseText);
    final body = GoogleFonts.sourceSans3TextTheme(baseText);

    final textTheme = headings
        .copyWith(
          bodyLarge: body.bodyLarge,
          bodyMedium: body.bodyMedium,
          bodySmall: body.bodySmall,
          labelLarge: body.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          labelMedium: body.labelMedium,
          labelSmall: body.labelSmall,
          titleMedium: headings.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          titleLarge: headings.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          headlineSmall:
              headings.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          headlineMedium:
              headings.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        )
        .apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor:
          isLight ? UesBrand.neutro0 : UesBrand.oscuroFondo,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? UesBrand.vino : UesBrand.oscuroSuperficie,
        foregroundColor: isLight ? Colors.white : UesBrand.oscuroTexto,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: isLight ? Colors.white : UesBrand.oscuroTexto,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: UesBrand.vino,
          foregroundColor: Colors.white,
          disabledBackgroundColor: cs.onSurface.withValues(alpha: 0.12),
          minimumSize: const Size(0, 52),
          textStyle: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outline),
          minimumSize: const Size(0, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: UesBrand.naranja,
        foregroundColor: Color(0xFF2A1200),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? Colors.white : UesBrand.oscuroSuperficie,
        indicatorColor: UesBrand.naranja.withValues(alpha: 0.16),
        elevation: 3,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.sourceSans3(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? UesBrand.naranjaOscuro : cs.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? UesBrand.naranjaOscuro : cs.onSurfaceVariant,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isLight ? Colors.white : UesBrand.oscuroSuperficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        side: BorderSide(color: cs.outlineVariant),
        backgroundColor: isLight ? UesBrand.neutro50 : UesBrand.oscuroSuperficieAlta,
        selectedColor: UesBrand.naranja.withValues(alpha: 0.16),
        labelStyle: GoogleFonts.sourceSans3(fontWeight: FontWeight.w600),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? UesBrand.neutro50 : UesBrand.oscuroSuperficieAlta,
        hintStyle: TextStyle(color: cs.onSurfaceVariant),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: UesBrand.naranja, width: 2),
        ),
      ),
      dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? UesBrand.naranja : null),
      ),
    );
  }

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: UesBrand.naranja,
    onPrimary: Color(0xFF2A1200),
    primaryContainer: Color(0xFFFFE2CE),
    onPrimaryContainer: UesBrand.naranjaOscuro,
    secondary: UesBrand.vino,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFF7D9E1),
    onSecondaryContainer: UesBrand.vinoOscuro,
    tertiary: Color(0xFF8A6A00),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFFE7A8),
    onTertiaryContainer: Color(0xFF3E2E00),
    error: UesBrand.error,
    onError: Colors.white,
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: UesBrand.neutro0,
    onSurface: UesBrand.neutro900,
    onSurfaceVariant: UesBrand.neutro700,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: UesBrand.neutro50,
    surfaceContainer: UesBrand.neutro50,
    surfaceContainerHigh: UesBrand.neutro100,
    surfaceContainerHighest: UesBrand.neutro100,
    outline: UesBrand.neutro300,
    outlineVariant: UesBrand.neutro200,
    shadow: Color(0x1A241F1B),
    scrim: Colors.black54,
    inverseSurface: UesBrand.neutro900,
    onInverseSurface: UesBrand.neutro50,
    inversePrimary: Color(0xFFFFB68C),
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: UesBrand.naranja,
    onPrimary: Color(0xFF2A1200),
    primaryContainer: Color(0xFF7A3A06),
    onPrimaryContainer: Color(0xFFFFDCC6),
    secondary: UesBrand.vinoClaro,
    onSecondary: Color(0xFF3A0616),
    secondaryContainer: Color(0xFF6B1030),
    onSecondaryContainer: Color(0xFFFFD9E0),
    tertiary: UesBrand.amarillo,
    onTertiary: Color(0xFF3A2A00),
    tertiaryContainer: Color(0xFF5E4600),
    onTertiaryContainer: Color(0xFFFFE7A8),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    surface: UesBrand.oscuroSuperficie,
    onSurface: UesBrand.oscuroTexto,
    onSurfaceVariant: UesBrand.oscuroTextoTenue,
    surfaceContainerLowest: UesBrand.oscuroFondo,
    surfaceContainerLow: UesBrand.oscuroSuperficie,
    surfaceContainer: UesBrand.oscuroSuperficieAlta,
    surfaceContainerHigh: Color(0xFF352E28),
    surfaceContainerHighest: Color(0xFF3F3830),
    outline: UesBrand.oscuroBorde,
    outlineVariant: Color(0xFF302A24),
    shadow: Colors.black,
    scrim: Colors.black87,
    inverseSurface: UesBrand.oscuroTexto,
    onInverseSurface: UesBrand.oscuroSuperficie,
    inversePrimary: UesBrand.naranjaOscuro,
  );
}
