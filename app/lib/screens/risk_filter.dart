import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';

// Search, filters and sort for risk lists, shared by moderators and experts:
// a search box, a filter button with a count, and this sheet.

enum RiskStatus { active, archive, all }

enum RiskSort {
  recommended,
  toReview,
  changed,
  split,
  disagreement,
  gap,
  responseRate,
  level,
  exposure,
  id
}

/// Sorts offered to moderators, and to experts (who only see their own risks
/// and none of the moderator signals).
const moderatorSorts = [
  RiskSort.toReview,
  RiskSort.changed,
  RiskSort.split,
  RiskSort.disagreement,
  RiskSort.gap,
  RiskSort.responseRate,
  RiskSort.level,
  RiskSort.exposure,
  RiskSort.id,
];
const expertSorts = [
  RiskSort.recommended,
  RiskSort.level,
  RiskSort.exposure,
  RiskSort.id
];

extension RiskSortText on RiskSort {
  String get label => switch (this) {
        RiskSort.recommended => 'Recommended for you',
        RiskSort.toReview => 'Most comments to review',
        RiskSort.changed => 'Biggest change in expert view',
        RiskSort.split => 'Experts most split',
        RiskSort.disagreement => 'Most disagreement with ACAPS',
        RiskSort.gap => 'Biggest forecast gap with ACAPS',
        RiskSort.responseRate => 'Lowest response rate',
        RiskSort.level => 'Highest risk level',
        RiskSort.exposure => 'Largest expected exposure',
        RiskSort.id => 'Risk ID',
      };
}

/// Search, filters and sort for a list of risks: the same component for
/// moderators (Risks tab) and experts (Risks tab), so both work the same way.
class RiskFilter extends ChangeNotifier {
  /// What "Reset" goes back to: moderators start on comments to review,
  /// experts on their recommended order.
  final RiskSort defaultSort;
  RiskFilter({this.defaultSort = RiskSort.toReview}) : sort = defaultSort;

  String query = '';
  String? region;
  String? country;
  RiskStatus status = RiskStatus.active;
  RiskSort sort;
  bool onlyToReview = false;

  /// Only risks where experts disagree among themselves (no clear group view).
  bool onlySplit = false;

  /// ACAPS categories: one risk type, any of these priority needs, and at
  /// least this expected exposure band (index in [exposureBands]).
  String? type;
  final Set<String> needs = {};
  int? minExposure;
  double minDisagreement = 0;

  void update(void Function(RiskFilter f) f) {
    f(this);
    notifyListeners();
  }

  void clear() {
    query = '';
    clearSheet();
    status = RiskStatus.active;
  }

  /// Resets what lives in the filter sheet (not search, not status).
  void clearSheet() {
    region = null;
    country = null;
    sort = defaultSort;
    onlyToReview = false;
    onlySplit = false;
    type = null;
    needs.clear();
    minExposure = null;
    minDisagreement = 0;
  }

  /// Filters set in the sheet (sort is not a filter).
  int get sheetCount =>
      (region == null ? 0 : 1) +
      (country == null ? 0 : 1) +
      (onlyToReview ? 1 : 0) +
      (onlySplit ? 1 : 0) +
      (minDisagreement > 0 ? 1 : 0) +
      (type == null ? 0 : 1) +
      (needs.isEmpty ? 0 : 1) +
      (minExposure == null ? 0 : 1);

  /// Something is narrowing the list (search or a filter in the sheet).
  bool get active => query.trim().isNotEmpty || sheetCount > 0;

  /// Search, place and categories: the filters experts and moderators share.
  bool matches(Risk r) {
    final q = query.trim().toLowerCase();
    final cs = AppState.riskCountries(r);
    if (country != null && !cs.contains(country)) return false;
    if (region != null && !cs.any((c) => regionOf(c) == region)) return false;
    if (q.isNotEmpty &&
        !'${r.searchText} ${r.oneLiner.toLowerCase()}'.contains(q))
      return false;
    if (type != null && r.type != type) return false;
    if (needs.isNotEmpty && !r.needList.any(needs.contains)) return false;
    if (minExposure != null && (r.exposureIdx ?? -1) < minExposure!)
      return false;
    return true;
  }

  /// Sorts by [key] (highest first), keeping the given order for ties.
  static List<Risk> _byDesc(List<Risk> rs, int Function(Risk) key) {
    final indexed = [for (var i = 0; i < rs.length; i++) (i, rs[i])];
    indexed.sort((a, b) {
      final c = key(b.$2).compareTo(key(a.$2));
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return [for (final x in indexed) x.$2];
  }

  static int _level(Risk r) =>
      switch (r.level) { 'High' => 3, 'Medium' => 2, 'Low' => 1, _ => 0 };

  /// Experts: filter [risks] (kept in their given, recommended order) and sort.
  List<Risk> applyBasic(Iterable<Risk> risks) {
    final out = risks.where(matches).toList();
    switch (sort) {
      case RiskSort.level:
        return _byDesc(out, _level);
      case RiskSort.exposure:
        return _byDesc(out, (r) => r.exposureIdx ?? -1);
      case RiskSort.id:
        out.sort((a, b) => a.id.compareTo(b.id));
      default:
        break; // recommended: as given
    }
    return out;
  }

  /// Moderators: filter with their extra signals, and sort.
  List<(Risk, RiskModStats)> apply(List<Risk> risks) {
    final out = <(Risk, RiskModStats)>[];
    for (final r in risks) {
      if (status == RiskStatus.active && !r.isActive) continue;
      if (status == RiskStatus.archive && !r.isResolved) continue;
      if (status == RiskStatus.all && !r.isActive && !r.isResolved) continue;
      if (!matches(r)) continue;
      final s = appState.modStats(r);
      if (onlyToReview && s.toReview == 0) continue;
      if (onlySplit && !s.split) continue;
      if (s.disagreement < minDisagreement) continue;
      out.add((r, s));
    }
    out.sort((a, b) => switch (sort) {
          RiskSort.toReview => b.$2.toReview != a.$2.toReview
              ? b.$2.toReview.compareTo(a.$2.toReview)
              : b.$2.comments.compareTo(a.$2.comments),
          RiskSort.changed => b.$2.moved.abs() != a.$2.moved.abs()
              ? b.$2.moved.abs().compareTo(a.$2.moved.abs())
              : b.$2.changed.compareTo(a.$2.changed),
          RiskSort.split => b.$2.spreadWidth != a.$2.spreadWidth
              ? b.$2.spreadWidth.compareTo(a.$2.spreadWidth)
              : b.$2.answered.compareTo(a.$2.answered),
          RiskSort.disagreement =>
            b.$2.disagreement.compareTo(a.$2.disagreement),
          RiskSort.gap =>
            (b.$2.gap?.abs() ?? -1).compareTo(a.$2.gap?.abs() ?? -1),
          RiskSort.responseRate =>
            a.$2.responseRate.compareTo(b.$2.responseRate),
          RiskSort.recommended => 0,
          RiskSort.level => _level(b.$1).compareTo(_level(a.$1)),
          RiskSort.exposure =>
            (b.$1.exposureIdx ?? -1).compareTo(a.$1.exposureIdx ?? -1),
          RiskSort.id => a.$1.id.compareTo(b.$1.id),
        });
    return out;
  }
}

/// The filter-and-sort sheet behind the ⚙ button. Experts get the same
/// sheet without the moderator-only options.
void showRiskFilterSheet(BuildContext context, RiskFilter f,
    {bool moderator = true}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ListenableBuilder(
      listenable: f,
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        final countries = (f.region == null
                ? appState.countries
                : appState.countries.where((c) => regionOf(c) == f.region))
            .toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Filter and sort', style: t.titleLarge)),
                  TextButton(
                      onPressed: () => f.update((x) => x.clearSheet()),
                      child: const Text('Reset')),
                ],
              ),
              const SectionLabel('Sort'),
              DropdownMenu<RiskSort>(
                key: ValueKey('sort-${f.sort}'),
                expandedInsets: EdgeInsets.zero,
                initialSelection: f.sort,
                leadingIcon: const Icon(Icons.sort),
                dropdownMenuEntries: [
                  for (final s in moderator ? moderatorSorts : expertSorts)
                    DropdownMenuEntry(value: s, label: s.label)
                ],
                onSelected: (v) {
                  if (v != null) f.update((x) => x.sort = v);
                },
              ),
              const SectionLabel('Where'),
              DropdownMenu<String?>(
                key: ValueKey('region-${f.region}'),
                expandedInsets: EdgeInsets.zero,
                initialSelection: f.region,
                label: const Text('Region'),
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: null, label: 'All regions'),
                  for (final r in regions.keys)
                    DropdownMenuEntry(value: r, label: r),
                ],
                onSelected: (v) => f.update((x) {
                  x.region = v;
                  if (v != null &&
                      x.country != null &&
                      regionOf(x.country!) != v) x.country = null;
                }),
              ),
              const SizedBox(height: 10),
              DropdownMenu<String?>(
                key: ValueKey('country-${f.country}-${f.region}'),
                expandedInsets: EdgeInsets.zero,
                initialSelection: f.country,
                menuHeight: 320,
                label: const Text('Country'),
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: null, label: 'All countries'),
                  for (final c in countries)
                    DropdownMenuEntry(value: c, label: c),
                ],
                onSelected: (v) => f.update((x) => x.country = v),
              ),
              const SectionLabel('Category'),
              DropdownMenu<String?>(
                key: ValueKey('type-${f.type}'),
                expandedInsets: EdgeInsets.zero,
                initialSelection: f.type,
                label: const Text('Risk type'),
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: null, label: 'All risk types'),
                  for (final ty in riskTypes)
                    DropdownMenuEntry(value: ty, label: ty),
                ],
                onSelected: (v) => f.update((x) => x.type = v),
              ),
              const SizedBox(height: 12),
              Text('Expected priority needs (any of)', style: t.bodyMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final n in priorityNeeds)
                    FilterChip(
                      label: Text(n),
                      selected: f.needs.contains(n),
                      onSelected: (on) => f.update(
                          (x) => on ? x.needs.add(n) : x.needs.remove(n)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownMenu<int?>(
                key: ValueKey('exposure-${f.minExposure}'),
                expandedInsets: EdgeInsets.zero,
                initialSelection: f.minExposure,
                label: const Text('Expected exposure at least'),
                leadingIcon: const Icon(Icons.groups_outlined),
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: null, label: 'Any exposure'),
                  for (var i = 0; i < exposureBands.length; i++)
                    DropdownMenuEntry(
                        value: i, label: '${exposureBands[i]} people'),
                ],
                onSelected: (v) => f.update((x) => x.minExposure = v),
              ),
              if (moderator) ...[
                const SectionLabel('Show only'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: f.onlyToReview,
                  onChanged: (v) => f.update((x) => x.onlyToReview = v),
                  title: const Text('Risks with comments to review'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: f.onlySplit,
                  onChanged: (v) => f.update((x) => x.onlySplit = v),
                  title: const Text('Risks where experts are split'),
                  subtitle: const Text(
                      'No clear group view: this part of the analysis may need attention.'),
                ),
                Row(
                  children: [
                    Expanded(
                        child: Text('Disagreement with ACAPS at least',
                            style: t.bodyMedium)),
                    Text('${(f.minDisagreement * 100).round()}%',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                Slider(
                  value: f.minDisagreement,
                  divisions: 20,
                  label: '${(f.minDisagreement * 100).round()}%',
                  onChanged: (v) => f.update((x) => x.minDisagreement = v),
                ),
              ],
              const SizedBox(height: 8),
              FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done')),
            ],
          ),
        );
      },
    ),
  );
}
