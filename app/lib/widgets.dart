import 'package:flutter/material.dart';

import 'brand.dart';
import 'models.dart';
import 'screens/survey.dart';
import 'store.dart';
import 'theme.dart';

/// Section heading as on acaps.org: Bebas Neue caps with a short teal bar.
class SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsets padding;
  const SectionLabel(this.text, {super.key, this.padding = const EdgeInsets.only(top: 28, bottom: 12)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontFamily: fontDisplay,
              fontSize: 22,
              height: 1.05,
              letterSpacing: 0.6,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          const AccentBar(width: 28),
        ],
      ),
    );
  }
}

/// A risk's ACAPS categories as tags: risk type, expected priority needs
/// and expected exposure (as on the ACAPS website). Shows only what ACAPS
/// recorded. [compact] (risk cards): the type and up to [maxNeeds] needs.
class CategoryChips extends StatelessWidget {
  final Risk risk;
  final bool compact;
  final int maxNeeds;
  const CategoryChips(this.risk, {super.key, this.compact = false, this.maxNeeds = 3});

  static IconData typeIcon(String type) {
    final t = type.toLowerCase();
    if (t.startsWith('new')) return Icons.fiber_new_outlined;
    if (t.startsWith('marked')) return Icons.trending_down;
    return Icons.flood_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final needs = risk.needList;
    final shown = compact ? needs.take(maxNeeds).toList() : needs;
    final chips = <Widget>[
      if (risk.type.isNotEmpty)
        Tooltip(
          message: 'Risk type: ${risk.type}',
          child: _Chip(compact ? risk.shortType : risk.type, typeIcon(risk.type), strong: true),
        ),
      for (final n in shown) Tooltip(message: 'Expected priority need', child: _Chip(n, null)),
      if (compact && needs.length > shown.length) _Chip('+${needs.length - shown.length}', null),
      if (!compact && risk.exposureIdx != null)
        Tooltip(
          message: 'Expected exposure: people who may need additional assistance',
          child: _Chip('${risk.exposure} people', Icons.groups_outlined),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}

/// Topic tag: square, tinted, like the category labels on ACAPS reports.
class _Chip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool strong;
  const _Chip(this.text, this.icon, {this.strong = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final light = cs.brightness == Brightness.light;
    final fg = strong ? (light ? AppColors.navy : cs.primary) : cs.onSurfaceVariant;
    final bg = strong ? cs.primaryContainer.withAlpha(light ? 255 : 120) : cs.surfaceContainerHighest.withAlpha(light ? 200 : 255);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(2),
        border: cs.outlineVariant == Colors.white ? Border.all(color: Colors.white) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(text, style: TextStyle(fontSize: 12, fontWeight: strong ? FontWeight.w700 : FontWeight.w400, color: fg)),
          ),
        ],
      ),
    );
  }
}

/// Risk level as a solid tag (red / sand / gold), like a map legend entry.
class LevelBadge extends StatelessWidget {
  final String level;
  const LevelBadge(this.level, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = levelColor(level);
    final unrated = level.isEmpty;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: unrated ? Colors.transparent : c,
        borderRadius: BorderRadius.circular(2),
        border: unrated ? Border.all(color: cs.outline) : null,
      ),
      child: Text(
        unrated ? 'UNRATED' : '${level.toUpperCase()} RISK',
        style: TextStyle(
          color: unrated ? cs.onSurfaceVariant : onColor(c),
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
          letterSpacing: 0.9,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Status tag: rounded with a thin teal outline (the website's tag style);
/// [strong] is solid navy.
class Pill extends StatelessWidget {
  final String text;
  final bool strong;
  final IconData? icon;
  const Pill(this.text, {super.key, this.strong = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final light = cs.brightness == Brightness.light;
    final accent = light ? AppColors.tealText : cs.primary;
    final fg = strong ? cs.onPrimary : accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: strong ? cs.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: strong ? cs.primary : accent.withAlpha(light ? 150 : 200)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          // Wraps instead of overflowing when the pill is wider than its space.
          Flexible(child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg))),
        ],
      ),
    );
  }
}

/// Avatar colours: the ACAPS palette, darkened enough for white initials.
const _avatarColors = [
  AppColors.navy,
  AppColors.tealText,
  Color(0xFFA0592A), // sand, dark
  Color(0xFF3F7A37), // green, dark
  Color(0xFF80558B), // severity purple
  Color(0xFFB83232), // red, dark
  Color(0xFF7A6630), // gold, dark
  AppColors.graphite,
];

/// Initials avatar with a colour derived from the name; anonymous gets a mask.
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
    final color = anon ? cs.onSurfaceVariant : _avatarColors[stableHash(name) % _avatarColors.length];
    final initials = name
        .split(RegExp(r'[\s\-_]+'))
        .where((p) => p.isNotEmpty && !RegExp(r'^\d+$').hasMatch(p))
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: faded ? Colors.transparent : (anon ? color.withAlpha(50) : color),
        border: Border.all(
          color: ring ? AppColors.teal : (faded ? cs.outlineVariant : Colors.transparent),
          width: ring ? 2.5 : 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: anon
          ? Icon(Icons.visibility_off_outlined, size: size * 0.48, color: faded ? cs.outlineVariant : cs.onSurface)
          : Text(
              initials.isEmpty ? '?' : initials,
              style: TextStyle(
                fontFamily: fontDisplay,
                color: faded ? cs.outlineVariant : Colors.white,
                fontSize: size * 0.46,
                height: 1.0,
                letterSpacing: 0.5,
              ),
            ),
    );
  }
}

/// Selectable option card (used for anonymity levels): a teal edge on the
/// left when selected.
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
    final light = cs.brightness == Brightness.light;
    final accent = light ? AppColors.teal : cs.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? cs.primaryContainer.withAlpha(light ? 160 : 110) : cs.surfaceContainerLowest,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: selected ? accent : cs.outlineVariant, width: 4),
                top: BorderSide(color: selected ? accent.withAlpha(110) : cs.outlineVariant),
                right: BorderSide(color: selected ? accent.withAlpha(110) : cs.outlineVariant),
                bottom: BorderSide(color: selected ? accent.withAlpha(110) : cs.outlineVariant),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Icon(icon, color: selected ? (light ? AppColors.navy : cs.primary) : cs.onSurfaceVariant),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 13.5, height: 1.4, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(Icons.check_circle, color: accent),
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

/// White card with a coloured left edge, like the feed cards on acaps.org.
class EdgeCard extends StatelessWidget {
  final Color edge;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? color;
  const EdgeCard({
    super.key,
    required this.edge,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Card(
        color: color,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: edge),
                Expanded(child: Padding(padding: padding, child: child)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A risk in a list: tap to open its survey.
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
    final edge = risk.isResolved ? cs.outline : levelColor(risk.level);
    final n = risk.surveyItems.length;

    return EdgeCard(
      edge: edge,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SurveyScreen(risk: risk, start: done || risk.isResolved ? SurveyStart.summary : SurveyStart.intro),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Eyebrow('${risk.id}  ·  ${risk.country}')),
              if (risk.isResolved) const Pill('Closed', icon: Icons.history_edu),
              if (skipped) const Pill('Skipped', icon: Icons.snooze_outlined),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            risk.oneLiner,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: t.titleMedium?.copyWith(fontSize: 17, height: 1.28),
          ),
          const SizedBox(height: 10),
          CategoryChips(risk, compact: true),
          const SizedBox(height: 12),
          Row(
            children: [
              LevelBadge(risk.level),
              const SizedBox(width: 10),
              // Shrinks and wraps on narrow phones instead of overflowing.
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: done && !risk.isResolved
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('ANSWERED', style: Eyebrow.style(context).copyWith(fontSize: 11)),
                            const SizedBox(width: 4),
                            Icon(Icons.check_circle, color: cs.brightness == Brightness.light ? AppColors.teal : cs.primary, size: 20),
                          ],
                        )
                      : Text(trailing ?? '${n + 1} short screens · 2 min',
                          textAlign: TextAlign.end, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Risk header (code, country, one-liner, ACAPS rating) on a tinted panel
/// with faint contour lines. Also used for the "forecast matured" block, so
/// both look like the same risk card.
class RiskHeader extends StatelessWidget {
  final Risk risk;
  final Widget? footer;
  const RiskHeader({super.key, required this.risk, this.footer});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = risk.probabilityIdx;
    final c = levelColor(risk.level);
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.withAlpha(dark ? 30 : 20), cs.surfaceContainerLowest),
        border: Border(left: BorderSide(color: c, width: 4)),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: TopoLines(color: cs.onSurface.withAlpha(dark ? 22 : 16), seed: stableHash(risk.id) % 97, scale: 120)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Eyebrow('${risk.id}  ·  ${risk.country}')),
                    LevelBadge(risk.level),
                  ],
                ),
                const SizedBox(height: 8),
                Text(risk.oneLiner, style: t.titleMedium),
                const SizedBox(height: 10),
                Text(
                  'ACAPS: ${p == null ? 'unrated' : '${levelLabels[p].toLowerCase()} probability (${probabilityRanges[p]})'}'
                  '${risk.impact == null ? '' : ' · impact ${risk.impact}/5'}',
                  style: t.bodySmall?.copyWith(color: cs.onSurface.withAlpha(200)),
                ),
                if (footer != null) ...[const SizedBox(height: 12), footer!],
              ],
            ),
          ),
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

/// Info box as on the website ("How is the severity level calculated?"):
/// a tinted panel with a coloured bar on the left.
class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const InfoBanner({super.key, required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final light = cs.brightness == Brightness.light;
    final c = color ?? (light ? AppColors.teal : cs.primary);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.withAlpha(light ? 24 : 40), cs.surfaceContainerLowest),
        border: Border(left: BorderSide(color: c, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: readable(c), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14, height: 1.45, color: cs.onSurface))),
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
                  width: 48,
                  child: Text('${(appState.textScale * 100).round()}%', textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                const Text('A', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
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
