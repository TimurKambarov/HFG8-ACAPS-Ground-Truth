import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

// ACAPS graphic motifs, drawn in code so they cost no bandwidth:
// - topographic contour lines (the background pattern of acaps.org),
// - the map pin with concentric rings (the ACAPS mark, also used in large
//   on the website's navy footer band),
// - the short teal bar under headings.

/// True in the high-contrast theme: decorative patterns are left out there.
bool _plain(BuildContext context) => Theme.of(context).colorScheme.outlineVariant == Colors.white;

// ---------------------------------------------------------------------------
// Topographic lines
// ---------------------------------------------------------------------------

/// Contour lines like a topographic map, filling the available space.
/// Computed once per size and seed, then cached (no image is loaded).
class TopoLines extends StatelessWidget {
  final Color color;
  final int seed;

  /// Distance in logical pixels between the hills of the pattern.
  final double scale;
  const TopoLines({super.key, required this.color, this.seed = 1, this.scale = 150});

  @override
  Widget build(BuildContext context) {
    if (_plain(context)) return const SizedBox.expand();
    return RepaintBoundary(
      child: CustomPaint(painter: _TopoPainter(color, seed, scale), size: Size.infinite),
    );
  }
}

class _TopoPainter extends CustomPainter {
  final Color color;
  final int seed;
  final double scale;
  _TopoPainter(this.color, this.seed, this.scale);

  static final _cache = <String, List<Path>>{};

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final key = '${size.width.round()}x${size.height.round()}/$seed/$scale';
    final paths = _cache[key] ??= _contours(size, seed, scale);
    if (_cache.length > 24) _cache.remove(_cache.keys.first);
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..color = color;
    // Every fourth line is an "index contour": slightly heavier, as on a map.
    final thick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var i = 0; i < paths.length; i++) {
      canvas.drawPath(paths[i], i % 4 == 0 ? thick : thin);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TopoPainter old) => old.color != color || old.seed != seed || old.scale != scale;

  /// Marching squares over a smooth random field: one path per height level.
  static List<Path> _contours(Size size, int seed, double scale) {
    final rnd = math.Random(seed);
    // A few long waves in random directions: their interference makes the
    // closed, organic loops of a contour map.
    final waves = [
      for (var k = 0; k < 5; k++)
        (
          fx: (rnd.nextDouble() * 2 - 1) * (0.6 + k * 0.25),
          fy: (rnd.nextDouble() * 2 - 1) * (0.6 + k * 0.25),
          p: rnd.nextDouble() * math.pi * 2,
          a: 1.0 / (1 + k * 0.55),
        ),
    ];
    double f(double x, double y) {
      final u = x / scale * math.pi, v = y / scale * math.pi;
      var s = 0.0;
      for (final w in waves) {
        s += w.a * math.sin(w.fx * u + w.fy * v + w.p);
      }
      // Gentle warp so lines are not too regular.
      return s + 0.35 * math.sin(u * 0.9 + math.cos(v * 0.7 + seed));
    }

    const cell = 7.0;
    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;
    final grid = List.generate(rows + 1, (j) => List.generate(cols + 1, (i) => f(i * cell, j * cell)));

    final paths = <Path>[];
    const step = 0.24;
    for (var level = -2.4; level <= 2.4; level += step) {
      final p = Path();
      for (var j = 0; j < rows; j++) {
        for (var i = 0; i < cols; i++) {
          final a = grid[j][i], b = grid[j][i + 1], c = grid[j + 1][i + 1], d = grid[j + 1][i];
          final idx = (a > level ? 8 : 0) | (b > level ? 4 : 0) | (c > level ? 2 : 0) | (d > level ? 1 : 0);
          if (idx == 0 || idx == 15) continue;
          final x = i * cell, y = j * cell;
          double t(double p, double q) => (level - p) / (q - p);
          final top = Offset(x + cell * t(a, b), y);
          final right = Offset(x + cell, y + cell * t(b, c));
          final bottom = Offset(x + cell * t(d, c), y + cell);
          final left = Offset(x, y + cell * t(a, d));
          void seg(Offset m, Offset n) => p
            ..moveTo(m.dx, m.dy)
            ..lineTo(n.dx, n.dy);
          final centreHigh = (a + b + c + d) / 4 > level;
          switch (idx) {
            case 1 || 14:
              seg(left, bottom);
            case 2 || 13:
              seg(bottom, right);
            case 3 || 12:
              seg(left, right);
            case 4 || 11:
              seg(top, right);
            case 6 || 9:
              seg(top, bottom);
            case 7 || 8:
              seg(top, left);
            case 5:
              if (centreHigh) {
                seg(top, left);
                seg(bottom, right);
              } else {
                seg(top, right);
                seg(left, bottom);
              }
            case 10:
              if (centreHigh) {
                seg(top, right);
                seg(left, bottom);
              } else {
                seg(top, left);
                seg(bottom, right);
              }
          }
        }
      }
      paths.add(p);
    }
    return paths;
  }
}

// ---------------------------------------------------------------------------
// Map pin
// ---------------------------------------------------------------------------

/// The ACAPS map pin: a teardrop with a ring cut out and a dot in the middle.
/// [height] is the full height; the width is 5/6 of it.
class PinMark extends StatelessWidget {
  final double height;
  final Color color;

  /// Colour of the centre dot (defaults to [color]).
  final Color? dotColor;
  const PinMark({super.key, this.height = 28, required this.color, this.dotColor});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: height * 90 / 108,
        height: height,
        child: CustomPaint(painter: _PinPainter(color, dotColor ?? color)),
      );
}

class _PinPainter extends CustomPainter {
  final Color color;
  final Color dot;
  _PinPainter(this.color, this.dot);

  @override
  void paint(Canvas canvas, Size size) {
    // Geometry of a 90 x 108 pin: circle r 45 around (45, 45), tip at (45, 108),
    // ring hole r 31, dot r 17 (the proportions of the ACAPS mark).
    final k = size.height / 108;
    canvas.scale(k);
    const c = Offset(45, 45);
    const r = 45.0;
    const tip = Offset(45, 108);
    final phi = math.acos(r / (tip.dy - c.dy)); // tangent angle from the downward axis
    final left = Offset(c.dx - r * math.sin(phi), c.dy + r * math.cos(phi));
    final start = math.atan2(left.dy - c.dy, left.dx - c.dx);
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: r), start, 2 * math.pi - 2 * (start - math.pi / 2), false)
      ..close()
      ..addOval(Rect.fromCircle(center: c, radius: 31));
    canvas.drawPath(ring, Paint()..color = color);
    canvas.drawCircle(c, 17, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.color != color || old.dot != dot;
}

// ---------------------------------------------------------------------------
// Headings
// ---------------------------------------------------------------------------

/// The short teal bar under ACAPS headings.
class AccentBar extends StatelessWidget {
  final double width;
  final Color? color;
  const AccentBar({super.key, this.width = 44, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? (cs.brightness == Brightness.light ? AppColors.teal : cs.primary);
    // Aligned so it keeps its width inside lists that stretch their children.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox(width: width, height: 3, child: ColoredBox(color: c)),
    );
  }
}

/// Small all-caps label above a title ("R1043 · CHAD", "NEW ANALYSIS").
class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  final int maxLines;
  const Eyebrow(this.text, {super.key, this.color, this.maxLines = 1});

  static TextStyle style(BuildContext context, {Color? color}) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(
      fontFamily: fontBody,
      fontSize: 12,
      height: 1.3,
      letterSpacing: 1.1,
      fontWeight: FontWeight.w700,
      color: color ?? (cs.brightness == Brightness.light ? AppColors.tealText : cs.primary),
    );
  }

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style(context, color: color),
      );
}

// ---------------------------------------------------------------------------
// Navy header band
// ---------------------------------------------------------------------------

/// Navy band at the top of a page, with contour lines and a large pin cut
/// off at the edge (like the website's footer band). White text.
class BrandHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final String? subtitle;

  /// Shown at the end of the eyebrow row (e.g. icon buttons).
  final List<Widget> actions;

  /// Extra content under the title (search field, profile pills...).
  final List<Widget> children;

  /// Varies the contour pattern between pages.
  final int seed;
  final bool showPin;
  final double titleSize;

  const BrandHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.actions = const [],
    this.children = const [],
    this.seed = 1,
    this.showPin = true,
    this.titleSize = 38,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final plain = _plain(context);
    final bg = plain ? Colors.black : (cs.brightness == Brightness.light ? AppColors.navy : AppColors.navyNight);
    final top = MediaQuery.paddingOf(context).top;
    const fg = Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: plain ? const Border(bottom: BorderSide(color: Colors.white, width: 2)) : null,
      ),
      child: Stack(
        children: [
          Positioned.fill(child: TopoLines(color: Colors.white.withAlpha(30), seed: seed)),
          if (showPin && !plain)
            Positioned(
              right: -36,
              bottom: -54,
              child: PinMark(height: 190, color: Colors.white.withAlpha(20), dotColor: AppColors.teal.withAlpha(60)),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 14, 12, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: eyebrow == null
                          ? const SizedBox(height: 40)
                          : Row(
                              children: [
                                PinMark(height: 18, color: AppColors.tealBright, dotColor: fg),
                                const SizedBox(width: 8),
                                Flexible(child: Eyebrow(eyebrow!, color: fg.withAlpha(225))),
                              ],
                            ),
                    ),
                    // White icon buttons on the navy band (only here: the
                    // theme would otherwise also recolour field icons).
                    IconButtonTheme(
                      data: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: fg)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    title,
                    style: TextStyle(fontFamily: fontDisplay, fontSize: titleSize, height: 1.0, letterSpacing: 0.6, color: fg),
                  ),
                ),
                const SizedBox(height: 10),
                AccentBar(color: plain ? fg : AppColors.tealBright),
                if (subtitle != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(subtitle!, style: TextStyle(fontSize: 15.5, height: 1.45, color: fg.withAlpha(225))),
                  ),
                ],
                if (children.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A scrolling page: [header] full width, then [children] with side padding.
class BrandPage extends StatelessWidget {
  final Widget header;
  final List<Widget> children;
  const BrandPage({super.key, required this.header, required this.children});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          header,
          for (final c in children) Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: c),
        ],
      );
}

// ---------------------------------------------------------------------------
// Key figures
// ---------------------------------------------------------------------------

/// A big Bebas number with a short label under it ("12 / forecasts").
class KeyFigure extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  final Widget? note;
  final CrossAxisAlignment align;
  const KeyFigure(
      {super.key, required this.value, required this.label, this.color, this.note, this.align = CrossAxisAlignment.center});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
              fontFamily: fontDisplay,
              fontSize: 36,
              height: 1.0,
              color: color ?? (cs.brightness == Brightness.light ? AppColors.navy : cs.primary),
            )),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: align == CrossAxisAlignment.center ? TextAlign.center : TextAlign.start,
          style:
              TextStyle(fontSize: 13, height: 1.25, letterSpacing: 0.3, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
        ),
        if (note != null) ...[const SizedBox(height: 3), note!],
      ],
    );
  }
}
