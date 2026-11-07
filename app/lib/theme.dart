// =============================================================================
// Design system: "field instrument"
// =============================================================================
//
// Three rules give the app its look:
//
//   1. The interface is monochrome: paper and ink. Colour is reserved for
//      DATA, so whatever is coloured means something.
//   2. ACAPS's probability scale is a heat ramp, from pale sand (very low)
//      to oxblood (very high). Lightness rises with the step, so it still
//      reads in greyscale and for colour-blind readers.
//   3. People are dots, never faces or names. Other experts are grey dots;
//      YOU are the blue dot, like "you are here" on a map; ACAPS is an ink
//      square. The same three marks appear on every chart.
//
// Type: Atkinson Hyperlegible, designed by the Braille Institute for readers
// with low vision. Next for text, Mono for numbers, IDs and labels. Both are
// bundled (assets/fonts), so the app needs no font download in the field.
// Corners are square; buttons are solid ink slabs.
// =============================================================================

import 'package:flutter/material.dart';

/// Font families bundled in assets/fonts (see pubspec.yaml).
const fontText = 'AtkinsonNext';
const fontMono = 'AtkinsonMono';

class AppColors {
  // --- Light: paper and ink ---
  static const paper = Color(0xFFEFEFEA); // background: cool stone, not cream
  static const sheet = Color(0xFFFAFAF7); // cards and sheets
  static const ink = Color(0xFF111315); // text, slabs, rules
  static const inkSoft = Color(0xFF51575D); // secondary text (6.4:1 on paper)
  static const rule = Color(0xFFD2D3CC); // hairlines and empty tracks
  static const you = Color(0xFF2B5BFF); // the signed-in expert, everywhere

  // --- Dark: night ---
  static const night = Color(0xFF0C0E10);
  static const nightSheet = Color(0xFF16191C);
  static const nightInk = Color(0xFFEFEFE9);
  static const nightSoft = Color(0xFFA3A9AE);
  static const nightRule = Color(0xFF2B3035);
  static const youNight = Color(0xFF7D96FF);

  // --- Data: risk level and the direction of a gap ---
  static const high = Color(0xFFC8402B); // = heat step 4
  static const medium = Color(0xFFE57A32); // = heat step 3
  static const low = Color(0xFF3E7C8F); // experts lower than ACAPS: a cool slate

  /// Kept for older call sites: the brand "primary" is ink.
  static const primary = ink;
}

/// ACAPS probability scale as a heat ramp: very low -> very high.
/// Lightness falls step by step, so the order survives greyscale.
const scaleColors = [
  Color(0xFFE8D7B0), // 1 very low  <10%   pale sand
  Color(0xFFF0B445), // 2 low       10-33% amber
  Color(0xFFE57A32), // 3 medium    34-66% orange
  Color(0xFFC8402B), // 4 high      67-90% vermilion
  Color(0xFF8E1F33), // 5 very high >90%   oxblood
];

/// Text colour that reads on a heat step.
Color onScale(int step) => step >= 4 ? Colors.white : AppColors.ink;

Color levelColor(String level) => switch (level) {
      'High' => AppColors.high,
      'Medium' => AppColors.medium,
      'Low' => scaleColors[1],
      _ => const Color(0xFF8A8F94),
    };

/// The signed-in expert's colour: the blue "you are here" dot.
Color youColor(BuildContext context) => Theme.of(context).colorScheme.secondary;

/// Monospaced label style (IDs, numbers, eyebrows).
TextStyle mono(double size, {FontWeight weight = FontWeight.w500, Color? color, double spacing = 0.6}) =>
    TextStyle(fontFamily: fontMono, fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing, height: 1.25);

/// High contrast: black, white, and a yellow "you".
ThemeData buildContrastTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Colors.white,
    onPrimary: Colors.black,
    secondary: Color(0xFFFFE14D),
    onSecondary: Colors.black,
    secondaryContainer: Color(0xFF2A2A2A),
    onSecondaryContainer: Colors.white,
    tertiary: Color(0xFFFFE14D),
    onTertiary: Colors.black,
    error: Color(0xFFFF6B5B),
    onError: Colors.black,
    errorContainer: Color(0xFF5A0000),
    onErrorContainer: Colors.white,
    surface: Colors.black,
    onSurface: Colors.white,
    onSurfaceVariant: Colors.white,
    surfaceContainerLowest: Colors.black,
    surfaceContainerLow: Color(0xFF0A0A0A),
    surfaceContainer: Color(0xFF141414),
    surfaceContainerHigh: Color(0xFF1E1E1E),
    surfaceContainerHighest: Color(0xFF2A2A2A),
    outline: Colors.white,
    outlineVariant: Colors.white,
    inverseSurface: Colors.white,
    onInverseSurface: Colors.black,
    inversePrimary: Colors.black,
  );
  return _themeFrom(scheme, borderWidth: 2, navBg: Colors.black);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    // Ink is the brand: buttons, rules, icons. No coloured primary.
    primary: dark ? AppColors.nightInk : AppColors.ink,
    onPrimary: dark ? AppColors.night : AppColors.paper,
    primaryContainer: dark ? AppColors.nightRule : AppColors.rule,
    onPrimaryContainer: dark ? AppColors.nightInk : AppColors.ink,
    // "You": the one colour that is not data. Tonal buttons and other
    // "secondary containers" stay neutral, so blue only ever means you.
    secondary: dark ? AppColors.youNight : AppColors.you,
    onSecondary: dark ? AppColors.night : Colors.white,
    secondaryContainer: dark ? AppColors.nightRule : AppColors.rule,
    onSecondaryContainer: dark ? AppColors.nightInk : AppColors.ink,
    tertiaryContainer: dark ? AppColors.nightRule : AppColors.rule,
    onTertiaryContainer: dark ? AppColors.nightInk : AppColors.ink,
    tertiary: dark ? AppColors.nightInk : AppColors.ink,
    onTertiary: dark ? AppColors.night : AppColors.paper,
    error: dark ? const Color(0xFFE8604A) : AppColors.high,
    onError: Colors.white,
    errorContainer: dark ? const Color(0xFF3A1610) : const Color(0xFFF5DDD6),
    onErrorContainer: dark ? const Color(0xFFFFD9D0) : const Color(0xFF5A140B),
    surface: dark ? AppColors.night : AppColors.paper,
    onSurface: dark ? AppColors.nightInk : AppColors.ink,
    onSurfaceVariant: dark ? AppColors.nightSoft : AppColors.inkSoft,
    surfaceContainerLowest: dark ? AppColors.nightSheet : AppColors.sheet,
    surfaceContainerLow: dark ? AppColors.nightSheet : AppColors.sheet,
    surfaceContainer: dark ? const Color(0xFF1C2024) : const Color(0xFFE7E7E1),
    surfaceContainerHigh: dark ? const Color(0xFF22272B) : const Color(0xFFE2E2DB),
    surfaceContainerHighest: dark ? const Color(0xFF292E33) : const Color(0xFFDADAD3),
    outline: dark ? AppColors.nightInk : AppColors.ink,
    outlineVariant: dark ? AppColors.nightRule : AppColors.rule,
    inverseSurface: dark ? AppColors.nightInk : AppColors.ink,
    onInverseSurface: dark ? AppColors.night : AppColors.paper,
    inversePrimary: dark ? AppColors.night : AppColors.paper,
  );
  return _themeFrom(scheme, navBg: dark ? const Color(0xFF050607) : AppColors.ink);
}

ThemeData _themeFrom(ColorScheme scheme, {double borderWidth = 1.5, required Color navBg}) {
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: fontText);
  final ink = scheme.onSurface;
  final soft = scheme.onSurfaceVariant;
  final paper = scheme.surface;
  const square = RoundedRectangleBorder();
  final heavy = BorderSide(color: ink, width: 2);
  final text = base.textTheme;
  // Navigation sits on an ink (or black) bar in every theme.
  const navInk = Color(0xFFEFEFE9);

  TextStyle? t(TextStyle? s, double size, FontWeight w, {double spacing = 0, double height = 1.2, Color? color}) =>
      s?.copyWith(fontSize: size, fontWeight: w, letterSpacing: spacing, height: height, color: color ?? ink);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkRipple.splashFactory,
    textTheme: text.copyWith(
      displaySmall: t(text.displaySmall, 44, FontWeight.w800, spacing: -1.2, height: 1.02),
      headlineLarge: t(text.headlineLarge, 38, FontWeight.w800, spacing: -1.0, height: 1.05),
      headlineMedium: t(text.headlineMedium, 33, FontWeight.w800, spacing: -0.8, height: 1.08),
      headlineSmall: t(text.headlineSmall, 28, FontWeight.w800, spacing: -0.6, height: 1.1),
      titleLarge: t(text.titleLarge, 21, FontWeight.w800, spacing: -0.3, height: 1.22),
      titleMedium: t(text.titleMedium, 17, FontWeight.w700, height: 1.3),
      titleSmall: t(text.titleSmall, 15, FontWeight.w700, height: 1.3),
      bodyLarge: t(text.bodyLarge, 17, FontWeight.w400, height: 1.45),
      bodyMedium: t(text.bodyMedium, 15.5, FontWeight.w400, height: 1.45),
      bodySmall: t(text.bodySmall, 13.5, FontWeight.w400, height: 1.4, color: soft),
      labelLarge: t(text.labelLarge, 15, FontWeight.w700, spacing: 0.1),
      labelMedium: text.labelMedium?.merge(mono(12.5, color: ink)),
      labelSmall: text.labelSmall?.merge(mono(11, color: soft, spacing: 1.0)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 4,
      // A ruled header, like the top of an instrument panel.
      shape: Border(bottom: BorderSide(color: ink, width: 2)),
      titleTextStyle: mono(14.5, weight: FontWeight.w700, color: ink, spacing: 0.8),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: borderWidth > 1.5 ? RoundedRectangleBorder(side: BorderSide(color: ink, width: borderWidth)) : square,
    ),
    // Primary action: a solid ink slab.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.outlineVariant,
        disabledForegroundColor: soft,
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: square,
        textStyle: const TextStyle(fontFamily: fontText, fontWeight: FontWeight.w800, fontSize: 16.5, letterSpacing: 0.1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(elevation: 0, shape: square)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size(56, 48),
        side: heavy,
        shape: square,
        textStyle: const TextStyle(fontFamily: fontText, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    // Text actions are underlined words, not floating labels.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ink,
        shape: square,
        textStyle: TextStyle(
          fontFamily: fontText,
          fontWeight: FontWeight.w700,
          fontSize: 15,
          decoration: TextDecoration.underline,
          decorationThickness: 2,
          decorationColor: ink,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(shape: square, foregroundColor: ink)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: square,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: square,
        side: heavy,
        foregroundColor: ink,
        selectedBackgroundColor: scheme.primary,
        selectedForegroundColor: scheme.onPrimary,
        textStyle: const TextStyle(fontFamily: fontText, fontWeight: FontWeight.w700, fontSize: 14.5),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(side: BorderSide(color: ink, width: 1.5)),
      side: BorderSide(color: ink, width: 1.5),
      backgroundColor: scheme.surfaceContainerLowest,
      selectedColor: scheme.primary,
      checkmarkColor: scheme.onPrimary,
      labelStyle: TextStyle(fontFamily: fontText, fontWeight: FontWeight.w700, fontSize: 13.5, color: ink),
      secondaryLabelStyle: TextStyle(fontFamily: fontText, fontWeight: FontWeight.w700, fontSize: 13.5, color: scheme.onPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    ),
    // Fields are a line to write on, not a box.
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: UnderlineInputBorder(borderSide: BorderSide(color: soft, width: 1.5)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: soft, width: 1.5)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: ink, width: 3)),
      disabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5)),
      labelStyle: TextStyle(color: soft, fontWeight: FontWeight.w500),
      floatingLabelStyle: mono(13, weight: FontWeight.w700, color: ink, spacing: 0.8),
      hintStyle: TextStyle(color: soft),
      prefixIconColor: ink,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
    ),
    // The tab bar is an ink panel in every theme; the current tab gets a bar.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: navBg,
      indicatorColor: navInk,
      indicatorShape: const _BarIndicator(),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => mono(
            11.5,
            weight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? navInk : navInk.withAlpha(150),
            spacing: 0.4,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? navInk : navInk.withAlpha(150),
            size: 24,
          )),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: navBg,
      indicatorColor: navInk,
      indicatorShape: const _BarIndicator(),
      selectedIconTheme: const IconThemeData(color: navInk),
      unselectedIconTheme: IconThemeData(color: navInk.withAlpha(150)),
      selectedLabelTextStyle: mono(12, weight: FontWeight.w700, color: navInk),
      unselectedLabelTextStyle: mono(12, color: navInk.withAlpha(150)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: ink,
      unselectedLabelColor: soft,
      indicatorColor: ink,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: scheme.outlineVariant,
      labelStyle: const TextStyle(fontFamily: fontText, fontWeight: FontWeight.w800),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(side: BorderSide(color: ink, width: 2)),
      titleTextStyle: TextStyle(fontFamily: fontText, fontWeight: FontWeight.w800, fontSize: 22, color: ink, height: 1.2),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: Border(top: BorderSide(color: ink, width: 2)),
      dragHandleColor: ink,
      dragHandleSize: const Size(44, 4),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(fontFamily: fontText, color: scheme.onInverseSurface, fontWeight: FontWeight.w500, fontSize: 14.5),
      actionTextColor: scheme.brightness == Brightness.dark ? AppColors.you : const Color(0xFF9DB2FF),
      shape: square,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: scheme.inverseSurface),
      textStyle: TextStyle(fontFamily: fontText, color: scheme.onInverseSurface, fontSize: 13),
    ),
    badgeTheme: BadgeThemeData(backgroundColor: scheme.error, textColor: Colors.white),
    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(),
      side: BorderSide(color: ink, width: 2),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? ink : Colors.transparent),
      checkColor: WidgetStatePropertyAll(paper),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? paper : soft),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? ink : scheme.outlineVariant),
      trackOutlineColor: WidgetStatePropertyAll(ink.withAlpha(0)),
    ),
    listTileTheme: const ListTileThemeData(shape: square),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: ink, linearTrackColor: scheme.outlineVariant),
    sliderTheme: SliderThemeData(activeTrackColor: ink, thumbColor: ink, inactiveTrackColor: scheme.outlineVariant, trackHeight: 3),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
    expansionTileTheme: const ExpansionTileThemeData(shape: Border(), collapsedShape: Border()),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(side: BorderSide(color: ink, width: 1.5))),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLowest),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(side: BorderSide(color: ink, width: 1.5)),
      color: scheme.surfaceContainerLowest,
    ),
  );
}

/// Navigation indicator: a short bar under the icon instead of a pill.
class _BarIndicator extends ShapeBorder {
  const _BarIndicator();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  Rect _bar(Rect r) => Rect.fromLTWH(r.left + r.width * 0.28, r.bottom - 3, r.width * 0.44, 3);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(_bar(rect));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(_bar(rect));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}
