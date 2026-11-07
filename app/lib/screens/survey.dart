import 'package:flutter/material.dart';

import '../design.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

enum SurveyStart { intro, questions, summary }

/// "Not now" on a risk: skip it and say so clearly, with Undo. The risk stays
/// in the Risks list (tagged "Skipped") and the banner hides for this session.
void notNow(BuildContext context, Risk r) {
  appState.skip(r);
  final title = r.title.length > 90 ? '${r.title.substring(0, 90).trimRight()}…' : r.title;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      // A snack bar with an action stays until closed unless told otherwise.
      persist: false,
      duration: const Duration(seconds: 5),
      content: Text('Skipped: "$title". It stays in your list, marked "Skipped", so you can answer later.'),
      action: SnackBarAction(label: 'Undo', onPressed: () => appState.undoSkip(r)),
    ));
}

class _Draft {
  Agreement? agree;
  int? severity;
  final TextEditingController missing;

  _Draft([ItemAnswer? a])
      : agree = a?.agree,
        severity = a?.severity,
        missing = TextEditingController(text: a?.missing ?? '');

  bool get complete => agree != null && severity != null;

  ItemAnswer toAnswer() => ItemAnswer(agree: agree!, severity: severity!, missing: missing.text.trim());
}

/// A forward action: the label and an arrow, on an ink slab.
Widget _forward(String label, VoidCallback? onPressed, {IconData icon = Icons.arrow_forward}) => FilledButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Flexible(child: Text(label)), const SizedBox(width: 10), Icon(icon, size: 20)],
      ),
    );

/// Risk survey: intro -> one ground-truthing screen per trigger -> one
/// scored forecast for the whole risk -> thank you + group summary.
class SurveyScreen extends StatefulWidget {
  final Risk risk;
  final SurveyStart start;

  /// Opened by a notification or the "new risk" pop-up on app entry.
  final bool fromNotification;
  const SurveyScreen({super.key, required this.risk, this.start = SurveyStart.intro, this.fromNotification = false});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  late final List<SurveyItem> items = widget.risk.surveyItems;
  late final Map<String, _Draft> drafts;
  late int step; // 0 = intro, 1..n = triggers, n+1 = forecast, n+2 = summary
  bool _details = false;

  /// How to credit me if this risk is published; starts from my profile.
  Credit? _credit;

  /// The one scored answer: ACAPS probability scale 1..5.
  int? _forecast;

  Risk get r => widget.risk;
  int get forecastStep => items.length + 1;
  int get summaryStep => items.length + 2;

  @override
  void initState() {
    super.initState();
    final me = appState.me;
    final existing = me == null ? null : appState.responseOf(me, r);
    drafts = {for (final it in items) it.id: _Draft(existing?.items[it.id])};
    _forecast = existing?.forecast;
    _credit = me == null ? null : (existing?.credit ?? defaultCredit(me));
    step = switch (widget.start) {
      // Closed risks are read-only: straight to what happened and the group view.
      _ when me == null || r.isResolved => summaryStep,
      SurveyStart.intro => 0,
      SurveyStart.questions => 1,
      SurveyStart.summary => existing == null ? 0 : summaryStep,
    };
  }

  @override
  void dispose() {
    for (final d in drafts.values) {
      d.missing.dispose();
    }
    super.dispose();
  }

  void _go(int s) {
    FocusScope.of(context).unfocus();
    if (s == summaryStep) {
      appState.submit(r, {for (final e in drafts.entries) e.key: e.value.toAnswer()}, forecast: _forecast!, credit: _credit);
    }
    setState(() => step = s);
  }

  @override
  Widget build(BuildContext context) {
    final inItems = step >= 1 && step <= items.length;
    final inQuestions = step >= 1 && step <= forecastStep;
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(
            step == 0
                ? r.id
                : inItems
                    ? '${r.id} · ${items.length == 1 ? 'The risk' : 'Trigger $step of ${items.length}'}'
                    : step == forecastStep
                        ? '${r.id} · Your forecast'
                        : (r.isResolved ? '${r.id} · What happened' : 'Group summary'),
          ),
          bottom: inQuestions ? SegmentProgress(step: step, total: forecastStep) : null,
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey(step),
            child: step == 0
                ? _intro(context)
                : inItems
                    ? _ItemPage(
                        item: items[step - 1],
                        index: step - 1,
                        total: items.length,
                        draft: drafts[items[step - 1].id]!,
                        onChanged: () => setState(() {}),
                      )
                    : step == forecastStep
                        ? _ForecastPage(
                            risk: r,
                            value: _forecast,
                            onSelect: (v) => setState(() => _forecast = v),
                            footer: appState.me != null && _credit != null
                                ? CreditPicker(expert: appState.me!, value: _credit!, onChanged: (c) => setState(() => _credit = c))
                                : null,
                          )
                        : _Summary(risk: r),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: _buttons(context),
          ),
        ),
      ),
    );
  }

  Widget _buttons(BuildContext context) {
    final me = appState.me;
    if (step == 0) {
      return Row(
        children: [
          if (r.isActive && me != null) ...[
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 56)),
              onPressed: () {
                notNow(context, r);
                Navigator.of(context).pop();
              },
              child: const Text('Not now'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(child: _forward('Start', () => _go(1))),
        ],
      );
    }
    if (step <= forecastStep) {
      final last = step == forecastStep;
      final ok = last ? _forecast != null : drafts[items[step - 1].id]!.complete;
      return Row(
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 56)),
            onPressed: () => _go(step - 1),
            child: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 10),
          Expanded(child: _forward(last ? 'Send answers' : 'Next', ok ? () => _go(step + 1) : null, icon: last ? Icons.send : Icons.arrow_forward)),
        ],
      );
    }
    final locked = r.isResolved || me == null;
    return Row(
      children: [
        if (!locked) ...[
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: () => setState(() => step = 1),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Change answer'),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
        ),
      ],
    );
  }

  Widget _intro(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (widget.fromNotification && r.isActive) ...[
          InfoBanner(
            icon: Icons.notifications_active_outlined,
            color: youColor(context),
            text: 'ACAPS updated this risk in ${AppState.riskCountries(r).join(', ')}. Got 2 minutes?',
          ),
          const SizedBox(height: 12),
        ],
        RiskHeader(risk: r),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${items.length + 1}', style: mono(40, weight: FontWeight.w700, color: cs.onSurface, spacing: -1)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'short screens, about 2 minutes: '
                '${items.length == 1 ? 'the risk' : '${items.length} triggers'}, then one forecast. '
                'You answer before you see the group, so your view stays independent.',
                style: t.bodyMedium,
              ),
            ),
          ],
        ),
        // Always visible: exposure and triggers.
        if (r.exposure.isNotEmpty) ...[
          const SectionLabel('Expected exposure'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(r.exposure, style: mono(20, weight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(width: 8),
              Expanded(child: Text('people may need assistance', style: t.bodySmall)),
            ],
          ),
        ],
        if (r.triggers.isNotEmpty) ...[
          const SectionLabel('Triggers ACAPS is watching'),
          for (final (i, tr) in r.triggers.take(3).indexed)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              color: cs.surfaceContainerLowest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('T${i + 1}', style: mono(13, weight: FontWeight.w700, color: cs.onSurfaceVariant)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(tr.title, style: t.titleSmall)),
                    ],
                  ),
                  if (tr.completion != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 30),
                        Expanded(child: CellMeter(tr.completion!, height: 7)),
                        const SizedBox(width: 10),
                        Text('${tr.completion}%', style: mono(12.5, weight: FontWeight.w700, color: cs.onSurface)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
        // Only the long analysis stays behind "More details".
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => setState(() => _details = !_details),
            icon: Icon(_details ? Icons.expand_less : Icons.expand_more),
            label: Text(_details ? 'Less' : 'Full ACAPS analysis'),
          ),
        ),
        if (_details) ...[
          Text(r.title, style: t.titleSmall),
          const SizedBox(height: 8),
          Text(r.rationale, style: t.bodyMedium),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// One trigger, three ground-truthing questions (not scored)
// ---------------------------------------------------------------------------

class _ItemPage extends StatefulWidget {
  final SurveyItem item;
  final int index;
  final int total;
  final _Draft draft;
  final VoidCallback onChanged;

  const _ItemPage({required this.item, required this.index, required this.total, required this.draft, required this.onChanged});

  @override
  State<_ItemPage> createState() => _ItemPageState();
}

class _ItemPageState extends State<_ItemPage> {
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final it = widget.item;
    final d = widget.draft;
    final c = it.completion;
    void set(VoidCallback f) {
      setState(f);
      widget.onChanged();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Eyebrow(widget.total == 1 ? 'THE RISK' : 'TRIGGER ${widget.index + 1} OF ${widget.total}'),
        const SizedBox(height: 10),
        Text(it.title, style: t.headlineSmall?.copyWith(fontSize: 26)),
        if (c != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: CellMeter(c, height: 12)),
              const SizedBox(width: 12),
              Text('$c%', style: mono(18, weight: FontWeight.w700, color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 6),
          Text('How close ACAPS thinks this trigger is to being reached', style: t.bodySmall),
        ],
        if (it.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            it.description,
            maxLines: _more ? null : 3,
            overflow: _more ? null : TextOverflow.ellipsis,
            style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
              onPressed: () => setState(() => _more = !_more),
              child: Text(_more ? 'Less' : 'Read more'),
            ),
          ),
        ],
        _Question(
          n: 1,
          text: c == null ? 'Do you agree with the ACAPS assessment?' : 'Do you agree with ACAPS on this trigger?',
          child: AgreePicker(value: d.agree, onSelect: (a) => set(() => d.agree = a)),
        ),
        _Question(
          n: 2,
          text: 'How bad would it be?',
          child: SeverityPicker(value: d.severity, labels: severityLabels, onSelect: (v) => set(() => d.severity = v)),
        ),
        _Question(
          n: 3,
          text: 'What is ACAPS missing?',
          optional: true,
          child: TextField(
            controller: d.missing,
            maxLength: 140,
            maxLines: 1,
            decoration: const InputDecoration(hintText: 'One line: a signal, a place, a correction…'),
          ),
        ),
        Row(
          children: [
            Icon(Icons.lock_outline, size: 15, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                appState.me!.hideFromOtherCountries
                    ? 'Colleagues from ${appState.me!.homeCountry} see your comment as ${nameSeenBy(appState.me!, ViewerRole.expert, sameCountry: true)}, '
                        'others as $anonymousName. The public never sees it.'
                    : 'Colleagues see your comment as ${nameSeenBy(appState.me!, ViewerRole.expert)}. The public never sees it.',
                style: t.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The one scored question: will the whole risk materialise in 6 months?
// ---------------------------------------------------------------------------

/// ACAPS's scale with its ranges, as shown under the forecast blocks.
final forecastButtonLabels = [for (var i = 0; i < 5; i++) '${levelLabels[i]}\n${probabilityRanges[i]}'];

class _ForecastPage extends StatelessWidget {
  final Risk risk;
  final int? value;
  final ValueChanged<int> onSelect;

  /// The credit choice, on this last screen.
  final Widget? footer;

  const _ForecastPage({required this.risk, required this.value, required this.onSelect, this.footer});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final by = DateTime.now().add(forecastHorizon);
    final acaps = risk.acapsLikelihood;
    final v = value;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        const Eyebrow('YOUR FORECAST · SCORED'),
        const SizedBox(height: 10),
        Text('Will this risk materialise before ${formatDate(by)}?', style: t.headlineSmall?.copyWith(fontSize: 26)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: cs.onSurface, width: 3))),
          child: Text(risk.title, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ),
        const SizedBox(height: 18),
        // Live read-out of the choice, in its heat colour.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Container(
            key: ValueKey(v),
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: v == null ? cs.surfaceContainerLowest : scaleColors[v - 1],
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    v == null ? 'Tap a step' : levelLabels[v - 1].toUpperCase(),
                    style: TextStyle(
                      fontFamily: fontText,
                      fontSize: v == null ? 20 : 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: v == null ? cs.onSurfaceVariant : onScale(v),
                    ),
                  ),
                ),
                if (v != null) Text(probabilityRanges[v - 1], style: mono(22, weight: FontWeight.w700, color: onScale(v))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        HeatScale(value: v, acaps: acaps, labels: forecastButtonLabels, onSelect: onSelect),
        const SizedBox(height: 10),
        Text(
          [
            if (v != null) 'You: ${probabilityText(v)}.',
            if (acaps != null) 'ACAPS: ${probabilityText(acaps)}.',
          ].join('  '),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          'This is the one answer that is scored. When ACAPS records whether the risk materialised, '
          'you get up to 100 points for accuracy. The scale and ranges are ACAPS\'s own, so your '
          'forecast is scored exactly like theirs.',
          style: t.bodySmall,
        ),
        if (footer != null) ...[const SizedBox(height: 24), footer!],
      ],
    );
  }
}

/// "If ACAPS publishes this risk, list me as ..." Starts at the expert's
/// profile anonymity level; they can change it for this risk.
class CreditPicker extends StatelessWidget {
  final Expert expert;
  final Credit value;
  final ValueChanged<Credit> onChanged;
  const CreditPicker({super.key, required this.expert, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final shown = publicCredit(expert, value);
    final isDefault = value == defaultCredit(expert);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Eyebrow('IF ACAPS PUBLISHES THIS RISK'),
            const SizedBox(height: 8),
            Text('Credit me as', style: t.titleMedium),
            const SizedBox(height: 10),
            SegmentedButton<Credit>(
              showSelectedIcon: false,
              // Same order as the anonymity levels: 1 real name, 2 pseudonym, 3 anonymous.
              segments: [
                for (final c in const [Credit.realName, Credit.pseudonym, Credit.anonymous])
                  ButtonSegment(value: c, label: Text(c.label), enabled: creditAllowed(expert, c)),
              ],
              selected: {value},
              onSelectionChanged: (v) => onChanged(v.first),
            ),
            const SizedBox(height: 8),
            Text(
              '${shown == null ? 'Not listed. Your answers only count in the totals.' : 'Listed among contributors as "${shown.name}".'} '
              'Names are never shown next to answers.'
              '${isDefault ? ' This matches your profile (level ${expert.level.number}: ${expert.level.label}); you can change it for this risk.' : ''}'
              '${expert.realName == null ? ' Real name is off: your profile is fully anonymous.' : ''}',
              style: t.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  final int n;
  final String text;
  final bool optional;
  final Widget child;
  const _Question({required this.n, required this.text, required this.child, this.optional = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                color: cs.onSurface,
                alignment: Alignment.center,
                child: Text('$n', style: mono(14, weight: FontWeight.w700, color: cs.surface, spacing: 0)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, height: 1.25)),
                ),
              ),
              if (optional)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text('OPTIONAL', style: mono(10.5, weight: FontWeight.w700, color: cs.onSurfaceVariant, spacing: 1)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thank you + group summary
// ---------------------------------------------------------------------------

class _Summary extends StatelessWidget {
  final Risk risk;
  const _Summary({required this.risk});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final me = appState.me;
    final mine = me == null ? null : appState.responseOf(me, risk);
    final panel = appState.panelForRisk(risk);
    final answered = appState.respondents(risk);
    final comments = appState.commentsOn(risk);
    final items = risk.surveyItems;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (mine != null)
          Reveal(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  color: youColor(context),
                  child: const Icon(Icons.check, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Thank you.', style: t.headlineSmall),
                      Text('Here is how your group sees it.', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (risk.isResolved && mine == null) ...[
          const InfoBanner(
            icon: Icons.lock_clock_outlined,
            text: 'This risk has closed. You can see what happened and how the group saw it. '
                'Answers are no longer accepted, so there are no points here.',
          ),
          const SizedBox(height: 12),
          MaturedBlock(risk: risk),
          const SizedBox(height: 12),
        ],
        RespondentsCard(risk: risk, answered: answered, panelSize: panel.length),
        if (risk.isResolved && mine != null) ...[
          const SectionLabel('Your forecast matured'),
          MaturedBlock(risk: risk, response: mine),
        ],
        const SectionLabel('Forecast: will it materialise within 6 months?'),
        ForecastSummary(risk: risk, mine: mine?.forecast),
        const SectionLabel('Triggers'),
        // Per trigger: results, then what colleagues say ACAPS is missing, then the next trigger.
        for (var i = 0; i < items.length; i++) ...[
          QuestionHeader(number: i + 1, total: items.length, title: items[i].title),
          ItemSummary(risk: risk, item: items[i], mine: mine?.items[items[i].id]),
          CommentGroup(
            comments: comments.where((c) => c.itemId == items[i].id).toList()
              ..sort((a, b) => b.agreeIds.length.compareTo(a.agreeIds.length)),
          ),
          if (i < items.length - 1) const SizedBox(height: 28),
        ],
      ],
    );
  }
}

/// "6 of 8 answered", as a number and as dots, split into experts from the
/// risk country and from elsewhere.
class RespondentsCard extends StatelessWidget {
  final Risk risk;
  final List<Expert> answered;
  final int panelSize;
  const RespondentsCard({super.key, required this.risk, required this.answered, required this.panelSize});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final rc = AppState.riskCountries(risk);
    final split = splitByRiskCountry(answered, rc);
    final localN = split.local.fold(0, (a, x) => a + x.n);
    final otherN = split.other.fold(0, (a, x) => a + x.n);
    final me = appState.me;
    final youIn = me != null && answered.any((e) => e.id == me.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${answered.length}', style: mono(44, weight: FontWeight.w700, color: cs.onSurface, spacing: -1.5)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(' of $panelSize', style: mono(18, weight: FontWeight.w700, color: cs.onSurfaceVariant)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('experts on this panel have answered. Names are never shown here.', style: t.bodySmall),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            PanelDots(total: panelSize, answered: answered.length, youAnswered: youIn, size: 13),
            const SizedBox(height: 14),
            _SplitRow(icon: Icons.place, label: 'From ${rc.join(', ')}', n: localN),
            const SizedBox(height: 8),
            _SplitRow(
              icon: Icons.public,
              label: 'From other countries',
              n: otherN,
              detail: split.other.isEmpty ? null : countryList(split.other),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int n;
  final String? detail;
  const _SplitRow({required this.icon, required this.label, required this.n, this.detail});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: cs.onSurface),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (detail != null) Text(detail!, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Text('$n', style: mono(16, weight: FontWeight.w700, color: cs.onSurface)),
      ],
    );
  }
}

/// Counts per step 1..5.
List<int> countsOf(Iterable<int> xs) {
  final c = List.filled(5, 0);
  for (final x in xs) {
    c[x - 1]++;
  }
  return c;
}

/// Headline of a group view: the group answer (or "opinions split") in bold,
/// then how far experts agree.
class GroupLine extends StatelessWidget {
  final GroupView group;

  /// Forecast (ACAPS probability words) or "how bad" (1-5).
  final bool forecast;
  final String noun;
  const GroupLine({super.key, required this.group, required this.forecast, required this.noun});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final g = group;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (g.split) ...[
              Container(
                margin: const EdgeInsets.only(top: 2, right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: cs.error,
                child: Text('SPLIT', style: mono(11, weight: FontWeight.w700, color: Colors.white, spacing: 1)),
              ),
            ],
            Expanded(
              child: Text(forecast ? g.probabilityHeadline : g.severityHeadline,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: g.split ? cs.error : null)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('${g.spread(forecast ? levelLabels : const ['1', '2', '3', '4', '5'])} · ${g.n} ${g.n == 1 ? noun : '${noun}s'}',
            style: t.bodySmall),
      ],
    );
  }
}

/// How the panel's view moved since the last update cycle (about a month):
/// "Since 8 Oct 2026: Medium to High · 3 of 7 experts changed their forecast".
class TrendLine extends StatelessWidget {
  final Risk risk;
  const TrendLine({super.key, required this.risk});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final tr = appState.trendOf(risk);
    if (tr == null) return const SizedBox.shrink();
    final moved = tr.now.median - tr.then.median;
    final same = tr.then.short == tr.now.short;
    final (icon, color) = moved > 0
        ? (Icons.trending_up, AppColors.high)
        : moved < 0
            ? (Icons.trending_down, AppColors.low)
            : (Icons.trending_flat, cs.onSurfaceVariant);
    final strong = TextStyle(fontWeight: FontWeight.w800, color: same ? cs.onSurface : color);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(border: Border.all(color: same ? cs.outlineVariant : color, width: 2)),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Since ${formatDate(tr.since)}: ', style: mono(12.5, color: cs.onSurfaceVariant, spacing: 0)),
                if (same)
                  TextSpan(text: 'no change (${tr.now.short})', style: strong)
                else ...[
                  TextSpan(text: tr.then.short, style: strong),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward, size: 15, color: color)),
                  ),
                  TextSpan(text: tr.now.short, style: strong),
                ],
                TextSpan(text: ' · ${tr.changed} of ${tr.now.n} experts changed their forecast'),
              ]),
              style: t.bodySmall?.copyWith(color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// The group's forecasts for the whole risk on the ACAPS scale: every expert
/// a dot above their answer, the group (median, middle half) under the
/// scale, ACAPS and you marked.
class ForecastSummary extends StatelessWidget {
  final Risk risk;
  final int? mine;
  const ForecastSummary({super.key, required this.risk, required this.mine});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fs = appState.forecastsFor(risk).toList();
    final g = GroupView.of(fs);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (g == null)
              Text('No forecasts yet.', style: t.labelLarge)
            else
              GroupLine(group: g, forecast: true, noun: 'forecast'),
            const SizedBox(height: 14),
            HeatScale(crowd: fs, value: mine, acaps: risk.acapsLikelihood, group: g, labels: forecastButtonLabels),
            TrendLine(risk: risk),
          ],
        ),
      ),
    );
  }
}

class ItemSummary extends StatelessWidget {
  final Risk risk;
  final SurveyItem item;
  final ItemAnswer? mine;
  const ItemSummary({super.key, required this.risk, required this.item, required this.mine});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final answers = appState.answersFor(risk, item.id);
    List<int> count(int Function(ItemAnswer) f) {
      final c = List.filled(5, 0);
      for (final a in answers) {
        c[f(a) - 1]++;
      }
      return c;
    }

    final agree = {for (final a in Agreement.values) a: answers.where((x) => x.agree == a).length};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agree with ACAPS', style: t.labelLarge),
            const SizedBox(height: 8),
            AgreementBar(counts: agree, mine: mine?.agree),
            const SizedBox(height: 20),
            Text('How bad it would be', style: t.labelLarge),
            if (GroupView.of(answers.map((a) => a.severity)) case final g?) ...[
              const SizedBox(height: 6),
              GroupLine(group: g, forecast: false, noun: 'answer'),
            ],
            const SizedBox(height: 8),
            Distribution(counts: count((a) => a.severity), mine: mine?.severity, acaps: risk.impact),
          ],
        ),
      ),
    );
  }
}

const agreementColors = {
  Agreement.yes: Color(0xFF2F7A57),
  Agreement.partly: Color(0xFF9A9C96),
  Agreement.no: AppColors.high,
};

/// Read-only stacked bar of yes / partly / no, with a plain-text legend.
/// Deliberately not key-shaped, so it doesn't look tappable.
class AgreementBar extends StatelessWidget {
  final Map<Agreement, int> counts;
  final Agreement? mine;
  const AgreementBar({super.key, required this.counts, this.mine});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = counts.values.fold(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 16,
          width: double.infinity,
          child: total == 0
              ? Container(color: cs.outlineVariant)
              : Row(
                  children: [
                    for (final a in Agreement.values)
                      if (counts[a]! > 0)
                        Expanded(
                          flex: counts[a]!,
                          child: Container(
                            margin: const EdgeInsets.only(right: 2),
                            color: agreementColors[a]!,
                          ),
                        ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            for (final a in Agreement.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, color: agreementColors[a]),
                  const SizedBox(width: 5),
                  Text('${a.label} ${counts[a]}',
                      style: TextStyle(fontSize: 13, fontWeight: mine == a ? FontWeight.w800 : FontWeight.w500)),
                  if (mine == a) ...[
                    const SizedBox(width: 5),
                    PersonDot(you: true, size: 9),
                  ],
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// "Trigger 1 of 3" + title, opening each question block.
class QuestionHeader extends StatelessWidget {
  final int number;
  final int total;
  final String title;
  const QuestionHeader({super.key, required this.number, required this.total, required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            color: cs.onSurface,
            alignment: Alignment.center,
            child: Text('T$number', style: mono(13, weight: FontWeight.w700, color: cs.surface, spacing: 0)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(total == 1 ? 'THE RISK' : 'TRIGGER $number OF $total',
                    style: mono(11, weight: FontWeight.w700, color: cs.onSurfaceVariant, spacing: 1.2)),
                Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Colleagues' additions for one question, shown right under its results.
class CommentGroup extends StatelessWidget {
  final List<Comment> comments;
  const CommentGroup({super.key, required this.comments});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 12, left: 4),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: cs.onSurface, width: 3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.forum_outlined, size: 16, color: cs.onSurface),
              const SizedBox(width: 6),
              Text('What ACAPS is missing · ${comments.length}', style: t.labelLarge),
            ],
          ),
          const SizedBox(height: 4),
          if (comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('Nothing added on this one yet.', style: t.bodySmall),
            )
          else
            for (final c in comments) CommentCard(comment: c, items: const []),
        ],
      ),
    );
  }
}

/// Answers on 1..5 as dots above the scale: every expert a dot, you blue,
/// ACAPS marked, the group under the blocks. Heat colours for the ACAPS
/// probability scale ([labels] = its words), a grey ramp for "how bad".
class Distribution extends StatelessWidget {
  final List<int> counts;
  final int? mine;
  final int? acaps;

  /// Words under the numbers (e.g. the ACAPS probability ranges).
  final List<String>? labels;
  const Distribution({super.key, required this.counts, this.mine, this.acaps, this.labels});

  @override
  Widget build(BuildContext context) {
    final crowd = [for (var i = 1; i <= 5; i++) ...List.filled(counts[i - 1], i)];
    final probability = labels != null && labels!.length == 5 && labels!.first.contains('%');
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: HeatScale(
        crowd: crowd,
        value: mine,
        acaps: acaps,
        group: GroupView.of(crowd),
        labels: labels ?? [for (var i = 0; i < 5; i++) '${i + 1}\n${severityLabels[i]}'],
        colors: probability ? scaleColors : greyRamp,
      ),
    );
  }
}

/// Outcome of a closed risk, styled like the risk dossier. With [response],
/// also the expert's score for the forecast they made while it was open.
class MaturedBlock extends StatelessWidget {
  final Risk risk;
  final Response? response;
  const MaturedBlock({super.key, required this.risk, this.response});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final s = response == null ? null : appState.scoreOf(response!);
    final happened = risk.materialised;
    final text = risk.materialisation.length > 360 ? '${risk.materialisation.substring(0, 360).trimRight()}…' : risk.materialisation;

    return RiskHeader(
      risk: risk,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: happened ? AppColors.high : Colors.transparent,
              border: Border.all(color: happened ? AppColors.high : cs.onSurface, width: 2),
            ),
            child: Row(
              children: [
                Icon(happened ? Icons.warning_amber_rounded : Icons.shield_outlined, color: happened ? Colors.white : cs.onSurface),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(happened ? 'What happened: it materialised' : 'What happened: it did not materialise',
                      style: t.titleSmall?.copyWith(color: happened ? Colors.white : cs.onSurface, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(text, style: t.bodySmall?.copyWith(height: 1.45)),
          ],
          if (risk.fromEarlierList) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.history_toggle_off, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'From ACAPS\'s earlier risk list: it resolved over a longer period than 6 months, '
                    'so scores on it are indicative, not a true 6-month forecast.',
                    style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ],
          if (s != null) ...[
            const SizedBox(height: 12),
            Text(
              'Your forecast: ${probabilityText(response!.forecast!)}'
              '${risk.acapsLikelihood == null ? '' : ' · ACAPS: ${probabilityText(risk.acapsLikelihood!)}'}',
              style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ScoreBox(label: 'Your accuracy', value: '${accuracyPct(s.mine)}%', highlight: true),
                const SizedBox(width: 6),
                ScoreBox(label: 'ACAPS accuracy', value: '${accuracyPct(s.acaps)}%'),
                const SizedBox(width: 6),
                ScoreBox(label: 'Points', value: '+${s.points}'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${s.mine < s.acaps - 0.005 ? 'You were closer than ACAPS.' : s.mine > s.acaps + 0.005 ? 'ACAPS was closer this time.' : 'Same as ACAPS.'} '
              'Accuracy: how close your forecast was to what happened (100% = perfect). Only the forecast is scored.',
              style: t.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class ScoreBox extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const ScoreBox({super.key, required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final you = youColor(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: highlight ? you : Colors.transparent,
          border: Border.all(color: highlight ? you : cs.onSurface, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: mono(9.5, weight: FontWeight.w700, color: highlight ? Colors.white : cs.onSurfaceVariant, spacing: 0.6)),
            Text(value, style: mono(22, weight: FontWeight.w700, color: highlight ? Colors.white : cs.onSurface, spacing: -0.5)),
          ],
        ),
      ),
    );
  }
}

/// A colleague comment with agree/disagree. Hovering (or long-pressing) a
/// button shows where those experts are from, never singling anyone out.
class CommentCard extends StatelessWidget {
  final Comment comment;
  final List<SurveyItem> items;
  final Widget? moderatorActions;
  const CommentCard({super.key, required this.comment, required this.items, this.moderatorActions});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = comment;
    final author = appState.expertById(c.authorId);
    final viewer = appState.viewer;
    final name = author == null ? anonymousName : displayName(author, viewer);
    final me = appState.me;
    final isMine = me != null && c.authorId == me.id;
    final item = items.where((i) => i.id == c.itemId).firstOrNull;
    final risk = appState.byId(c.riskId);
    final rc = risk == null ? <String>[] : AppState.riskCountries(risk);
    // Closed risks are read-only, reactions included.
    final canReact = me != null && !isMine && !(risk?.isResolved ?? false);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Avatar(name, size: 22, ring: isMine),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  if (isMine) const Pill('You', strong: true),
                ],
              ),
              if (item != null && items.length > 1) ...[
                const SizedBox(height: 4),
                Text('On: ${item.title}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
              const SizedBox(height: 8),
              Text(c.text, style: const TextStyle(height: 1.4, fontSize: 15)),
              if (c.useful || c.usedInRiskId != null) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (c.useful) const Pill('Marked useful by ACAPS', icon: Icons.lightbulb_outline),
                  if (c.usedInRiskId != null) Pill('Used in ${c.usedInRiskId}', icon: Icons.push_pin_outlined),
                ]),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _ReactChip(
                    icon: Icons.thumb_up_alt_outlined,
                    label: 'Agree',
                    ids: c.agreeIds,
                    riskCountries: rc,
                    active: me != null && c.agreeIds.contains(me.id),
                    onTap: canReact ? () => appState.react(c, true) : null,
                  ),
                  _ReactChip(
                    icon: Icons.thumb_down_alt_outlined,
                    label: 'Disagree',
                    ids: c.disagreeIds,
                    riskCountries: rc,
                    active: me != null && c.disagreeIds.contains(me.id),
                    onTap: canReact ? () => appState.react(c, false) : null,
                  ),
                ],
              ),
              if (moderatorActions != null) ...[const Divider(height: 20), moderatorActions!],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Set<String> ids;
  final List<String> riskCountries;
  final bool active;
  final VoidCallback? onTap;

  const _ReactChip({required this.icon, required this.label, required this.ids, required this.riskCountries, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = active ? cs.surface : cs.onSurface;
    final where = describeSplit(appState.expertsByIds(ids), riskCountries);
    return Tooltip(
      message: where,
      waitDuration: const Duration(milliseconds: 150),
      child: Material(
        color: active ? cs.onSurface : Colors.transparent,
        shape: RoundedRectangleBorder(side: BorderSide(color: cs.onSurface, width: 1.5)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(active ? Icons.check : icon, size: 15, color: fg),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg)),
                const SizedBox(width: 6),
                Text('${ids.length}', style: mono(12.5, weight: FontWeight.w700, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
