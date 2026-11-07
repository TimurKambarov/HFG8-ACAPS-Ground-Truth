import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'store.dart';

// ACAPS visual identity (acaps.org), adapted for an app.
//
// Light theme follows the website: white header, light-grey page bands,
// teal for anything you can tap, deep navy for large blocks, crimson only for
// risk/alerts, and the yellow-green lime as a rare accent.
// Dark and high-contrast themes are not on the website; they are derived from
// the same navy / teal / lime so the app still reads as ACAPS.
//
// Low-bandwidth rules: no web fonts, no images, no shadows; everything here
// is plain colour and borders, so nothing extra is downloaded.
//
// Public names (AppColors.*, scaleColors, levelColor, buildTheme,
// buildContrastTheme) are used by the screens - keep them when editing.

class AppColors {
  // --- Brand --------------------------------------------------------------
  /// ACAPS deep navy: quote blocks, banners, hero.
  static const navy = Color(0xFF004A7C);

  /// Darker navy for gradients and dark surfaces.
  static const navyDeep = Color(0xFF062A47);

  /// ACAPS teal as on the website buttons ("Contact us", "Donate").
  /// Decorative use only (stripes, underlines): white text on it is < 4.5:1.
  static const teal = Color(0xFF0093B7);

  /// Teal darkened just enough for white text / text on white (AA 4.5:1).
  static const tealDeep = Color(0xFF007FA3);

  /// Teal for dark backgrounds.
  static const tealBright = Color(0xFF4CC6E6);

  /// ACAPS crimson (risk radar "High", "Risk radar" banner).
  static const crimson = Color(0xFFB3123A);

  /// ACAPS yellow-green ("We are hiring"). Use sparingly.
  static const lime = Color(0xFFC8D200);

  /// Lime darkened so it is visible on white (icons, borders).
  static const limeDeep = Color(0xFF8A9400);

  /// Text colour on light backgrounds.
  static const text = Color(0xFF1D1D1B);

  /// Light grey band (breadcrumb bar / tab bar on the website).
  static const band = Color(0xFFF2F3F4);

  // --- Names used by the screens (kept for compatibility) -----------------
  static const ink = navyDeep;
  static const primary = navy;
  static const primaryDark = tealBright;
  static const accent = lime;
  static const paper = band;
  static const paperDark = Color(0xFF0A1724);
  static const cardDark = Color(0xFF102235);

  /// Risk levels follow the ACAPS Risk Radar legend (crimson / coral / rose),
  /// tuned so the text stays readable on light and dark cards.
  static const high = crimson;
  static const medium = Color(0xFFDE4A5A);
  static const low = Color(0xFFC2707A);
}

/// One colour per step of the ACAPS probability scale (very low -> very high).
/// Teal -> blue -> ACAPS severity purple -> magenta -> crimson; every step
/// carries white text.
const scaleColors = [
  Color(0xFF2E8CA8),
  Color(0xFF2D6E96),
  Color(0xFF7A58A8),
  Color(0xFFB0306A),
  Color(0xFFB3123A),
];

/// Risk level colour for the theme currently in use: the light-theme crimson
/// is unreadable as text on navy/black, so dark themes get lighter tones.
Color levelColor(String level) {
  final dark = _darkInUse;
  return switch (level) {
    'High' => dark ? const Color(0xFFFF5577) : AppColors.high,
    'Medium' => dark ? const Color(0xFFFF8F7A) : AppColors.medium,
    'Low' => dark ? const Color(0xFFE8B4B8) : AppColors.low,
    _ => dark ? const Color(0xFFA3B6C7) : const Color(0xFF8A8F94),
  };
}

bool get _darkInUse => switch (appState.theme) {
      AppTheme.light => false,
      AppTheme.dark || AppTheme.contrast => true,
      AppTheme.system => ui.PlatformDispatcher.instance.platformBrightness == Brightness.dark,
    };

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = dark ? _darkScheme : _lightScheme;
  return _themeFrom(scheme, appBarBg: dark ? AppColors.paperDark : Colors.white);
}

/// High contrast: black background, white text, ACAPS teal and lime
/// brightened to the maximum, 2px outlines everywhere.
ThemeData buildContrastTheme() => _themeFrom(_contrastScheme, borderWidth: 2, appBarBg: Colors.black);

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.tealDeep,
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFD5EEF5),
  onPrimaryContainer: Color(0xFF003A4D),
  secondary: AppColors.navy,
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFDCE8F2),
  onSecondaryContainer: Color(0xFF002A47),
  tertiary: AppColors.limeDeep,
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFF2F5C2),
  onTertiaryContainer: Color(0xFF2E3300),
  error: AppColors.crimson,
  onError: Colors.white,
  errorContainer: Color(0xFFFBE3E8),
  onErrorContainer: Color(0xFF5C0019),
  surface: AppColors.band,
  onSurface: AppColors.text,
  onSurfaceVariant: Color(0xFF55616B),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color(0xFFF8F9FA),
  surfaceContainer: Colors.white,
  surfaceContainerHigh: Colors.white,
  surfaceContainerHighest: Color(0xFFE6EAED),
  outline: Color(0xFF8A959E),
  outlineVariant: Color(0xFFD9DEE2),
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
  onPrimary: Color(0xFF00202B),
  primaryContainer: Color(0xFF00506A),
  onPrimaryContainer: Color(0xFFC5EEFA),
  secondary: Color(0xFF8FC1E8),
  onSecondary: Color(0xFF002640),
  secondaryContainer: Color(0xFF13406A),
  onSecondaryContainer: Color(0xFFD6E9F8),
  tertiary: AppColors.lime,
  onTertiary: Color(0xFF1F2300),
  tertiaryContainer: Color(0xFF3B4100),
  onTertiaryContainer: Color(0xFFEEF39A),
  error: Color(0xFFFF7088),
  onError: Color(0xFF3F0010),
  errorContainer: Color(0xFF5E0A22),
  onErrorContainer: Color(0xFFFFD9DF),
  surface: AppColors.paperDark,
  onSurface: Color(0xFFE6EEF4),
  onSurfaceVariant: Color(0xFFA3B6C7),
  surfaceContainerLowest: AppColors.cardDark,
  surfaceContainerLow: Color(0xFF132840),
  surfaceContainer: Color(0xFF132840),
  surfaceContainerHigh: Color(0xFF173049),
  surfaceContainerHighest: Color(0xFF203D59),
  outline: Color(0xFF5F7A92),
  outlineVariant: Color(0xFF26425E),
  inverseSurface: Color(0xFFE6EEF4),
  onInverseSurface: AppColors.navyDeep,
  inversePrimary: AppColors.tealDeep,
  shadow: Colors.black,
  scrim: Colors.black,
  surfaceTint: Colors.transparent,
);

const _contrastScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF5AD7FF),
  onPrimary: Colors.black,
  primaryContainer: Color(0xFF003344),
  onPrimaryContainer: Colors.white,
  secondary: Colors.white,
  onSecondary: Colors.black,
  secondaryContainer: Color(0xFF1F1F1F),
  onSecondaryContainer: Colors.white,
  tertiary: Color(0xFFE4EE2A),
  onTertiary: Colors.black,
  tertiaryContainer: Color(0xFF2B2E00),
  onTertiaryContainer: Colors.white,
  error: Color(0xFFFF7A90),
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
  inversePrimary: AppColors.tealDeep,
  shadow: Colors.black,
  scrim: Colors.black,
  surfaceTint: Colors.transparent,
);

/// Condensed system font: Roboto Condensed on Android (close to the ACAPS
/// website type) with no download; other platforms use their default font.
const _condensed = 'sans-serif-condensed';

ThemeData _themeFrom(ColorScheme scheme, {double borderWidth = 1, required Color appBarBg}) {
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final text = base.textTheme;
  // Derive from the theme so buttons, chips and tabs keep the theme font.
  final label = text.labelLarge!;
  final heading = scheme.brightness == Brightness.light ? AppColors.text : scheme.onSurface;

  // The website is rectangular: square buttons, cards with a sharp edge.
  const radius = BorderRadius.all(Radius.circular(4));
  const shape = RoundedRectangleBorder(borderRadius: radius);
  final edge = BorderSide(color: scheme.outlineVariant, width: borderWidth);

  TextStyle? display(TextStyle? s, double spacing) => s?.copyWith(
        fontFamily: _condensed,
        fontWeight: FontWeight.w900,
        letterSpacing: spacing,
        height: 1.1,
        color: heading,
      );

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkRipple.splashFactory,
    textTheme: text.copyWith(
      displaySmall: display(text.displaySmall, -0.5),
      headlineLarge: display(text.headlineLarge, -0.5),
      headlineMedium: display(text.headlineMedium, -0.4),
      headlineSmall: display(text.headlineSmall, -0.2),
      titleLarge: text.titleLarge?.copyWith(fontFamily: _condensed, fontWeight: FontWeight.w800, height: 1.25),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
      bodyLarge: text.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.5),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: appBarBg,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: edge),
      titleTextStyle: text.titleLarge?.copyWith(
        fontFamily: _condensed,
        fontWeight: FontWeight.w900,
        color: scheme.brightness == Brightness.light ? AppColors.navy : scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius, side: edge),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: shape,
        textStyle: label.copyWith(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(elevation: 0, shape: shape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.brightness == Brightness.light ? AppColors.navy : scheme.primary,
        side: BorderSide(
          color: scheme.brightness == Brightness.light ? AppColors.navy : scheme.primary,
          width: borderWidth == 1 ? 1.5 : borderWidth,
        ),
        shape: shape,
        textStyle: label.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: shape, textStyle: label.copyWith(fontWeight: FontWeight.w700)),
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
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: scheme.outlineVariant, width: borderWidth)),
      selectedColor: scheme.primary,
      checkmarkColor: scheme.onPrimary,
      secondarySelectedColor: scheme.primary,
      labelStyle: label.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600),
      secondaryLabelStyle: label.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700),
      side: BorderSide(color: scheme.outlineVariant, width: borderWidth),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: OutlineInputBorder(borderRadius: radius, borderSide: edge),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.outline.withAlpha(140), width: borderWidth)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.primary, width: 2)),
    ),
    // Active item gets a teal underline-style indicator, like the website nav.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: appBarBg,
      indicatorColor: scheme.primary.withAlpha(scheme.brightness == Brightness.light ? 28 : 50),
      indicatorShape: shape,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => label.copyWith(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          )),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: appBarBg,
      indicatorColor: scheme.primary.withAlpha(scheme.brightness == Brightness.light ? 28 : 50),
      indicatorShape: shape,
      selectedIconTheme: IconThemeData(color: scheme.primary),
      selectedLabelTextStyle: label.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: scheme.outlineVariant,
      labelStyle: label.copyWith(fontWeight: FontWeight.w800),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius, side: borderWidth > 1 ? edge : BorderSide.none),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.brightness == Brightness.light ? AppColors.navy : scheme.inverseSurface,
      contentTextStyle: label.copyWith(
        color: scheme.brightness == Brightness.light ? Colors.white : scheme.onInverseSurface,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: scheme.brightness == Brightness.light ? AppColors.lime : scheme.inversePrimary,
      shape: shape,
    ),
    listTileTheme: const ListTileThemeData(shape: shape),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      thumbColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
    ),
  );
}
