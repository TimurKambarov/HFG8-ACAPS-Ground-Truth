import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'store.dart';

// ACAPS visual identity, taken from the acaps.org stylesheet.
//
// - Colours: the site's Bootstrap palette. Navy #004B78 for buttons, links and
//   big blocks; teal #0096BA for underlines, card edges and the active nav
//   item; sand #F4A261 and gold #E9C46A as warm accents; light-grey bands
//   (#F2F2F2) behind white cards.
// - Type: Bebas Neue (all-caps headings) and Roboto Condensed (everything
//   else), bundled as small Latin subsets in assets/fonts.
// - Shapes: mostly square edges with small radii, a short teal bar under
//   headings, a coloured left edge on feed cards. Decorative motifs
//   (topographic lines, the map pin) are drawn in code: see brand.dart.
//
// Low bandwidth: no images, no web fonts. Everything is colour, lines and
// two bundled fonts.
//
// Public names (AppColors.*, scaleColors, severityColors, levelColor,
// readable, onColor, buildTheme, buildContrastTheme) are used by the screens.

const fontDisplay = 'BebasNeue';
const fontBody = 'RobotoCondensed';

/// Glyphs missing from the Latin subsets (arrows) come from this tiny font.
const fontFallback = ['Arrows'];

class AppColors {
  // --- acaps.org palette --------------------------------------------------
  /// --bs-primary: buttons, links, navy bands.
  static const navy = Color(0xFF004B78);

  /// Link hover / pressed navy.
  static const navyDeep = Color(0xFF003C60);

  /// Darker navy for headers in the dark theme.
  static const navyNight = Color(0xFF032B45);

  /// --bs-secondary: heading bars, card edges, the active nav underline.
  /// Decoration only: as small text on white it is below 4.5:1.
  static const teal = Color(0xFF0096BA);

  /// Teal dark enough for small text on white (4.9:1).
  static const tealText = Color(0xFF007A99);

  /// Teal for dark backgrounds.
  static const tealBright = Color(0xFF3DB8D8);

  /// --bs-tertiary and --bs-quaternary: warm accents.
  static const sand = Color(0xFFF4A261);
  static const gold = Color(0xFFE9C46A);

  /// --bs-success / --bs-danger / --bs-warning.
  static const green = Color(0xFF5C9B53);
  static const red = Color(0xFFD43D3D);
  static const amber = Color(0xFFF0AD4E);

  /// Body text (#131415 on the site).
  static const ink = Color(0xFF131415);

  /// Footer greys.
  static const graphite = Color(0xFF313131);
  static const charcoal = Color(0xFF212121);

  /// Light-grey page band and hairlines.
  static const mist = Color(0xFFF2F2F2);
  static const line = Color(0xFFDEDEDE);

  // --- Names used by the screens -----------------------------------------
  static const primary = navy;
  static const paperDark = Color(0xFF15181B);
  static const cardDark = Color(0xFF1F2327);

  /// Risk levels as solid tags: red / sand / gold, like a map legend.
  static const high = red;
  static const medium = sand;
  static const low = gold;
}

/// The INFORM Severity scale colours used on acaps.org (very low -> very high).
const informSeverity = [
  Color(0xFFE4C7E4),
  Color(0xFFD17EBD),
  Color(0xFF80558B),
  Color(0xFF47155A),
  Color(0xFF1B0622),
];

bool get _darkInUse => switch (appState.theme) {
      AppTheme.light => false,
      AppTheme.dark || AppTheme.contrast => true,
      AppTheme.system => ui.PlatformDispatcher.instance.platformBrightness == Brightness.dark,
    };

/// ACAPS probability scale, very low -> very high: light teal to navy (dark
/// teal to bright teal in dark themes, so "very high" always stands out).
List<Color> get scaleColors => _darkInUse
    ? const [Color(0xFF1C5568), Color(0xFF1B7A96), Color(0xFF1FA0C2), Color(0xFF5CC8E6), Color(0xFFB0E6F4)]
    : const [Color(0xFF9DD6E6), Color(0xFF4DB5D2), Color(0xFF0096BA), Color(0xFF00668F), AppColors.navy];

/// "How bad would it be", 1 -> 5: the INFORM severity purples.
List<Color> get severityColors => _darkInUse
    ? const [Color(0xFF4A2D57), Color(0xFF6E3F80), Color(0xFF9A62AB), Color(0xFFD17EBD), Color(0xFFE4C7E4)]
    : informSeverity;

/// Fill colour of a risk level tag.
Color levelColor(String level) => switch (level) {
      'High' => AppColors.high,
      'Medium' => AppColors.medium,
      'Low' => AppColors.low,
      _ => _darkInUse ? const Color(0xFF59626A) : const Color(0xFFABABAB),
    };

/// Text colour on top of [c]: white on dark fills, ink on light ones.
Color onColor(Color c) =>
    ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : AppColors.ink;

/// [c] adjusted until it reads as text on the current background (4.5:1):
/// darker on light themes, lighter on dark ones. Hue stays the same.
Color readable(Color c) {
  final dark = _darkInUse;
  final bg = dark ? AppColors.cardDark : Colors.white;
  double contrast(Color a) {
    final la = a.computeLuminance(), lb = bg.computeLuminance();
    return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
  }

  var hsl = HSLColor.fromColor(c);
  var out = c;
  for (var i = 0; i < 20 && contrast(out) < 4.6; i++) {
    final l = (hsl.lightness + (dark ? 0.04 : -0.04)).clamp(0.0, 1.0);
    hsl = hsl.withLightness(l);
    out = hsl.toColor();
  }
  return out;
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return _themeFrom(dark ? _darkScheme : _lightScheme);
}

/// High contrast: black background, white text, ACAPS teal and gold
/// brightened, 2px outlines everywhere, no decorative patterns.
ThemeData buildContrastTheme() => _themeFrom(_contrastScheme, borderWidth: 2);

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.navy,
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFDCEFF5),
  onPrimaryContainer: AppColors.navyNight,
  secondary: AppColors.tealText,
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFDCEFF5),
  onSecondaryContainer: AppColors.navyNight,
  tertiary: Color(0xFFA0592A),
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFFCE9DA),
  onTertiaryContainer: Color(0xFF4A2508),
  error: AppColors.red,
  onError: Colors.white,
  errorContainer: Color(0xFFFBE3E3),
  onErrorContainer: Color(0xFF7F2525),
  surface: AppColors.mist,
  onSurface: AppColors.ink,
  onSurfaceVariant: Color(0xFF5C6166),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Colors.white,
  surfaceContainer: Colors.white,
  surfaceContainerHigh: Colors.white,
  surfaceContainerHighest: Color(0xFFE9E9E9),
  outline: Color(0xFFABABAB),
  outlineVariant: AppColors.line,
  inverseSurface: AppColors.navy,
  onInverseSurface: Colors.white,
  inversePrimary: AppColors.tealBright,
  shadow: Colors.black,
  scrim: Colors.black,
  surfaceTint: Colors.transparent,
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: AppColors.tealBright,
  onPrimary: Color(0xFF00202E),
  primaryContainer: Color(0xFF00405F),
  onPrimaryContainer: Color(0xFFCDEFF8),
  secondary: Color(0xFF7FC8DE),
  onSecondary: Color(0xFF00202E),
  secondaryContainer: Color(0xFF0E3A52),
  onSecondaryContainer: Color(0xFFCDEFF8),
  tertiary: AppColors.sand,
  onTertiary: Color(0xFF2B1600),
  tertiaryContainer: Color(0xFF4A2A10),
  onTertiaryContainer: Color(0xFFFFDDC4),
  error: Color(0xFFF28B82),
  onError: Color(0xFF3D0B0B),
  errorContainer: Color(0xFF5C1A1A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: AppColors.paperDark,
  onSurface: Color(0xFFE8EAEC),
  onSurfaceVariant: Color(0xFFA9B0B6),
  surfaceContainerLowest: AppColors.cardDark,
  surfaceContainerLow: AppColors.cardDark,
  surfaceContainer: Color(0xFF23282C),
  surfaceContainerHigh: Color(0xFF2A2F34),
  surfaceContainerHighest: Color(0xFF353B41),
  outline: Color(0xFF6E777F),
  outlineVariant: Color(0xFF343A40),
  inverseSurface: Color(0xFFE8EAEC),
  onInverseSurface: AppColors.paperDark,
  inversePrimary: AppColors.navy,
  shadow: Colors.black,
  scrim: Colors.black,
  surfaceTint: Colors.transparent,
);

const _contrastScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF5CC8E6),
  onPrimary: Colors.black,
  primaryContainer: Color(0xFF003344),
  onPrimaryContainer: Colors.white,
  secondary: Colors.white,
  onSecondary: Colors.black,
  secondaryContainer: Color(0xFF1F1F1F),
  onSecondaryContainer: Colors.white,
  tertiary: Color(0xFFF2D58A),
  onTertiary: Colors.black,
  tertiaryContainer: Color(0xFF2E2600),
  onTertiaryContainer: Colors.white,
  error: Color(0xFFFF8A80),
  onError: Colors.black,
  errorContainer: Color(0xFF5A0000),
  onErrorContainer: Colors.white,
  surface: Colors.black,
  onSurface: Colors.white,
  onSurfaceVariant: Colors.white,
  surfaceContainerLowest: Colors.black,
  surfaceContainerLow: Colors.black,
  surfaceContainer: Colors.black,
  surfaceContainerHigh: Color(0xFF141414),
  surfaceContainerHighest: Color(0xFF2A2A2A),
  outline: Colors.white,
  outlineVariant: Colors.white,
  inverseSurface: Colors.white,
  onInverseSurface: Colors.black,
  inversePrimary: AppColors.navy,
  shadow: Colors.black,
  scrim: Colors.black,
  surfaceTint: Colors.transparent,
);

ThemeData _themeFrom(ColorScheme scheme, {double borderWidth = 1}) {
  final light = scheme.brightness == Brightness.light;
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: fontBody, fontFamilyFallback: fontFallback);
  final text = base.textTheme;
  final heading = scheme.onSurface;
  // Teal underline / indicator colour for this theme.
  final accent = light ? AppColors.teal : scheme.primary;
  final barBg = light ? Colors.white : (borderWidth > 1 ? Colors.black : const Color(0xFF1A1E21));

  // Small radii: the website is mostly square.
  const radius = BorderRadius.all(Radius.circular(4));
  const shape = RoundedRectangleBorder(borderRadius: radius);
  final edge = BorderSide(color: scheme.outlineVariant, width: borderWidth);

  // Bebas Neue is all caps and narrow: it needs a larger size than body text.
  TextStyle? display(TextStyle? s, double size) => s?.copyWith(
        fontFamily: fontDisplay,
        fontWeight: FontWeight.w400,
        fontSize: size,
        letterSpacing: 0.6,
        height: 1.0,
        color: heading,
      );
  final label = text.labelLarge!.copyWith(fontFamily: fontBody, fontWeight: FontWeight.w700, letterSpacing: 0.4);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkRipple.splashFactory,
    textTheme: text.copyWith(
      displayLarge: display(text.displayLarge, 64),
      displayMedium: display(text.displayMedium, 52),
      displaySmall: display(text.displaySmall, 44),
      headlineLarge: display(text.headlineLarge, 38),
      headlineMedium: display(text.headlineMedium, 34),
      headlineSmall: display(text.headlineSmall, 29),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 21, height: 1.25, color: heading),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 17.5, height: 1.3, color: heading),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 15.5, height: 1.3, color: heading),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 16.5, height: 1.5),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 1.5),
      bodySmall: text.bodySmall?.copyWith(fontSize: 13.5, height: 1.45, color: scheme.onSurfaceVariant),
      labelLarge: label.copyWith(fontSize: 15),
      labelMedium: text.labelMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.4),
      labelSmall: text.labelSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 11.5, letterSpacing: 0.8),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: barBg,
      foregroundColor: light ? AppColors.navy : scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: edge),
      titleTextStyle: TextStyle(
        fontFamily: fontDisplay,
        fontSize: 25,
        letterSpacing: 0.6,
        height: 1.1,
        color: light ? AppColors.navy : scheme.onSurface,
      ),
    ),
    // White cards on the grey page band, lifted by a soft shadow as on the
    // website's feed cards (no shadow in dark themes: a hairline instead).
    cardTheme: CardThemeData(
      elevation: light ? 1.5 : 0,
      shadowColor: Colors.black.withAlpha(60),
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius, side: light ? BorderSide.none : edge),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: shape,
        textStyle: label.copyWith(fontSize: 16, letterSpacing: 0.8),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(elevation: 0, shape: shape, textStyle: label),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.primary, width: borderWidth == 1 ? 1.5 : borderWidth),
        shape: shape,
        textStyle: label.copyWith(letterSpacing: 0.6),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: light ? AppColors.navy : scheme.primary,
        shape: shape,
        textStyle: label,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(shape: shape)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: shape,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: shape,
        side: BorderSide(color: scheme.outline, width: borderWidth),
        selectedBackgroundColor: scheme.primary,
        selectedForegroundColor: scheme.onPrimary,
        textStyle: label.copyWith(fontSize: 14),
      ),
    ),
    // Tags as on the website: rounded, thin outline.
    chipTheme: ChipThemeData(
      shape: StadiumBorder(side: BorderSide(color: scheme.outline, width: borderWidth)),
      selectedColor: scheme.primary,
      checkmarkColor: scheme.onPrimary,
      secondarySelectedColor: scheme.primary,
      backgroundColor: scheme.surfaceContainerLowest,
      labelStyle: label.copyWith(color: scheme.onSurface, fontSize: 14, letterSpacing: 0.2),
      secondaryLabelStyle: label.copyWith(color: scheme.onPrimary, fontSize: 14),
      side: BorderSide(color: scheme.outline, width: borderWidth),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: OutlineInputBorder(borderRadius: radius, borderSide: edge),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.outline, width: borderWidth)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: accent, width: 2)),
    ),
    // Active item: a teal bar under the icon, like the website's main nav.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: barBg,
      indicatorColor: accent.withAlpha(light ? 22 : 40),
      indicatorShape: Border(bottom: BorderSide(color: accent, width: 3)),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => label.copyWith(
            fontSize: 12.5,
            letterSpacing: 0.3,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w400,
            color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          )),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: barBg,
      indicatorColor: accent.withAlpha(light ? 22 : 40),
      indicatorShape: Border(left: BorderSide(color: accent, width: 3)),
      selectedIconTheme: IconThemeData(color: scheme.primary),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: label.copyWith(color: scheme.primary, fontSize: 12.5),
      unselectedLabelTextStyle: label.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400, fontSize: 12.5),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: accent,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: scheme.outlineVariant,
      labelStyle: label,
      unselectedLabelStyle: label.copyWith(fontWeight: FontWeight.w400),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius, side: borderWidth > 1 ? edge : BorderSide.none),
      titleTextStyle: display(text.headlineSmall, 27),
      iconColor: accent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: scheme.outline,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(6))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius, side: edge),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: light ? AppColors.navy : scheme.inverseSurface,
      contentTextStyle: TextStyle(
        fontFamily: fontBody,
        fontSize: 15,
        color: light ? Colors.white : scheme.onInverseSurface,
      ),
      actionTextColor: light ? AppColors.gold : scheme.inversePrimary,
      shape: shape,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: light ? AppColors.charcoal : scheme.inverseSurface, borderRadius: radius),
      textStyle: TextStyle(fontFamily: fontBody, fontSize: 13, color: light ? Colors.white : scheme.onInverseSurface),
    ),
    listTileTheme: ListTileThemeData(
      shape: shape,
      titleTextStyle: text.bodyLarge?.copyWith(fontSize: 16, color: scheme.onSurface),
      subtitleTextStyle: text.bodyMedium?.copyWith(fontSize: 14, color: scheme.onSurfaceVariant),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: Colors.transparent,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      thumbColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
    ),
    badgeTheme: BadgeThemeData(backgroundColor: scheme.error, textColor: scheme.onError),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
    ),
  );
}
