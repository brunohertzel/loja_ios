import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData fromHex(String primaryHex, String secondaryHex) =>
      lightFromHex(primaryHex, secondaryHex);

  static ThemeData lightFromHex(String primaryHex, String secondaryHex) =>
      _build(primaryHex, secondaryHex, Brightness.light);

  static ThemeData darkFromHex(String primaryHex, String secondaryHex) =>
      _build(primaryHex, secondaryHex, Brightness.dark);

  static ThemeData _build(
    String primaryHex,
    String secondaryHex,
    Brightness brightness,
  ) {
    final rawPrimary = parseColor(primaryHex) ?? const Color(0xFF1A73E8);
    final rawSecondary = parseColor(secondaryHex) ?? const Color(0xFF202124);
    final dark = brightness == Brightness.dark;

    const darkSurface = Color(0xFF15191F);
    const darkBackground = Color(0xFF0E1116);
    const lightSurface = Colors.white;
    const lightBackground = Color(0xFFF5F7FA);

    final surface = dark ? darkSurface : lightSurface;
    final background = dark ? darkBackground : lightBackground;

    // A cor cadastrada pelo cliente continua sendo a identidade da loja.
    // No modo escuro, porem, cores muito escuras viram ilegíveis sobre as
    // superficies escuras. Clareamos apenas o tom de uso na interface, sem
    // trocar o hue/branding configurado no servidor.
    final primary = dark
        ? _ensureContrast(rawPrimary, surface, minRatio: 4.5)
        : rawPrimary;
    final secondary = dark
        ? _ensureContrast(rawSecondary, surface, minRatio: 4.5)
        : rawSecondary;

    final onSurface = dark ? const Color(0xFFF4F6F8) : const Color(0xFF202124);
    final onSurfaceVariant = dark
        ? const Color(0xFFC8D0DA)
        : const Color(0xFF5F6368);
    final onPrimary = _contrast(primary);
    final onSecondary = _contrast(secondary);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: onPrimary,
          secondary: secondary,
          onSecondary: onSecondary,
          surface: surface,
          onSurface: onSurface,
          onSurfaceVariant: onSurfaceVariant,
          surfaceContainerLowest: dark
              ? const Color(0xFF0D1014)
              : const Color(0xFFFAFBFC),
          surfaceContainerLow: dark
              ? const Color(0xFF12171D)
              : const Color(0xFFF6F8FA),
          surfaceContainer: dark
              ? const Color(0xFF171D24)
              : const Color(0xFFF1F4F7),
          surfaceContainerHigh: dark
              ? const Color(0xFF1C232C)
              : const Color(0xFFEBEFF3),
          surfaceContainerHighest: dark
              ? const Color(0xFF232C36)
              : const Color(0xFFE5EAF0),
          primaryContainer: dark
              ? Color.alphaBlend(
                  primary.withOpacity(.20),
                  const Color(0xFF171D24),
                )
              : null,
          onPrimaryContainer: dark ? onSurface : null,
          secondaryContainer: dark
              ? Color.alphaBlend(
                  secondary.withOpacity(.16),
                  const Color(0xFF171D24),
                )
              : null,
          onSecondaryContainer: dark ? onSurface : null,
          tertiaryContainer: dark ? const Color(0xFF202630) : null,
          onTertiaryContainer: dark ? onSurface : null,
          outline: dark ? const Color(0xFF6B7685) : null,
          outlineVariant: dark ? const Color(0xFF343C47) : null,
        );

    final baseText = ThemeData(
      brightness: brightness,
    ).textTheme.apply(bodyColor: onSurface, displayColor: onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: baseText,
      iconTheme: IconThemeData(color: onSurface),
      dividerColor: dark ? const Color(0xFF343C47) : const Color(0xFFDDE3EA),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: rawPrimary,
        foregroundColor: _contrast(rawPrimary),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: surface,
        indicatorColor: primary.withOpacity(dark ? .28 : .14),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: onSurface, fontWeight: FontWeight.w600),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1A1F27) : Colors.white,
        labelStyle: TextStyle(color: onSurfaceVariant),
        hintStyle: TextStyle(color: onSurfaceVariant),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF46505E) : const Color(0xFFD7DFE8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark
            ? const Color(0xFF202630)
            : const Color(0xFFF2F5F8),
        labelStyle: TextStyle(color: onSurface),
        side: BorderSide(
          color: dark ? const Color(0xFF46505E) : const Color(0xFFD7DFE8),
        ),
      ),
    );
  }

  static Color? parseColor(String? value) {
    var text = value?.replaceAll('#', '').trim() ?? '';
    if (text.length == 6) text = 'FF$text';
    if (text.length != 8) return null;
    final number = int.tryParse(text, radix: 16);
    return number == null ? null : Color(number);
  }

  static Color _contrast(Color color) =>
      color.computeLuminance() > .48 ? Colors.black : Colors.white;

  static Color _ensureContrast(
    Color foreground,
    Color background, {
    double minRatio = 4.5,
  }) {
    if (_contrastRatio(foreground, background) >= minRatio) return foreground;

    var hsl = HSLColor.fromColor(foreground);
    for (var i = 0; i < 20; i++) {
      final next = (hsl.lightness + .035).clamp(0.0, 1.0).toDouble();
      hsl = hsl.withLightness(next);
      final candidate = hsl.toColor();
      if (_contrastRatio(candidate, background) >= minRatio) return candidate;
      if (next >= 1.0) break;
    }
    return Colors.white;
  }

  static double _contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final high = la > lb ? la : lb;
    final low = la > lb ? lb : la;
    return (high + .05) / (low + .05);
  }
}
