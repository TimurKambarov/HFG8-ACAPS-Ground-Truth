// =============================================================================
// Risk Radar screens for moderators (import new risks / sync statuses)
// =============================================================================
//
// ACAPS publishes its risk analysis in the "Risk Radar". Our app ships with a
// CSV export of it (assets/risk-radar-export.csv), but that export goes stale:
// ACAPS adds new risks and closes old ones every month. This file gives the
// moderator two buttons on the Risks tab that talk to the live ACAPS API:
//
//   1. IMPORT         -> pick a risk the app does not have yet, check it in the
//                        normal "New risk" form (already filled in from the
//                        API), then publish it to the expert panel.
//   2. SYNC STATUSES  -> see which risks ACAPS has opened or closed since our
//                        export, tick the ones to apply, apply them.
//
// Both actions need the same download (the full Risk Radar), so they share one
// screen widget with a [RadarMode] switch instead of duplicating the loading,
// error and refresh logic.
//
// Design principle (same as the rest of the app): nothing from the API reaches
// experts without a human check. Import always goes through the form, and
// status changes are listed with tick boxes before anything is applied.
//
// Data flow:
//   AcapsApi.riskRadar()  ->  List<ApiRisk>  (risks as ACAPS sees them now)
//        |                          |
//        | import mode              | sync mode
//        v                          v
//   RiskFormScreen(fromApi)    appState.statusChanges()  (diff vs the app)
//        |                          |
//        v                          v
//   appState.saveRisk()        appState.applyStatusChanges()
// =============================================================================

import 'package:flutter/material.dart';

import '../acaps_api.dart';
import '../models.dart';
import '../store.dart';
import 'risk_form.dart';

/// Filter for the import list (the segmented button under the search box).
enum _Show {
  /// Default: only risks the app does not have yet, i.e. the ones you can import.
  notInApp,

  /// Only risks ACAPS currently marks as Active.
  active,

  /// Everything on the Risk Radar (risks already in the app are greyed out).
  all,
}

/// What the Risk Radar screen is for: two separate moderator actions that
/// share the API download.
enum RadarMode {
  /// Pick a new risk, review it in the prefilled risk form, publish it.
  importRisks,

  /// Update the status of risks already in the app (Active / Archive).
  syncStatuses,
}

/// Moderator screen on top of the ACAPS Risk Radar API, see [RadarMode].
/// In import mode it pops with the published [Risk].
///
/// Opened from the moderator's Risks tab (see `_importRisk` and
/// `_syncStatuses` in moderator.dart).
class ImportRiskScreen extends StatefulWidget {
  /// The API client. Tests pass one with a fake HTTP client so they run
  /// offline; the app leaves it null and gets a real one.
  final AcapsApi? api;

  /// Which of the two actions this screen performs.
  final RadarMode mode;
  const ImportRiskScreen({super.key, this.api, this.mode = RadarMode.importRisks});

  @override
  State<ImportRiskScreen> createState() => _ImportRiskScreenState();
}

class _ImportRiskScreenState extends State<ImportRiskScreen> {
  late final AcapsApi _api = widget.api ?? AcapsApi();
  final _search = TextEditingController();

  /// The downloaded Risk Radar. Starts from the session cache, so reopening
  /// the import screen shows the list straight away (null = nothing yet).
  List<ApiRisk>? _risks = AcapsApi.cache;

  /// Last error message (no proxy, wrong password, API down...), or null.
  String? _error;

  /// True while a download is running (drives the spinner).
  bool _loading = false;

  /// Current filter of the import list.
  _Show _show = _Show.notInApp;

  @override
  void initState() {
    super.initState();
    // Status sync always asks the API afresh; import can reuse this session's download.
    // (A stale status list would be misleading; a stale import list is
    // harmless, and the refresh button in the app bar reloads it anyway.)
    if (_risks == null || _sync) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Downloads the whole Risk Radar. On failure we keep the previous list if
  /// there is one and only show the error above it ("Refresh failed: ...").
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.riskRadar();
      // `mounted` check: the moderator may have left the screen during the
      // download; calling setState on a disposed widget would throw.
      if (mounted) setState(() => _risks = r);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  bool get _sync => widget.mode == RadarMode.syncStatuses;

  /// Is a risk with this ACAPS id already in the app (from the CSV export,
  /// an earlier import, or the New risk form)?
  bool _inApp(ApiRisk r) => appState.byId(r.risk.id) != null;

  // ---------------------------------------------------------------------------
  // Sync mode
  // ---------------------------------------------------------------------------

  /// Status updates the moderator unticked. We store the *unticked* ones, so
  /// every change is selected by default.
  final Set<String> _skipUpdate = {};

  /// Applies the ticked status changes and confirms with a snackbar.
  void _applyUpdates(List<StatusChange> changes) {
    final chosen = changes.where((c) => !_skipUpdate.contains(c.risk.id)).toList();
    if (chosen.isEmpty) return;
    appState.applyStatusChanges(chosen); // saves on the device and notifies listeners
    setState(() => _skipUpdate.clear());
    // How many risks closed (= moved to the Archive), for the message.
    final closed = chosen.where((c) => !c.risk.withStatus(c.to).isActive).length;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${chosen.length} ${chosen.length == 1 ? 'status' : 'statuses'} updated from the Risk Radar'
          '${closed == 0 ? '' : ' · $closed moved to the Archive'}'),
    ));
  }

  // ---------------------------------------------------------------------------
  // Import mode
  // ---------------------------------------------------------------------------

  /// The import list after the filter and the search box. Search matches the
  /// same things as the moderator's main risk search: id, title, country.
  List<ApiRisk> get _rows {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final r in _risks ?? const <ApiRisk>[])
        if (switch (_show) {
              _Show.notInApp => !_inApp(r),
              _Show.active => r.risk.isActive,
              _Show.all => true,
            } &&
            (q.isEmpty ||
                r.risk.id.toLowerCase().contains(q) ||
                r.risk.title.toLowerCase().contains(q) ||
                r.risk.country.toLowerCase().contains(q)))
          r,
    ];
  }

  /// Opens the chosen risk in the regular risk form, prefilled from the API,
  /// so the moderator checks (and can edit) every field before publishing.
  /// If they publish, we close this screen too and hand the risk back to the
  /// moderator shell, which shows a snackbar and opens the new risk.
  Future<void> _review(ApiRisk r) async {
    final saved = await Navigator.of(context).push<Risk>(MaterialPageRoute(
      builder: (_) => RiskFormScreen(initial: r.risk, fromApi: true, apiUpdated: r.lastUpdate),
    ));
    if (saved != null && mounted) Navigator.pop(context, saved);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    // Each mode only computes what it shows.
    final rows = _sync ? const <ApiRisk>[] : _rows;
    final all = _risks ?? const <ApiRisk>[];
    final newCount = all.where((r) => !_inApp(r)).length;
    // The diff between the app and the API, recomputed on every build, so the
    // list empties itself right after "Apply".
    final changes = _sync ? appState.statusChanges(all.map((a) => a.risk)) : const <StatusChange>[];

    // Three states: first load (spinner), first load failed (error + retry),
    // or we have data (list; a failed *refresh* just shows a red line on top).
    Widget body;
    if (_risks == null && _loading) {
      body = const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('Loading the Risk Radar from the ACAPS API…'),
        ]),
      );
    } else if (_risks == null && _error != null) {
      // The message comes from AcapsApi and says what to do, e.g. "start the
      // proxy" on the web. Selectable so it can be copied into a terminal.
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: cs.error),
            const SizedBox(height: 12),
            SelectableText(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Try again')),
          ]),
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Summary line: "137 risks on the Risk Radar · 6 not in the app yet · loaded 18:04"
          Text(
            '${all.length} risks on the Risk Radar'
            '${_sync ? '' : ' · $newCount not in the app yet'}'
            '${AcapsApi.cachedAt == null ? '' : ' · loaded ${TimeOfDay.fromDateTime(AcapsApi.cachedAt!).format(context)}'}',
            style: t.bodySmall,
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text('Refresh failed: $_error', style: TextStyle(color: cs.error, fontSize: 12.5)),
          ],
          const SizedBox(height: 10),
          if (_sync)
            // --- Sync mode: one card with the status changes ---
            _StatusUpdates(
              changes: changes,
              // Risks from our CSV that the API does not list at all: we never
              // touch them (no news is not the same as "closed").
              notOnApi: appState.risks.where((r) => !r.custom && !all.any((a) => a.risk.id == r.id)).length,
              skipped: _skipUpdate,
              onToggle: (id, on) => setState(() => on ? _skipUpdate.remove(id) : _skipUpdate.add(id)),
              onApply: () => _applyUpdates(changes),
            )
          else ...[
            // --- Import mode: search + filter + list of risks ---
            TextField(
              controller: _search,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search ID, title or country', isDense: true),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            SegmentedButton<_Show>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Show.notInApp, label: Text('Not in app')),
                ButtonSegment(value: _Show.active, label: Text('Active')),
                ButtonSegment(value: _Show.all, label: Text('All')),
              ],
              selected: {_show},
              onSelectionChanged: (s) => setState(() => _show = s.first),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  _show == _Show.notInApp && _search.text.isEmpty ? 'Every Risk Radar risk is already in the app.' : 'No risks match.',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium,
                ),
              ),
            // Risks already in the app are shown but cannot be tapped:
            // importing them again would create a duplicate id.
            for (final r in rows) _ApiRiskTile(r: r, inApp: _inApp(r), onTap: _inApp(r) ? null : () => _review(r)),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_sync ? 'Sync statuses from Risk Radar' : 'Import from Risk Radar'),
        actions: [
          // Manual reload. While reloading with data on screen, the icon turns
          // into a small spinner instead of hiding the list.
          IconButton(
            tooltip: 'Reload from the API',
            onPressed: _loading ? null : _load,
            icon: _loading && _risks != null
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      // Same max width as the risk form, so the screen reads well on desktop.
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: body)),
    );
  }
}

/// Status as shown to the moderator. Everything that is not "Active"
/// (Materialised, Not materialised) lives in the app's Archive, so we say so.
String _statusLabel(String s) {
  if (s.trim().isEmpty) return 'No status';
  return s.trim().toLowerCase() == 'active' ? 'Active' : '$s (Archive)';
}

/// Risks in the app whose status changed in the Risk Radar: tick, then apply.
///
/// Stateless on purpose: which boxes are ticked lives in the parent screen,
/// so the selection survives rebuilds (e.g. after a refresh).
class _StatusUpdates extends StatelessWidget {
  final List<StatusChange> changes;

  /// How many app risks the API does not list (shown as a note, never changed).
  final int notOnApi;

  /// Ids the moderator unticked.
  final Set<String> skipped;
  final void Function(String id, bool on) onToggle;
  final VoidCallback onApply;
  const _StatusUpdates({
    required this.changes,
    required this.notOnApi,
    required this.skipped,
    required this.onToggle,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final note = notOnApi == 0 ? '' : ' $notOnApi risks in the app are not on the API and stay as they are.';

    // Nothing to do: a calm "all good" card instead of an empty list.
    if (changes.isEmpty) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.check_circle_outline, color: cs.primary),
          title: const Text('Statuses are up to date'),
          subtitle: Text('Every risk in the app has the same status as in the Risk Radar.$note', style: t.bodySmall),
        ),
      );
    }

    final n = changes.where((c) => !skipped.contains(c.risk.id)).length; // ticked
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${changes.length} status ${changes.length == 1 ? 'update' : 'updates'}', style: t.titleMedium),
                const SizedBox(height: 2),
                // Explains the consequence before the moderator presses Apply.
                Text(
                  'ACAPS changed these risks. Closed ones go to the Archive: experts can no longer answer, '
                  'and the forecasts they gave get scored.$note',
                  style: t.bodySmall,
                ),
              ]),
            ),
            // One row per change: "R1037 · Active → Materialised (Archive)".
            for (final c in changes)
              CheckboxListTile(
                value: !skipped.contains(c.risk.id),
                onChanged: (v) => onToggle(c.risk.id, v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text('${c.risk.id} · ${_statusLabel(c.from)} → ${_statusLabel(c.to)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(c.risk.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: n == 0 ? null : onApply, // disabled when nothing is ticked
                icon: const Icon(Icons.sync, size: 18),
                label: Text('Apply $n ${n == 1 ? 'update' : 'updates'}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of the import list: title, then "R1037 · South Sudan · Active ·
/// High risk · updated 2026-06-11". Risks already in the app get an "In app"
/// chip and are disabled.
class _ApiRiskTile extends StatelessWidget {
  final ApiRisk r;
  final bool inApp;
  final VoidCallback? onTap;
  const _ApiRiskTile({required this.r, required this.inApp, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final risk = r.risk;
    final meta = [
      risk.id,
      if (risk.country.isNotEmpty) risk.country,
      risk.status.isEmpty ? 'No status' : risk.status,
      if (risk.level.isNotEmpty) '${risk.level} risk',
      if (r.lastUpdate.isNotEmpty) 'updated ${r.lastUpdate}',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        enabled: !inApp,
        onTap: onTap,
        title: Text(risk.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(meta, style: t.bodySmall),
        trailing: inApp
            ? Chip(label: const Text('In app'), visualDensity: VisualDensity.compact, side: BorderSide(color: cs.outlineVariant))
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
