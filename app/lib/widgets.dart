import 'package:flutter/material.dart';

import 'design.dart';
import 'models.dart';
import 'screens/survey.dart';
import 'store.dart';
import 'theme.dart';

/// Section label: a short ink rule and the title in mono capitals.
class SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsets padding;
  const SectionLabel(this.text, {super.key, this.padding = const EdgeInsets.only(top: 28, bottom: 12)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Eyebrow(text.toUpperCase()),
    );
  }
}

/// ACAPS risk level as a square tag in its heat colour.
class LevelBadge extends StatelessWidget {
  final String level;
  const LevelBadge(this.level, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = levelColor(level);
    final fg = level == 'High' ? Colors.white : AppColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: c,
      child: Text(
        level.isEmpty ? 'UNRATED' : '${level.toUpperCase()} RISK',
        style: mono(11, weight: FontWeight.w700, color: fg, spacing: 0.9),
      ),
    );
  }
}

/// Small square tag. [strong] = solid ink.
class Pill extends StatelessWidget {
  final String text;
  final bool strong;
  final IconData? icon;
  const Pill(this.text, {super.key, this.strong = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = strong ? cs.surface : cs.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: strong ? cs.onSurface : Colors.transparent,
        border: Border.all(color: cs.onSurface, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          // Wraps instead of overflowing when the tag is wider than its space.
          Flexible(child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg, height: 1.2))),
        ],
      ),
    );
  }
}

/// A person is a dot. Named people get their initials in mono; anonymous
/// people are a plain grey dot. [ring] marks you (blue).
class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final bool faded;
  final bool ring;

  const Avatar(this.name, {super.key, this.size = 36, this.faded = false, this.ring = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final anon = name == anonymousName || name.contains('anonymous');
    final initials = name
        .split(RegExp(r'[\s\-_]+'))
        .where((p) => p.isNotEmpty && !RegExp(r'^\d+$').hasMatch(p))
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    final you = youColor(context);
    final bg = ring ? you : (anon ? cs.onSurfaceVariant : cs.onSurface);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: faded ? Colors.transparent : bg,
        border: faded ? Border.all(color: cs.outlineVariant, width: 1.5) : null,
        boxShadow: ring ? [BoxShadow(color: you.withAlpha(80), spreadRadius: size * 0.12)] : null,
      ),
      alignment: Alignment.center,
      child: anon
          ? null
          : Text(
              initials.isEmpty ? '?' : initials,
              style: mono(size * 0.36, weight: FontWeight.w700, color: faded ? cs.outlineVariant : cs.surface, spacing: 0),
            ),
    );
  }
}

/// Selectable option (used for anonymity levels): a big mono number, the
/// title and what it means. Selected = ink frame and a filled square.
class OptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const OptionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final number = RegExp(r'Level (\d)').firstMatch(title)?.group(1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? cs.surfaceContainerLowest : Colors.transparent,
        shape: RoundedRectangleBorder(side: BorderSide(color: selected ? cs.onSurface : cs.outlineVariant, width: selected ? 2.5 : 1.5)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
                  child: number != null
                      ? Text('0$number', style: mono(20, weight: FontWeight.w700, color: selected ? cs.onSurface : cs.onSurfaceVariant))
                      : Icon(icon, color: selected ? cs.onSurface : cs.onSurfaceVariant),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: cs.onSurface)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: TextStyle(fontSize: 13.5, height: 1.35, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: selected ? cs.onSurface : Colors.transparent,
                    border: Border.all(color: selected ? cs.onSurface : cs.outlineVariant, width: 2),
                  ),
                  child: selected ? Icon(Icons.check, size: 14, color: cs.surface) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData anonymityIcon(Anonymity a) => switch (a) {
      Anonymity.knownToAcaps => Icons.badge_outlined,
      Anonymity.pseudonymous => Icons.theater_comedy_outlined,
      Anonymity.anonymous => Icons.visibility_off_outlined,
    };

/// A risk in a list, styled as a dossier tab: the countries as big ISO
/// codes, the one-liner, ACAPS's probability as heat, and the panel as dots.
class RiskTile extends StatelessWidget {
  final Risk risk;
  final String? trailing;

  const RiskTile({super.key, required this.risk, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final me = appState.me;
    final done = me != null && appState.responseOf(me, risk) != null;
    final skipped = !done && risk.isActive && appState.isSkipped(risk);
    final p = risk.probabilityIdx;
    final stripe = risk.isResolved ? cs.onSurfaceVariant : (p == null ? cs.outlineVariant : scaleColors[p]);
    final panel = appState.panelForRisk(risk).length;
    final answered = appState.respondents(risk).length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SurveyScreen(risk: risk, start: done || risk.isResolved ? SurveyStart.summary : SurveyStart.intro),
          )),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 8, color: stripe),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: IsoCode(risk, size: 20)),
                            if (risk.isResolved) ...[const Pill('Closed', icon: Icons.history_edu), const SizedBox(width: 6)],
                            if (skipped) ...[const Pill('Skipped', icon: Icons.snooze_outlined), const SizedBox(width: 6)],
                            Text(risk.id, style: mono(12, weight: FontWeight.w700, color: cs.onSurfaceVariant)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          risk.oneLiner,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.25),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            HeatChip(p == null ? null : p + 1, showRange: false),
                            const SizedBox(width: 10),
                            if (panel > 0) Flexible(child: PanelDots(total: panel, answered: answered, youAnswered: done, size: 8)),
                            const SizedBox(width: 10),
                            // Shrinks and wraps on narrow phones instead of overflowing.
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: done && !risk.isResolved
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check, color: youColor(context), size: 18),
                                          const SizedBox(width: 3),
                                          Text('ANSWERED', style: mono(11, weight: FontWeight.w700, color: youColor(context), spacing: 1)),
                                        ],
                                      )
                                    : Text(trailing ?? '2 min',
                                        textAlign: TextAlign.end,
                                        style: mono(11.5, color: cs.onSurfaceVariant, spacing: 0.2)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Risk header (countries, ID, one-liner, ACAPS rating). Also used for the
/// "forecast matured" block, so both look like the same dossier.
class RiskHeader extends StatelessWidget {
  final Risk risk;
  final Widget? footer;
  const RiskHeader({super.key, required this.risk, this.footer});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final p = risk.probabilityIdx;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        border: Border(top: BorderSide(color: p == null ? cs.onSurface : scaleColors[p], width: 8)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: IsoCode(risk, size: 26)),
              Text(risk.id, style: mono(13, weight: FontWeight.w700, color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 2),
          Text(risk.country, style: t.bodySmall),
          const SizedBox(height: 10),
          Text(risk.oneLiner, style: t.titleLarge),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('ACAPS ', style: mono(11, weight: FontWeight.w700, color: cs.onSurfaceVariant, spacing: 1)),
                HeatChip(p == null ? null : p + 1),
              ]),
              if (risk.impact != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('IMPACT ', style: mono(11, weight: FontWeight.w700, color: cs.onSurfaceVariant, spacing: 1)),
                  Pips(risk.impact),
                  Text('  ${risk.impact}/5', style: mono(11.5, weight: FontWeight.w700, color: cs.onSurface)),
                ]),
            ],
          ),
          // Plain words too, so colour never carries the meaning alone.
          const SizedBox(height: 8),
          Text(
            'ACAPS: ${p == null ? 'unrated' : '${levelLabels[p].toLowerCase()} probability (${probabilityRanges[p]})'}'
            '${risk.impact == null ? '' : ' · impact ${risk.impact}/5'}',
            style: t.bodySmall,
          ),
          if (footer != null) ...[const SizedBox(height: 14), footer!],
        ],
      ),
    );
  }
}

/// Fade + slide-up when first built.
class Reveal extends StatelessWidget {
  final Widget child;
  final int delayMs;
  const Reveal({super.key, required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + delayMs),
      curve: Interval(delayMs / (380 + delayMs), 1, curve: Curves.easeOutCubic),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: child),
      ),
      child: child,
    );
  }
}

/// A note: a thick bar in its colour on the left, icon and text.
class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const InfoBanner({super.key, required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        border: Border(left: BorderSide(color: c, width: 5)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14, height: 1.4, color: cs.onSurface))),
        ],
      ),
    );
  }
}

/// Theme and text size controls.
class DisplaySettings extends StatelessWidget {
  const DisplaySettings({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theme', style: t.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final th in AppTheme.values)
                  ChoiceChip(
                    avatar: Icon(switch (th) {
                      AppTheme.system => Icons.brightness_auto_outlined,
                      AppTheme.light => Icons.light_mode_outlined,
                      AppTheme.dark => Icons.dark_mode_outlined,
                      AppTheme.contrast => Icons.contrast,
                    }, size: 18),
                    label: Text(th.label),
                    selected: appState.theme == th,
                    onSelected: (_) => appState.setTheme(th),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text('Text size', style: t.labelLarge)),
                if (appState.textScale != 1.0)
                  TextButton(onPressed: () => appState.setTextScale(1.0), child: const Text('Reset to 100%')),
              ],
            ),
            Row(
              children: [
                const Text('A', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Slider(
                    value: appState.textScale.clamp(minTextScale, maxTextScale),
                    min: minTextScale,
                    max: maxTextScale,
                    divisions: ((maxTextScale - minTextScale) / textScaleStep).round(),
                    label: '${(appState.textScale * 100).round()}%',
                    onChanged: appState.setTextScale,
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text('${(appState.textScale * 100).round()}%', textAlign: TextAlign.end, style: mono(14, weight: FontWeight.w700)),
                ),
                const Text('A', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        );
      },
    );
  }
}

void showDisplaySettings(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const SafeArea(
        child: Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 20), child: DisplaySettings()),
      ),
    );

String formatDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}
