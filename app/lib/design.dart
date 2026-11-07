// =============================================================================
// Signature components of the "field instrument" design (see theme.dart).
// =============================================================================
//
//   Eyebrow        "— TRIGGER 1 OF 3": mono label with a short ink rule.
//   IsoCode        "TCD SDN": the risk's countries as big ISO codes.
//   HeatChip       ACAPS probability as a heat-coloured tag.
//   Pips           impact 1-5 as five squares.
//   PanelDots      one dot per panel member: answered, not yet, you.
//   HeatScale      ACAPS's five-step scale. As an input it is the forecast
//                  picker; as a chart every answer is a dot above it, with
//                  the group (median and middle half), ACAPS and YOU marked.
//   SeverityPicker "How bad would it be?" as signal-strength bars.
//   AgreePicker    Yes / Partly / No as three big square keys.
//   AnonymityRings how far your name travels: you at the centre, then
//                  ACAPS, colleagues, other countries, the public.
//   SegmentProgress the survey's progress as separate blocks.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------
// Labels and codes
// ---------------------------------------------------------------------------

/// Mono uppercase label with a short ink rule in front.
class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const Eyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Container(width: 14, height: 2.5, color: c),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: mono(11.5, weight: FontWeight.w700, color: c, spacing: 1.4))),
      ],
    );
  }
}

/// ISO3 codes of a risk's countries ("TCD SDN"); falls back to the first
/// three letters of each country name.
String isoCodes(Risk r) {
  final iso = r.iso.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  if (iso.isNotEmpty) return iso.take(4).join(' ');
  return r.country
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .map((s) => s.length <= 3 ? s.toUpperCase() : s.substring(0, 3).toUpperCase())
      .take(4)
      .join(' ');
}

class IsoCode extends StatelessWidget {
  final Risk risk;
  final double size;
  final Color? color;
  const IsoCode(this.risk, {super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) => Text(
        isoCodes(risk),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: mono(size, weight: FontWeight.w700, color: color ?? Theme.of(context).colorScheme.onSurface, spacing: 0.5),
      );
}

/// ACAPS probability as a heat tag: "HIGH 67–90%".
class HeatChip extends StatelessWidget {
  final int? step; // 1..5
  final bool showRange;
  const HeatChip(this.step, {super.key, this.showRange = true});

  @override
  Widget build(BuildContext context) {
    final s = step;
    if (s == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.onSurfaceVariant, width: 1.5)),
        child: Text('UNRATED', style: mono(11, weight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant, spacing: 1)),
      );
    }
    final fg = onScale(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: scaleColors[s - 1],
      child: Text(
        showRange ? '${levelLabels[s - 1].toUpperCase()} ${probabilityRanges[s - 1]}' : levelLabels[s - 1].toUpperCase(),
        style: mono(11, weight: FontWeight.w700, color: fg, spacing: 0.8),
      ),
    );
  }
}

/// Impact 1-5 as five squares, filled up to [value].
class Pips extends StatelessWidget {
  final int? value;
  final double size;
  const Pips(this.value, {super.key, this.size = 9});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Container(
            width: size,
            height: size,
            margin: EdgeInsets.only(right: i < 5 ? 3 : 0),
            decoration: BoxDecoration(
              color: value != null && i <= value! ? cs.onSurface : Colors.transparent,
              border: Border.all(color: cs.onSurface, width: 1.5),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// People as dots
// ---------------------------------------------------------------------------

/// One dot per panel member: answered (ink), not yet (hollow), you (blue).
class PanelDots extends StatelessWidget {
  final int total;
  final int answered;

  /// The signed-in expert answered: one answered dot is blue.
  final bool youAnswered;
  final double size;
  final Color? ink;
  const PanelDots({super.key, required this.total, required this.answered, this.youAnswered = false, this.size = 9, this.ink});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = ink ?? cs.onSurface;
    final you = youColor(context);
    final shown = math.min(total, 24);
    return Wrap(
      spacing: 3.5,
      runSpacing: 3.5,
      children: [
        for (var i = 0; i < shown; i++)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < answered ? (youAnswered && i == 0 ? you : c) : Colors.transparent,
              border: Border.all(color: i < answered && youAnswered && i == 0 ? you : c, width: 1.5),
            ),
          ),
      ],
    );
  }
}

/// A single person: a dot. Others grey, you blue (with a halo).
class PersonDot extends StatelessWidget {
  final bool you;
  final double size;
  const PersonDot({super.key, this.you = false, this.size = 12});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: you ? youColor(context) : cs.onSurfaceVariant,
        border: you ? Border.all(color: cs.surface, width: size * 0.18) : null,
        boxShadow: you ? [BoxShadow(color: youColor(context).withAlpha(90), blurRadius: 0, spreadRadius: size * 0.22)] : null,
      ),
    );
  }
}

/// The ACAPS mark: an ink square.
class AcapsMark extends StatelessWidget {
  final double size;
  const AcapsMark({super.key, this.size = 10});

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, color: Theme.of(context).colorScheme.onSurface);
}

/// Legend line used under charts: "● you  ● other experts  ■ ACAPS".
class DotLegend extends StatelessWidget {
  final bool showYou;
  final bool showAcaps;
  const DotLegend({super.key, this.showYou = true, this.showAcaps = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final st = mono(11, color: cs.onSurfaceVariant, spacing: 0.4);
    Widget item(Widget mark, String label) => Row(mainAxisSize: MainAxisSize.min, children: [mark, const SizedBox(width: 5), Text(label, style: st)]);
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        if (showYou) item(const PersonDot(you: true, size: 10), 'you'),
        item(const PersonDot(size: 8), 'other experts'),
        if (showAcaps) item(const AcapsMark(size: 8), 'ACAPS'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The scale: forecast picker and group chart in one
// ---------------------------------------------------------------------------

/// Neutral ramp for scales that are not probabilities (how bad, 1-5).
const greyRamp = [Color(0xFFD7D8D1), Color(0xFFB2B4AD), Color(0xFF878A85), Color(0xFF5A5D5A), Color(0xFF2D2F2F)];

/// ACAPS's five steps as blocks. With [onSelect] it is an input (tap a block
/// or its label); with [crowd] every answer is drawn as a dot above its block,
/// and the group (median and middle half) is marked under the blocks.
class HeatScale extends StatelessWidget {
  /// Your answer (1..5): highlighted, and drawn as the blue dot.
  final int? value;
  final ValueChanged<int>? onSelect;

  /// ACAPS's rating on the same scale.
  final int? acaps;

  /// Every answer, yours included (chart mode).
  final List<int>? crowd;
  final GroupView? group;

  /// Text under each block, e.g. "High\n67–90%".
  final List<String> labels;
  final List<Color> colors;

  const HeatScale({
    super.key,
    this.value,
    this.onSelect,
    this.acaps,
    this.crowd,
    this.group,
    required this.labels,
    this.colors = scaleColors,
  });

  static const _gap = 4.0;
  static const _dot = 10.0;
  static const _dotGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final input = onSelect != null;
    final counts = List.filled(5, 0);
    for (final x in crowd ?? const <int>[]) {
      if (x >= 1 && x <= 5) counts[x - 1]++;
    }

    return LayoutBuilder(builder: (context, box) {
      final colW = (box.maxWidth - 4 * _gap) / 5;
      final perRow = math.max(1, ((colW + _dotGap) / (_dot + _dotGap)).floor());
      final rows = crowd == null ? 0 : counts.map((c) => (c / perRow).ceil()).fold(0, math.max);
      final swarmH = rows * (_dot + _dotGap);
      final blockH = input ? 58.0 : 22.0;

      Widget column(int i) {
        final selected = value == i;
        final col = colors[i - 1];
        final fg = colors == scaleColors ? onScale(i) : (i >= 4 ? Colors.white : AppColors.ink);
        final block = AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: blockH,
          decoration: BoxDecoration(
            color: input && !selected && value != null ? col.withAlpha(110) : col,
            border: selected ? Border.all(color: cs.onSurface, width: 3) : null,
          ),
          alignment: Alignment.center,
          child: input
              ? (selected
                  ? const PersonDot(you: true, size: 16)
                  : Text('$i', style: mono(18, weight: FontWeight.w700, color: fg.withAlpha(value == null ? 255 : 170))))
              : null,
        );

        final dots = crowd == null
            ? const SizedBox.shrink()
            : SizedBox(
                height: swarmH,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Wrap(
                    verticalDirection: VerticalDirection.up,
                    alignment: WrapAlignment.center,
                    spacing: _dotGap,
                    runSpacing: _dotGap,
                    children: [
                      for (var k = 0; k < counts[i - 1]; k++)
                        _AppearingDot(
                          delayMs: 40 * k + 60 * i,
                          child: k == 0 && value == i
                              ? const PersonDot(you: true, size: _dot)
                              : Container(
                                  width: _dot,
                                  height: _dot,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: cs.onSurfaceVariant),
                                ),
                        ),
                    ],
                  ),
                ),
              );

        final acapsMark = SizedBox(
          height: 18,
          child: acaps == i
              // Shrinks rather than overflows in a narrow column.
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AcapsMark(size: 8),
                      const SizedBox(width: 4),
                      Text('ACAPS', style: mono(10, weight: FontWeight.w700, color: cs.onSurface, spacing: 0.8)),
                    ],
                  ),
                )
              : null,
        );

        final label = Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            labels[i - 1],
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.2,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? cs.onSurface : cs.onSurfaceVariant,
            ),
          ),
        );

        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [acapsMark, if (crowd != null) dots, if (crowd != null) const SizedBox(height: 6), block, label],
        );
        if (!input) return content;
        return Semantics(
          button: true,
          selected: selected,
          label: labels[i - 1].replaceAll('\n', ' '),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect!(i);
            },
            child: Padding(padding: const EdgeInsets.only(bottom: 4), child: content),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 1; i <= 5; i++) ...[
                if (i > 1) const SizedBox(width: _gap),
                Expanded(child: column(i)),
              ],
            ],
          ),
          if (group != null) _GroupMarker(group: group!, colW: colW, gap: _gap),
          if (crowd != null && !input) ...[
            const SizedBox(height: 10),
            DotLegend(showYou: value != null, showAcaps: acaps != null),
          ],
        ],
      );
    });
  }
}

/// Under the blocks: a caret at the group's median and a bracket over the
/// middle half of answers. A split group gets a red bracket and "SPLIT".
class _GroupMarker extends StatelessWidget {
  final GroupView group;
  final double colW;
  final double gap;
  const _GroupMarker({required this.group, required this.colW, required this.gap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final split = group.split;
    final c = split ? cs.error : cs.onSurface;
    double x(double step) => (step - 1) * (colW + gap) + colW / 2;
    return SizedBox(
      height: 34,
      child: CustomPaint(
        painter: _GroupPainter(
          from: x(group.low.toDouble()),
          to: x(group.high.toDouble()),
          median: x(group.median),
          color: c,
          label: split ? 'SPLIT' : 'GROUP',
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _GroupPainter extends CustomPainter {
  final double from, to, median;
  final Color color;
  final String label;
  _GroupPainter({required this.from, required this.to, required this.median, required this.color, required this.label});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    const y = 8.0;
    // Bracket over the middle half of answers.
    canvas.drawLine(Offset(from, y), Offset(to, y), p);
    canvas.drawLine(Offset(from, y - 5), Offset(from, y + 5), p);
    canvas.drawLine(Offset(to, y - 5), Offset(to, y + 5), p);
    // Caret at the median.
    final tri = Path()
      ..moveTo(median, y - 7)
      ..lineTo(median - 6, y + 4)
      ..lineTo(median + 6, y + 4)
      ..close();
    canvas.drawPath(tri, Paint()..color = color);
    final tp = TextPainter(
      text: TextSpan(text: label, style: mono(10.5, weight: FontWeight.w700, color: color, spacing: 1.2)),
      textDirection: TextDirection.ltr,
    )..layout();
    final double lx = (median - tp.width / 2).clamp(0.0, math.max(0.0, size.width - tp.width)).toDouble();
    tp.paint(canvas, Offset(lx, y + 8));
  }

  @override
  bool shouldRepaint(_GroupPainter old) => old.from != from || old.to != to || old.median != median || old.color != color || old.label != label;
}

/// A dot that pops in, so a group view assembles person by person.
class _AppearingDot extends StatelessWidget {
  final int delayMs;
  final Widget child;
  const _AppearingDot({required this.delayMs, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final total = 260 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delayMs / total, 1, curve: Curves.easeOutBack),
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Inputs
// ---------------------------------------------------------------------------

/// "How bad would it be?": five bars of rising height, like signal strength.
/// Bars up to the chosen one fill in.
class SeverityPicker extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onSelect;
  final List<String> labels;
  const SeverityPicker({super.key, required this.value, required this.onSelect, required this.labels});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= 5; i++)
          Expanded(
            child: Semantics(
              button: true,
              selected: value == i,
              label: '$i of 5, ${labels[i - 1]}',
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(i);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 70,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 18.0 + 13.0 * (i - 1),
                            decoration: BoxDecoration(
                              color: value != null && i <= value! ? cs.onSurface : Colors.transparent,
                              border: Border.all(color: cs.onSurface, width: value == i ? 3 : 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('$i', style: mono(13, weight: FontWeight.w700, color: cs.onSurface)),
                      Text(
                        labels[i - 1],
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, fontWeight: value == i ? FontWeight.w800 : FontWeight.w500, color: value == i ? cs.onSurface : cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Yes / Partly / No as three big square keys.
class AgreePicker extends StatelessWidget {
  final Agreement? value;
  final ValueChanged<Agreement> onSelect;
  const AgreePicker({super.key, required this.value, required this.onSelect});

  static IconData iconOf(Agreement a) => switch (a) {
        Agreement.yes => Icons.check,
        Agreement.partly => Icons.contrast,
        Agreement.no => Icons.close,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final a in Agreement.values) ...[
          if (a != Agreement.yes) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              selected: value == a,
              child: Material(
                color: value == a ? cs.onSurface : Colors.transparent,
                shape: RoundedRectangleBorder(side: BorderSide(color: cs.onSurface, width: 2)),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(a);
                  },
                  child: SizedBox(
                    height: 64,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(iconOf(a), size: 22, color: value == a ? cs.surface : cs.onSurface),
                        const SizedBox(height: 2),
                        Text(a.label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: value == a ? cs.surface : cs.onSurface)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Survey progress as separate blocks: done (ink), current (half), to come.
class SegmentProgress extends StatelessWidget implements PreferredSizeWidget {
  final int step; // 1-based current step
  final int total;
  const SegmentProgress({super.key, required this.step, required this.total});

  @override
  Size get preferredSize => const Size.fromHeight(10);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          for (var i = 1; i <= total; i++) ...[
            if (i > 1) const SizedBox(width: 4),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 4,
                color: i < step ? cs.onSurface : (i == step ? youColor(context) : cs.outlineVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A trigger's completion (how close ACAPS thinks it is) as ten cells.
class CellMeter extends StatelessWidget {
  final int percent;
  final double height;
  const CellMeter(this.percent, {super.key, this.height = 10});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filled = (percent / 10).round().clamp(0, 10);
    final color = Color.lerp(scaleColors[1], scaleColors[4], percent / 100)!;
    return Row(
      children: [
        for (var i = 0; i < 10; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(child: Container(height: height, color: i < filled ? color : cs.outlineVariant)),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Anonymity: how far your name travels
// ---------------------------------------------------------------------------

/// What one audience sees of you.
class Audience {
  final String who;
  final String sees;

  /// 2 = real name, 1 = pseudonym, 0 = nothing that identifies you.
  final int exposure;
  const Audience(this.who, this.sees, this.exposure);
}

/// Half rings around you (the blue dot): each ring is an audience, darker
/// the more of you it sees. Reads like a sound wave: how far your name goes.
class AnonymityRings extends StatelessWidget {
  final List<Audience> rings; // inner to outer
  const AnonymityRings({super.key, required this.rings});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: rings.map((r) => '${r.who} sees ${r.sees}').join('. '),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final h = math.min(w / 2 + 18, 260.0);
        return SizedBox(
          width: w,
          height: h,
          child: CustomPaint(
            painter: _RingsPainter(
              rings: rings,
              ink: cs.onSurface,
              paper: cs.surface,
              soft: cs.onSurfaceVariant,
              you: youColor(context),
            ),
          ),
        );
      }),
    );
  }
}

class _RingsPainter extends CustomPainter {
  final List<Audience> rings;
  final Color ink, paper, soft, you;
  _RingsPainter({required this.rings, required this.ink, required this.paper, required this.soft, required this.you});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height - 4);
    final rMax = math.min(size.width / 2, size.height - 8);
    const rYou = 26.0;
    final band = (rMax - rYou) / rings.length;

    for (var i = rings.length - 1; i >= 0; i--) {
      final r = rings[i];
      final outer = rYou + band * (i + 1);
      final rect = Rect.fromCircle(center: c, radius: outer);
      final fill = switch (r.exposure) {
        2 => ink,
        1 => ink.withAlpha(95),
        _ => paper,
      };
      canvas.drawArc(rect, math.pi, math.pi, true, Paint()..color = fill);
      // Ring edge: solid where you are visible, dashed where you are not.
      final edge = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      if (r.exposure == 0) {
        _dashedArc(canvas, c, outer, edge);
      } else {
        canvas.drawArc(rect, math.pi, math.pi, false, edge);
      }
    }
    // Paper disc for "you", then the blue dot.
    canvas.drawArc(Rect.fromCircle(center: c, radius: rYou), math.pi, math.pi, true, Paint()..color = paper);
    canvas.drawCircle(c, 8, Paint()..color = you);
    canvas.drawCircle(
        c,
        12,
        Paint()
          ..color = you.withAlpha(90)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5);

    // Labels along the vertical axis, one per band. The wide line (what they
    // see) sits low in the band, where the arc curves away from it; the short
    // line (who) sits above it.
    for (var i = 0; i < rings.length; i++) {
      final r = rings[i];
      final inner = rYou + band * i;
      final onDark = r.exposure == 2;
      final fg = onDark ? paper : ink;
      _label(canvas, r.sees, Offset(c.dx, c.dy - inner - band * 0.34), fg, 12, center: true, bold: true);
      _label(canvas, r.who.toUpperCase(), Offset(c.dx, c.dy - inner - band * 0.72), onDark ? paper.withAlpha(210) : ink, 8.5, center: true);
    }
  }

  void _dashedArc(Canvas canvas, Offset c, double r, Paint p) {
    const dashes = 36;
    for (var k = 0; k < dashes; k += 2) {
      final a = math.pi + math.pi * k / dashes;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a, math.pi / dashes, false, p);
    }
  }

  void _label(Canvas canvas, String text, Offset at, Color color, double size, {bool center = false, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: bold
            ? TextStyle(fontFamily: fontText, fontSize: size, fontWeight: FontWeight.w800, color: color, height: 1.1)
            : mono(size, weight: FontWeight.w700, color: color, spacing: 1.0),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 220);
    tp.paint(canvas, Offset(center ? at.dx - tp.width / 2 : at.dx, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_RingsPainter old) => true;
}

// ---------------------------------------------------------------------------
// Surfaces
// ---------------------------------------------------------------------------

/// An inverted block: ink background, paper text. Used for what matters most
/// on a screen (the risk waiting for you, your track record).
class InkPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? stripe;
  const InkPanel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.stripe});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = cs.brightness == Brightness.dark;
    final bg = dark ? cs.surfaceContainerHighest : cs.inverseSurface;
    final content = Padding(padding: padding, child: child);
    return Theme(
      // Inside the panel, text and buttons invert too.
      data: Theme.of(context).copyWith(
        colorScheme: cs.copyWith(
          surface: bg,
          onSurface: dark ? cs.onSurface : cs.onInverseSurface,
          onSurfaceVariant: dark ? cs.onSurfaceVariant : cs.onInverseSurface.withAlpha(185),
          primary: dark ? cs.onSurface : cs.onInverseSurface,
          onPrimary: dark ? cs.surface : cs.inverseSurface,
          outline: dark ? cs.onSurface : cs.onInverseSurface,
        ),
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: dark ? cs.onSurface : cs.onInverseSurface,
              displayColor: dark ? cs.onSurface : cs.onInverseSurface,
            ),
      ),
      child: Builder(builder: (context) {
        final ics = Theme.of(context).colorScheme;
        return Container(
          color: bg,
          child: stripe == null
              ? content
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [Container(width: 8, color: stripe), Expanded(child: DefaultTextStyle.merge(style: TextStyle(color: ics.onSurface), child: content))],
                  ),
                ),
        );
      }),
    );
  }
}
