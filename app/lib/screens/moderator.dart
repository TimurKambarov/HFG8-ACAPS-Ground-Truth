import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';
import '../download.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home.dart';
import 'risk_filter.dart';
import 'risk_form.dart';
import 'survey.dart';

/// Moderator workspace, one tab per job:
///
/// Inbox: what needs action (countries that need experts, new comments).
///   Only new comments count towards the badge.
/// Risks: every risk with its full ACAPS details and triggers.
/// Comments: review what experts say ACAPS is missing, trigger by trigger.
/// Experts: every expert, sortable by rating.
/// Profile: this moderator's account, activity and display settings.
class ModeratorShell extends StatefulWidget {
  const ModeratorShell({super.key});

  @override
  State<ModeratorShell> createState() => _ModeratorShellState();
}

const _wideBreakpoint = 900.0;

/// Width of a tab body (screen minus the navigation rail) from which it
/// shows a list and a detail side by side.
const _splitBreakpoint = _wideBreakpoint - 120;
const _tabNames = ['inbox', 'risks', 'comments', 'experts', 'profile'];
const _risksTab = 1, _commentsTab = 2, _profileTab = 4;

/// Opens the comments of a risk, optionally scrolled to one trigger.
typedef OpenReview = void Function(Risk risk, {String? trigger});

class _ModeratorShellState extends State<ModeratorShell> {
  /// Demo links can open a tab directly: ?tab=inbox|risks|comments|experts|profile.
  int _tab = _tabNames.indexOf(Uri.base.queryParameters['tab'] ?? '').clamp(0, _tabNames.length - 1);
  final _filter = RiskFilter();
  String? _selectedRisk = 'R1043';

  /// Risk open in the Comments tab: the one with most new comments to start.
  String? _reviewRisk = _ReviewList.risksWithComments(onlyNew: true).firstOrNull?.$1.id ?? 'R1043';

  /// Trigger to scroll to in the Comments tab, and a counter so opening the
  /// same trigger again scrolls there again.
  String? _reviewTrigger;
  int _reviewOpens = 0;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  bool get _wide => MediaQuery.sizeOf(context).width >= _wideBreakpoint;

  /// Risk details (Risks tab).
  void _openRisk(Risk r) {
    if (_wide) {
      setState(() {
        _tab = _risksTab;
        _selectedRisk = r.id;
      });
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ModRiskScreen(risk: r, onReview: _openReview)));
    }
  }

  /// Comment review for one risk (Comments tab), optionally at one trigger.
  void _openReview(Risk r, {String? trigger}) {
    if (_wide) {
      setState(() {
        _tab = _commentsTab;
        _reviewRisk = r.id;
        _reviewTrigger = trigger;
        _reviewOpens++;
      });
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ModReviewScreen(risk: r, focusTrigger: trigger, onOpenDetails: _openRisk),
      ));
    }
  }

  Future<void> _newRisk() async {
    final r = await Navigator.of(context).push<Risk>(MaterialPageRoute(builder: (_) => const RiskFormScreen()));
    if (r == null || !mounted) return;
    final n = appState.panelForRisk(r).length;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r.id} published to $n ${n == 1 ? 'expert' : 'experts'}')));
    _openRisk(r);
  }

  @override
  Widget build(BuildContext context) {
    final wide = _wide;
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        // Only new comments are notifications; panel gaps live in the Inbox
        // but do not add to the number.
        final newComments = appState.commentsToReview;
        Widget inboxIcon(bool selected) {
          final icon = Icon(selected ? Icons.inbox : Icons.inbox_outlined);
          return newComments == 0 ? icon : Badge(label: Text('$newComments'), child: icon);
        }

        final me = appState.moderator;
        final dest = [
          (inboxIcon(false), inboxIcon(true), 'Inbox'),
          (const Icon(Icons.fact_check_outlined), const Icon(Icons.fact_check), 'Risks'),
          (const Icon(Icons.forum_outlined), const Icon(Icons.forum), 'Comments'),
          (const Icon(Icons.groups_2_outlined), const Icon(Icons.groups_2), 'Experts'),
          (const Icon(Icons.person_outline), const Icon(Icons.person), 'Profile'),
        ];

        final body = IndexedStack(
          index: _tab,
          children: [
            _InboxTab(onOpenReview: _openReview),
            _RisksTab(filter: _filter, selectedId: _selectedRisk, onSelect: _openRisk, onReview: _openReview, onNewRisk: _newRisk),
            _CommentsTab(
              selectedId: _reviewRisk,
              focusTrigger: _reviewTrigger,
              opens: _reviewOpens,
              onSelect: _openReview,
              onOpenDetails: _openRisk,
            ),
            const _ExpertsTab(),
            const _ModProfileTab(),
          ],
        );

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined),
                SizedBox(width: 8),
                Flexible(child: Text('ACAPS moderator', style: TextStyle(fontWeight: FontWeight.w800))),
              ],
            ),
            actions: [
              IconButton(tooltip: 'Invite an expert (single-use link)', onPressed: () => showInviteSheet(context), icon: const Icon(Icons.link)),
              if (me != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    tooltip: 'Signed in as ${me.name}',
                    onPressed: () => setState(() => _tab = _profileTab),
                    icon: Avatar(me.name, size: 30),
                  ),
                ),
            ],
          ),
          body: wide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _tab,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: (i) => setState(() => _tab = i),
                      destinations: [
                        for (final d in dest) NavigationRailDestination(icon: d.$1, selectedIcon: d.$2, label: Text(d.$3)),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _tab,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  destinations: [for (final d in dest) NavigationDestination(icon: d.$1, selectedIcon: d.$2, label: d.$3)],
                ),
        );
      },
    );
  }
}

// ===========================================================================
// Inbox: what needs action
// ===========================================================================

typedef _PanelAlert = ({String country, int n, int active});

class _Inbox {
  /// Countries with active risks and nobody on the panel: nobody to ask.
  final List<_PanelAlert> empty;

  /// Countries with active risks and 1-2 experts: group results could reveal
  /// who answered.
  final List<_PanelAlert> belowMin;

  /// Risks with comments nobody has reviewed yet, most first.
  final List<(Risk, int)> toReview;

  const _Inbox(this.empty, this.belowMin, this.toReview);

  int get newComments => toReview.fold(0, (s, x) => s + x.$2);
  int get panelGaps => empty.length + belowMin.length;

  static _Inbox collect() {
    final thin = appState.thinPanels;
    int byActive(_PanelAlert a, _PanelAlert b) => b.active != a.active ? b.active.compareTo(a.active) : a.country.compareTo(b.country);
    return _Inbox(
      thin.where((p) => p.n == 0).toList()..sort(byActive),
      thin.where((p) => p.n > 0).toList()..sort(byActive),
      [
        for (final (r, n, _) in _ReviewList.risksWithComments(onlyNew: true)) (r, n),
      ],
    );
  }
}

class _InboxTab extends StatefulWidget {
  final ValueChanged<Risk> onOpenReview;
  const _InboxTab({required this.onOpenReview});

  @override
  State<_InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<_InboxTab> {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final inbox = _Inbox.collect();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('Inbox', style: t.headlineSmall),
        const SizedBox(height: 4),
        Text('Countries that need experts, and new comments to review.', style: t.bodySmall),
        if (inbox.panelGaps == 0 && inbox.newComments == 0)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Column(
              children: [
                Icon(Icons.task_alt, size: 48, color: cs.primary),
                const SizedBox(height: 8),
                Text('All clear.', style: t.titleMedium),
              ],
            ),
          ),

        // 1. Panel coverage: one section, explained before any numbers.
        if (inbox.panelGaps > 0) ...[
          _SectionHeader(icon: Icons.person_add_alt, title: 'Countries that need experts', count: inbox.panelGaps),
          Text(
            'These countries have active risks but not enough experts. With none, nobody can answer. '
            'With 1 or 2, group results could reveal who answered, so at least $minPanel are needed. '
            'Create a personal invite link for a trusted contact with the link button at the top.',
            style: t.bodyMedium,
          ),
          if (inbox.empty.isNotEmpty)
            _CountryGroup(
              title: 'No experts yet',
              alerts: inbox.empty,
              status: (p) => 'No experts · ${_risks(p.active)} with nobody to answer',
            ),
          if (inbox.belowMin.isNotEmpty)
            _CountryGroup(
              title: 'Too few experts (minimum $minPanel)',
              alerts: inbox.belowMin,
              status: (p) => '${p.n} of $minPanel experts · ${_risks(p.active)}',
            ),
        ],

        // 2. New comments, at the bottom. These are the Inbox notifications.
        _SectionHeader(icon: Icons.forum_outlined, title: 'New comments to review', count: inbox.newComments),
        Text(
          inbox.newComments == 0
              ? 'No new comments. The number on the Inbox tab counts new comments only.'
              : 'Comments no moderator has handled yet. The number on the Inbox tab counts these.',
          style: t.bodyMedium,
        ),
        const SizedBox(height: 6),
        for (final (r, n) in inbox.toReview)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              onTap: () => widget.onOpenReview(r),
              title: Text(r.oneLiner, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${r.id} · ${r.country}', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CountPill('$n new', color: cs.primary),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _risks(int n) => '$n active ${n == 1 ? 'risk' : 'risks'}';

/// One group of countries in the Inbox: the first few, then "Show all".
class _CountryGroup extends StatefulWidget {
  final String title;
  final List<_PanelAlert> alerts;
  final String Function(_PanelAlert p) status;
  const _CountryGroup({required this.title, required this.alerts, required this.status});

  @override
  State<_CountryGroup> createState() => _CountryGroupState();
}

class _CountryGroupState extends State<_CountryGroup> {
  static const _preview = 5;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final shown = _all ? widget.alerts : widget.alerts.take(_preview);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text('${widget.title} · ${widget.alerts.length}', style: t.titleSmall),
        ),
        for (final p in shown)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              title: Text(p.country, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(widget.status(p), style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          ),
        if (widget.alerts.length > _preview)
          TextButton(
            onPressed: () => setState(() => _all = !_all),
            child: Text(_all ? 'Show fewer' : 'Show all ${widget.alerts.length}'),
          ),
      ],
    );
  }
}

/// The moderator's invite button: generates a new single-use link straight
/// away (no country to pick: the expert chooses theirs when creating their
/// profile), and lists all links.
void showInviteSheet(BuildContext context) {
  // Generated on the tap itself (not while the dialog builds).
  final link = appState.createInvite();
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: _InviteSheet(first: link),
      ),
    ),
  );
}

/// Ready-to-send invitation text with the personal link.
String inviteMessage(Invite i) =>
    'You are invited to join the ACAPS Ground Truth expert group: a few minutes a month to '
    'ground-truth ACAPS risk analysis, at the level of anonymity you choose.\n\n'
    'Your personal link (works once, please do not share it): ${inviteLink(i.code)}';

class _InviteSheet extends StatefulWidget {
  /// The link generated when the button was tapped.
  final Invite first;
  const _InviteSheet({required this.first});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

/// Opens with a freshly generated link, ready to copy; below, every link
/// with its status (open, used, cancelled).
class _InviteSheetState extends State<_InviteSheet> {
  late Invite _link = widget.first;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what copied')));
  }

  void _another() {
    _note.clear();
    setState(() => _link = appState.createInvite());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final list = appState.invitesNewestFirst;
    final open = list.where((i) => i.open).length;
    final used = list.where((i) => i.used).length;
    final cancelled = list.where((i) => i.revoked).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(width: 48),
              Expanded(child: Text('New invite link', textAlign: TextAlign.center, style: t.titleLarge)),
              IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Personal and works once. ACAPS knows whom it invited; once inside, the expert chooses their '
              'own anonymity and countries. A used link is never linked to the account.',
              textAlign: TextAlign.center, style: t.bodySmall),
          const SizedBox(height: 14),
          // The link is the invitation and the authorisation: opening it lets
          // that one person create a profile.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest.withAlpha(140), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.link, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectableText(inviteLink(_link.code),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _copy(inviteLink(_link.code), 'Invite link'),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy link'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _copy(inviteMessage(_link), 'Invitation message'),
                icon: const Icon(Icons.mail_outline, size: 18),
                label: const Text('Copy invitation message'),
              ),
              TextButton.icon(
                onPressed: _another,
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Another link'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Who is it for? (optional, moderators only)',
              hintText: 'e.g. protection officer, Abéché',
              isDense: true,
            ),
            onChanged: (v) => appState.setInviteNote(_link, v),
          ),
          const SectionLabel('Invite links'),
          Text('$open open · $used used${cancelled == 0 ? '' : ' · $cancelled cancelled'}', style: t.bodySmall),
          for (final i in list)
            _InviteRow(invite: i, onCopy: () => _copy(inviteLink(i.code), 'Invite link'), onChanged: () => setState(() {})),
        ],
      ),
    );
  }
}

/// One invite link in the moderator's list.
class _InviteRow extends StatelessWidget {
  final Invite invite;
  final VoidCallback onCopy;
  final VoidCallback onChanged;
  const _InviteRow({required this.invite, required this.onCopy, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final i = invite;
    final by = moderatorById(i.createdBy)?.shortName ?? 'a moderator';
    final status = i.revoked
        ? 'Cancelled'
        : i.used
            ? 'Used ${formatDate(i.usedAt!)}'
            : 'Open';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        i.open ? Icons.link : (i.used ? Icons.check_circle_outline : Icons.link_off),
        color: i.open ? cs.primary : cs.onSurfaceVariant,
      ),
      title: Text('${i.code} · $status', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
      subtitle: Text('${i.note.isEmpty ? '' : '${i.note} · '}created ${formatDate(i.createdAt)} by $by', style: t.bodySmall),
      trailing: i.open
          ? Wrap(
              children: [
                IconButton(tooltip: 'Copy link', onPressed: onCopy, icon: const Icon(Icons.copy, size: 18)),
                IconButton(
                  tooltip: 'Cancel this link',
                  onPressed: () {
                    appState.revokeInvite(i);
                    onChanged();
                  },
                  icon: Icon(Icons.link_off, size: 18, color: cs.error),
                ),
              ],
            )
          : null,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int? count;
  const _SectionHeader({required this.icon, required this.title, this.count});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(count == null ? title : '$title · $count', style: Theme.of(context).textTheme.titleMedium)),
          ],
        ),
      );
}

class _CountPill extends StatelessWidget {
  final String text;
  final Color color;
  const _CountPill(this.text, {required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            style: TextStyle(
                color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black,
                fontSize: 11.5,
                fontWeight: FontWeight.w800)),
      );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );
}

class _GapLabel extends StatelessWidget {
  final double gap;
  final double experts;
  final int acaps;
  const _GapLabel({required this.gap, required this.experts, required this.acaps});

  @override
  Widget build(BuildContext context) {
    final up = gap > 0.25, down = gap < -0.25;
    final color = up ? AppColors.high : (down ? AppColors.low : Theme.of(context).colorScheme.onSurfaceVariant);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(up ? Icons.trending_up : (down ? Icons.trending_down : Icons.trending_flat), size: 16, color: color),
        const SizedBox(width: 3),
        Flexible(
          // [experts] is the group's median forecast; halfway means between two steps.
          child: Text(
              'Forecast: experts ${experts == experts.roundToDouble() ? levelLabels[experts.round() - 1] : '${levelLabels[experts.floor() - 1]}–${levelLabels[experts.ceil() - 1]}'}'
              ' · ACAPS ${levelLabels[acaps - 1]}',
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ),
      ],
    );
  }
}

/// List on the left, details on the right when there is room.
class _SplitView extends StatelessWidget {
  final Widget list;
  final Widget? detail;
  final String emptyText;
  final double listWidth;
  const _SplitView({required this.list, required this.detail, required this.emptyText, this.listWidth = 400});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < _splitBreakpoint) return list;
        return Row(
          children: [
            SizedBox(width: listWidth, child: list),
            const VerticalDivider(width: 1),
            Expanded(child: detail ?? Center(child: Text(emptyText))),
          ],
        );
      },
    );
  }
}

// ===========================================================================
// Risks: search + status on screen, everything else in a filter sheet
// ===========================================================================

class _RisksTab extends StatelessWidget {
  final RiskFilter filter;
  final String? selectedId;
  final ValueChanged<Risk> onSelect;
  final OpenReview onReview;
  final VoidCallback onNewRisk;
  const _RisksTab({required this.filter, required this.selectedId, required this.onSelect, required this.onReview, required this.onNewRisk});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final split = box.maxWidth >= _splitBreakpoint;
        final selected = selectedId == null ? null : appState.byId(selectedId!);
        return _SplitView(
          list: ListenableBuilder(
            listenable: filter,
            builder: (context, _) => _RiskList(filter: filter, selectedId: split ? selectedId : null, onSelect: onSelect, onNewRisk: onNewRisk),
          ),
          detail: selected == null ? null : ModRiskDetail(key: ValueKey(selected.id), risk: selected, onReview: onReview),
          emptyText: 'Pick a risk on the left.',
        );
      },
    );
  }
}

class _RiskList extends StatefulWidget {
  final RiskFilter filter;
  final String? selectedId;
  final ValueChanged<Risk> onSelect;
  final VoidCallback onNewRisk;
  const _RiskList({required this.filter, required this.selectedId, required this.onSelect, required this.onNewRisk});

  @override
  State<_RiskList> createState() => _RiskListState();
}

class _RiskListState extends State<_RiskList> {
  late final _search = TextEditingController(text: widget.filter.query);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = widget.filter;
    if (_search.text != f.query) _search.text = f.query;
    final rows = f.apply(appState.risks);
    final n = f.sheetCount;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            Expanded(child: Text('Risks', style: t.headlineSmall)),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: widget.onNewRisk,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New risk'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search ID, title, country or category', isDense: true),
                onChanged: (v) => f.update((x) => x.query = v),
              ),
            ),
            const SizedBox(width: 8),
            Badge(
              isLabelVisible: n > 0,
              label: Text('$n'),
              child: IconButton.filledTonal(
                tooltip: 'Filter and sort',
                onPressed: () => showRiskFilterSheet(context, f),
                icon: const Icon(Icons.tune),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SegmentedButton<RiskStatus>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: RiskStatus.active, label: Text('Active')),
            ButtonSegment(value: RiskStatus.archive, label: Text('Archive')),
            ButtonSegment(value: RiskStatus.all, label: Text('All')),
          ],
          selected: {f.status},
          onSelectionChanged: (v) => f.update((x) => x.status = v.first),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 2),
          child: Row(
            children: [
              Expanded(
                child: Text('${rows.length} ${rows.length == 1 ? 'risk' : 'risks'} · ${f.sort.label.toLowerCase()}',
                    style: t.labelLarge, overflow: TextOverflow.ellipsis),
              ),
              if (n > 0 || f.query.isNotEmpty)
                TextButton(onPressed: () => f.update((x) => x.clear()), child: const Text('Clear')),
            ],
          ),
        ),
        if (rows.isEmpty) const _Empty('No risks match.'),
        for (final (r, s) in rows) _ModRiskTile(risk: r, s: s, selected: r.id == widget.selectedId, onTap: () => widget.onSelect(r)),
      ],
    );
  }
}

/// "Experts split": the panel disagrees among itself on the forecast.
class _SplitPill extends StatelessWidget {
  const _SplitPill();

  @override
  Widget build(BuildContext context) {
    final c = agreementColors[Agreement.partly]!;
    return Tooltip(
      message: 'Experts disagree among themselves: no clear group view. This part of the analysis may need attention.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withAlpha(40), borderRadius: BorderRadius.circular(10), border: Border.all(color: c)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.call_split, size: 13, color: c),
            const SizedBox(width: 3),
            Text('experts split', style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

/// A risk in the moderator list: who/where, what, and one line of status.
class _ModRiskTile extends StatelessWidget {
  final Risk risk;
  final RiskModStats s;
  final bool selected;
  final VoidCallback onTap;
  const _ModRiskTile({required this.risk, required this.s, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final status = [
      '${s.answered}/${s.panel} answered',
      if (s.comments > 0) '${s.comments} ${s.comments == 1 ? 'comment' : 'comments'}',
      if (s.moved != 0) 'view ${s.moved > 0 ? 'up' : 'down'} this month',
      if (s.panel < minPanel) 'too few experts',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      color: selected ? cs.primary.withAlpha(28) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${risk.id} · ${risk.country}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
                  ),
                  LevelBadge(risk.level),
                ],
              ),
              const SizedBox(height: 6),
              Text(risk.oneLiner, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall),
              const SizedBox(height: 6),
              CategoryChips(risk, compact: true, maxNeeds: 2),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: Text(status, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (s.split) ...[const _SplitPill(), const SizedBox(width: 6)],
                  if (s.toReview > 0) _CountPill('${s.toReview} new', color: cs.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// One risk: everything ACAPS knows about it, triggers in full
// ===========================================================================

class ModRiskScreen extends StatelessWidget {
  final Risk risk;
  final OpenReview onReview;
  const ModRiskScreen({super.key, required this.risk, required this.onReview});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Risk · ${risk.id}')),
        body: ListenableBuilder(
          listenable: appState,
          builder: (context, _) => ModRiskDetail(risk: appState.byId(risk.id) ?? risk, onReview: onReview),
        ),
      );
}

class ModRiskDetail extends StatelessWidget {
  final Risk risk;
  final OpenReview onReview;
  const ModRiskDetail({super.key, required this.risk, required this.onReview});

  Risk get r => risk;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final s = appState.modStats(r);
    final comments = appState.commentsOn(r);
    final thin = [for (final c in AppState.riskCountries(r)) (c, appState.panelFor(c).length)].where((x) => x.$2 < minPanel).toList();
    final inSurvey = r.surveyItems.map((i) => i.id).toSet();
    final p = r.probabilityIdx;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              RiskHeader(risk: r),
              if (r.title != r.oneLiner) ...[
                const SizedBox(height: 12),
                Text(r.title, style: t.titleSmall),
              ],
              if (r.custom) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Pill('Added in the app', icon: Icons.edit_note),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RiskFormScreen(initial: r))),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed: () => _confirmDelete(context, r),
                      icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
                      label: Text('Delete', style: TextStyle(color: cs.error)),
                    ),
                  ],
                ),
              ],
              if (thin.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: cs.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.error.withAlpha(90)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Not enough experts in ${thin.map((x) => '${x.$1} (${x.$2 == 0 ? 'none' : '${x.$2} of $minPanel'})').join(', ')}. '
                          'Results there could reveal who answered.',
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SectionLabel('ACAPS assessment'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Fact('Risk ID', r.id),
                  _Fact('Type', r.type.isEmpty ? '-' : r.type),
                  _Fact('Expected exposure', r.exposureIdx == null ? '-' : '${r.exposure} people'),
                  _Fact('Status', r.status.isEmpty ? '-' : r.status),
                  _Fact('Countries', r.country),
                  _Fact('Probability', p == null ? 'Unrated' : levelLabels[p]),
                  _Fact('Impact', r.impact == null ? '-' : '${r.impact} of 5'),
                  _Fact('Risk level', r.level.isEmpty ? 'Unrated' : r.level),
                  if (r.trend.isNotEmpty) _Fact('Trend', r.trend),
                ],
              ),
              if (r.needList.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('EXPECTED PRIORITY NEEDS',
                    style: TextStyle(fontSize: 10.5, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final n in r.needList) Pill(n, icon: Icons.sell_outlined)]),
              ],

              const SectionLabel('Expert answers'),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${s.answered} of ${s.panel} experts answered', style: t.titleSmall),
                            const SizedBox(height: 4),
                            if (s.gap != null) _GapLabel(gap: s.gap!, experts: s.expertLikelihood!, acaps: s.acapsLikelihood!),
                            if (s.answered > 0) Text('Disagree with ACAPS: ${(s.disagreement * 100).round()}%', style: t.bodySmall),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showPublicPreview(context, r),
                        icon: const Icon(Icons.output, size: 18),
                        label: const Text('Expert input'),
                      ),
                    ],
                  ),
                ),
              ),
              if (s.answered > 0) ...[
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Forecast: will it materialise within 6 months?', style: t.labelLarge),
                        const SizedBox(height: 6),
                        _GroupForecast(risk: r),
                        Distribution(counts: _forecastCounts(r), acaps: r.acapsLikelihood, labels: forecastButtonLabels),
                      ],
                    ),
                  ),
                ),
              ],

              SectionLabel('Triggers · ${r.triggers.length}'),
              if (r.triggers.isEmpty)
                Text('No triggers. Experts answer on the risk as a whole.', style: t.bodySmall)
              else ...[
                if (r.triggers.length > inSurvey.length)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('Experts are asked about the first ${inSurvey.length} triggers.', style: t.bodySmall),
                  ),
                for (var i = 0; i < r.triggers.length; i++)
                  _TriggerCard(
                    trigger: r.triggers[i],
                    number: i + 1,
                    inSurvey: inSurvey.contains(r.triggers[i].id),
                    comments: comments.where((c) => c.itemId == r.triggers[i].id).toList(),
                    onOpenComments: () => onReview(r, trigger: r.triggers[i].id),
                  ),
              ],

              const SectionLabel('Analysis'),
              _TextSection(title: 'Rationale', text: r.rationale, initiallyExpanded: true),
              _TextSection(title: r.isResolved ? 'What happened' : 'If it materialises', text: r.materialisation),
            ],
          ),
        ),
        // Always in reach at the bottom: go and review what experts said.
        Material(
          elevation: 3,
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: FilledButton.icon(
                onPressed: comments.isEmpty ? null : () => onReview(r),
                icon: const Icon(Icons.forum_outlined),
                label: Text(comments.isEmpty
                    ? 'No comments yet'
                    : s.toReview > 0
                        ? 'Review comments · ${s.toReview} new'
                        : 'Review comments · ${comments.length}'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  const _Fact(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withAlpha(140), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10.5, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// "R1043 - T0618" -> "T0618".
String _shortTriggerId(String id) => id.contains(' - ') ? id.split(' - ').last : id;

/// How close ACAPS thinks a trigger is to being reached.
class _CompletionBar extends StatelessWidget {
  final int completion;
  const _CompletionBar(this.completion);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'How close ACAPS thinks this trigger is to being reached',
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: completion / 100,
                minHeight: 7,
                color: Color.lerp(scaleColors[1], scaleColors[4], completion / 100),
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$completion% reached', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
        ],
      ),
    );
  }
}

/// One trigger in full: id, title, completion, description, comment counts.
class _TriggerCard extends StatefulWidget {
  final Trigger trigger;
  final int number;
  final bool inSurvey;
  final List<Comment> comments;
  final VoidCallback onOpenComments;
  const _TriggerCard({
    required this.trigger,
    required this.number,
    required this.inSurvey,
    required this.comments,
    required this.onOpenComments,
  });

  @override
  State<_TriggerCard> createState() => _TriggerCardState();
}

class _TriggerCardState extends State<_TriggerCard> {
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tr = widget.trigger;
    final fresh = widget.comments.where((c) => c.needsReview).length;
    final long = tr.description.length > 260;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Pill('Trigger ${widget.number} · ${_shortTriggerId(tr.id)}', icon: Icons.flag_outlined),
                if (!widget.inSurvey) const Pill('Not asked in the survey'),
                if (widget.comments.isNotEmpty)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Open the comments on this trigger',
                    avatar: const Icon(Icons.forum_outlined, size: 16),
                    label: Text('${widget.comments.length} ${widget.comments.length == 1 ? 'comment' : 'comments'}'
                        '${fresh > 0 ? ' · $fresh new' : ''} · open'),
                    onPressed: widget.onOpenComments,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(tr.title, style: t.titleSmall),
            if (tr.completion != null) ...[
              const SizedBox(height: 8),
              _CompletionBar(tr.completion!),
            ],
            if (tr.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                tr.description,
                maxLines: _more || !long ? null : 4,
                overflow: _more || !long ? null : TextOverflow.ellipsis,
                style: t.bodySmall?.copyWith(height: 1.45),
              ),
              if (long)
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                  onPressed: () => setState(() => _more = !_more),
                  child: Text(_more ? 'Less' : 'Read more'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A long analysis text, collapsed to one tap.
class _TextSection extends StatelessWidget {
  final String title;
  final String text;
  final bool initiallyExpanded;
  const _TextSection({required this.title, required this.text, this.initiallyExpanded = false});

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [SelectableText(text, style: const TextStyle(height: 1.45))],
      ),
    );
  }
}

Future<void> _confirmDelete(BuildContext context, Risk r) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete ${r.id}?'),
      content: const Text('The risk, its answers and its comments are removed. This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  Navigator.of(context).maybePop();
  appState.deleteRisk(r);
}

// ===========================================================================
// Comments: review what experts say, trigger by trigger
// ===========================================================================

class _CommentsTab extends StatelessWidget {
  final String? selectedId;
  final String? focusTrigger;
  final int opens;
  final ValueChanged<Risk> onSelect;
  final ValueChanged<Risk> onOpenDetails;
  const _CommentsTab({
    required this.selectedId,
    required this.focusTrigger,
    required this.opens,
    required this.onSelect,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final split = box.maxWidth >= _splitBreakpoint;
        final selected = selectedId == null ? null : appState.byId(selectedId!);
        return _SplitView(
          listWidth: 380,
          list: _ReviewList(selectedId: split ? selectedId : null, onSelect: onSelect),
          detail: selected == null
              ? null
              : ModRiskReview(
                  key: ValueKey('${selected.id}|$focusTrigger|$opens'),
                  risk: selected,
                  focusTrigger: focusTrigger,
                  onOpenDetails: onOpenDetails,
                ),
          emptyText: 'Pick a risk on the left to review its comments.',
        );
      },
    );
  }
}

/// Small caps label saying what the controls next to it apply to.
class _ScopeLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ScopeLabel(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text.toUpperCase(),
                style: TextStyle(fontSize: 10.5, letterSpacing: 0.9, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _ReviewList extends StatefulWidget {
  final String? selectedId;
  final ValueChanged<Risk> onSelect;
  const _ReviewList({required this.selectedId, required this.onSelect});

  /// Risks with comments: (risk, new, total), most new first.
  static List<(Risk, int, int)> risksWithComments({required bool onlyNew}) {
    final total = <String, int>{}, fresh = <String, int>{};
    for (final c in appState.comments) {
      total[c.riskId] = (total[c.riskId] ?? 0) + 1;
      if (c.needsReview) fresh[c.riskId] = (fresh[c.riskId] ?? 0) + 1;
    }
    return [
      for (final e in total.entries)
        if (appState.byId(e.key) case final r? when !onlyNew || (fresh[e.key] ?? 0) > 0) (r, fresh[e.key] ?? 0, e.value),
    ]..sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : b.$3.compareTo(a.$3));
  }

  @override
  State<_ReviewList> createState() => _ReviewListState();
}

class _ReviewListState extends State<_ReviewList> {
  late bool _onlyNew = appState.commentsToReview > 0;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final q = _q.toLowerCase();
    final fresh = _ReviewList.risksWithComments(onlyNew: true);
    final all = _ReviewList.risksWithComments(onlyNew: false);
    final rows = (_onlyNew ? fresh : all).where((x) => q.isEmpty || x.$1.searchText.contains(q));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text('Comments', style: t.headlineSmall),
        const SizedBox(height: 4),
        Text('What experts say ACAPS is missing. Pick a risk to review its comments.', style: t.bodySmall),
        const SizedBox(height: 14),
        const _ScopeLabel(Icons.filter_list, 'Which risks to list'),
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search risks by ID, title, country or category', isDense: true),
          onChanged: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: true, label: Text('With new comments · ${fresh.length}')),
              ButtonSegment(value: false, label: Text('All · ${all.length}')),
            ],
            selected: {_onlyNew},
            onSelectionChanged: (v) => setState(() => _onlyNew = v.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Text('${rows.length} ${rows.length == 1 ? 'risk' : 'risks'}', style: t.labelLarge),
        ),
        if (rows.isEmpty) _Empty(_onlyNew ? 'No risks with new comments. All caught up.' : 'No risks match.'),
        for (final (r, n, total) in rows)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: r.id == widget.selectedId ? cs.primary.withAlpha(28) : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: r.id == widget.selectedId ? cs.primary : cs.outlineVariant, width: r.id == widget.selectedId ? 2 : 1),
            ),
            child: ListTile(
              onTap: () => widget.onSelect(r),
              title: Text(r.oneLiner, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${r.id} · ${r.country} · $total ${total == 1 ? 'comment' : 'comments'}',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (n > 0) _CountPill('$n new', color: cs.primary),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ModReviewScreen extends StatelessWidget {
  final Risk risk;
  final String? focusTrigger;
  final ValueChanged<Risk> onOpenDetails;
  const ModReviewScreen({super.key, required this.risk, this.focusTrigger, required this.onOpenDetails});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Comments · ${risk.id}')),
        body: ListenableBuilder(
          listenable: appState,
          builder: (context, _) =>
              ModRiskReview(risk: appState.byId(risk.id) ?? risk, focusTrigger: focusTrigger, onOpenDetails: onOpenDetails),
        ),
      );
}

/// Review page for one risk: per trigger, its details and what experts said.
class ModRiskReview extends StatefulWidget {
  final Risk risk;

  /// Trigger to scroll to and highlight (opened from a trigger on the Risks tab).
  final String? focusTrigger;
  final ValueChanged<Risk> onOpenDetails;
  const ModRiskReview({super.key, required this.risk, this.focusTrigger, required this.onOpenDetails});

  @override
  State<ModRiskReview> createState() => _ModRiskReviewState();
}

class _ModRiskReviewState extends State<ModRiskReview> {
  /// Opens on "new only" when there is something new, unless a trigger was
  /// opened on purpose: then all of its comments are shown.
  late bool _onlyNew = widget.focusTrigger == null && appState.modStats(widget.risk).toReview > 0;
  final _triggerKeys = <String, GlobalKey>{};

  Risk get r => widget.risk;

  @override
  void initState() {
    super.initState();
    final focus = widget.focusTrigger;
    if (focus == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _triggerKeys[focus]?.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic, alignment: 0.02);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final items = r.surveyItems;
    final s = appState.modStats(r);
    final all = appState.commentsOn(r);
    bool keep(Comment c) => !_onlyNew || c.needsReview;
    int order(Comment a, Comment b) => a.needsReview != b.needsReview
        ? (a.needsReview ? -1 : 1)
        : b.agreeIds.length.compareTo(a.agreeIds.length);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // Which risk this page is about: everything below applies to it only.
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
          decoration: BoxDecoration(
            color: levelColor(r.level).withAlpha(Theme.of(context).brightness == Brightness.dark ? 45 : 26),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ScopeLabel(Icons.fact_check_outlined, 'Reviewing comments on this risk'),
              Text('${r.id}  ·  ${r.country.toUpperCase()}',
                  style: TextStyle(fontSize: 11.5, letterSpacing: 0.9, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(r.oneLiner, style: t.titleMedium),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text('${s.answered} of ${s.panel} experts answered · ${all.length} '
                        '${all.length == 1 ? 'comment' : 'comments'}, ${s.toReview} new', style: t.bodySmall),
                  ),
                  TextButton.icon(
                    onPressed: () => widget.onOpenDetails(r),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Risk details'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (all.isNotEmpty) ...[
          _ScopeLabel(Icons.visibility_outlined, 'Comments to show for ${r.id}'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: true, label: Text('New only · ${s.toReview}')),
                ButtonSegment(value: false, label: Text('All · ${all.length}')),
              ],
              selected: {_onlyNew},
              onSelectionChanged: (v) => setState(() => _onlyNew = v.first),
            ),
          ),
        ],
        for (var i = 0; i < items.length; i++) ...[
          Container(
            key: _triggerKeys.putIfAbsent(items[i].id, GlobalKey.new),
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: items[i].id == widget.focusTrigger ? cs.primary.withAlpha(22) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QuestionHeader(number: i + 1, total: items.length, title: items[i].title),
          ),
          _TriggerInfo(item: items[i]),
          Card(
            margin: const EdgeInsets.only(top: 8),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              dense: true,
              leading: const Icon(Icons.bar_chart, size: 20),
              title: Text('How experts answered ${items.length == 1 ? 'this risk' : 'this trigger'} · '
                  '${appState.answersFor(r, items[i].id).length}'),
              childrenPadding: EdgeInsets.zero,
              children: [ItemSummary(risk: r, item: items[i], mine: null)],
            ),
          ),
          _ModCommentList(
            comments: all.where((c) => c.itemId == items[i].id && keep(c)).toList()..sort(order),
            hiddenByFilter: all.where((c) => c.itemId == items[i].id && !keep(c)).length,
            risk: r,
          ),
          if (i < items.length - 1) const Divider(height: 36),
        ],
      ],
    );
  }
}

/// Trigger context above its comments: completion and description.
class _TriggerInfo extends StatefulWidget {
  final SurveyItem item;
  const _TriggerInfo({required this.item});

  @override
  State<_TriggerInfo> createState() => _TriggerInfoState();
}

class _TriggerInfoState extends State<_TriggerInfo> {
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final it = widget.item;
    if (it.completion == null && it.description.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (it.completion != null) ...[_CompletionBar(it.completion!), const SizedBox(height: 6)],
        if (it.description.isNotEmpty) ...[
          Text(
            it.description,
            maxLines: _more ? null : 3,
            overflow: _more ? null : TextOverflow.ellipsis,
            style: t.bodySmall?.copyWith(height: 1.45),
          ),
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
            onPressed: () => setState(() => _more = !_more),
            child: Text(_more ? 'Less' : 'Full trigger description'),
          ),
        ],
      ],
    );
  }
}

class _ModCommentList extends StatelessWidget {
  final List<Comment> comments;
  final int hiddenByFilter;
  final Risk risk;
  const _ModCommentList({required this.comments, required this.hiddenByFilter, required this.risk});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 12, left: 8),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: cs.primary.withAlpha(150), width: 3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.forum_outlined, size: 16, color: cs.primary),
              Text('Comments on this ${risk.surveyItems.length == 1 ? 'risk' : 'trigger'} · ${comments.length}', style: t.labelLarge),
              if (hiddenByFilter > 0) Text('(+$hiddenByFilter already reviewed, hidden)', style: t.bodySmall),
            ],
          ),
          if (comments.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Nothing here.', style: t.bodySmall))
          else
            for (final c in comments) _ModComment(comment: c, risk: risk),
        ],
      ),
    );
  }
}

/// "you" for the signed-in moderator, else their short name.
String _modName(String? id) =>
    id == appState.sessionModeratorId ? 'you' : (moderatorById(id)?.shortName ?? 'a moderator');

class _ModComment extends StatelessWidget {
  final Comment comment;
  final Risk risk;
  const _ModComment({required this.comment, required this.risk});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final c = comment;
    final author = appState.expertById(c.authorId);
    final name = author == null ? anonymousName : displayName(author, Viewer.moderator);
    final rc = AppState.riskCountries(risk);
    final pending = c.needsReview;
    final signed = [
      if (c.usefulBy != null) 'Marked useful by ${_modName(c.usefulBy)}',
      if (c.usedBy != null) 'Used in ${c.usedInRiskId} by ${_modName(c.usedBy)}',
      if (c.reviewed && c.reviewedBy != null && c.usefulBy == null && c.usedBy == null) 'Reviewed by ${_modName(c.reviewedBy)}',
    ];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pending ? cs.primary.withAlpha(180) : cs.outlineVariant, width: pending ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name, size: 24),
              const SizedBox(width: 8),
              Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
              if (author != null) ...[
                const SizedBox(width: 6),
                Pill('L${author.level.number}${author.level == Anonymity.anonymous ? '' : ' · ${author.homeCountry}'}'),
              ],
              const Spacer(),
              if (pending)
                Text('NEW', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
            ],
          ),
          // How far to trust the author: how they got in, and what they do.
          if (author != null) ...[const SizedBox(height: 6), TrustPills(author)],
          const SizedBox(height: 8),
          Text(c.text, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 8),
          Tooltip(
            message: 'Agree: ${describeSplit(appState.expertsByIds(c.agreeIds), rc)}\n'
                'Disagree: ${describeSplit(appState.expertsByIds(c.disagreeIds), rc)}',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.thumb_up_alt_outlined, size: 15, color: cs.onSurfaceVariant),
                Text(' ${c.agreeIds.length}   ', style: t.bodySmall),
                Icon(Icons.thumb_down_alt_outlined, size: 15, color: cs.onSurfaceVariant),
                Text(' ${c.disagreeIds.length}', style: t.bodySmall),
              ],
            ),
          ),
          const Divider(height: 18),
          const _ScopeLabel(Icons.touch_app_outlined, 'Actions for this comment only'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                tooltip: 'The author gets ${Points.usefulComment} points',
                avatar: const Icon(Icons.lightbulb_outline, size: 18),
                label: Text('Useful · +${Points.usefulComment} pts to author'),
                selected: c.useful,
                onSelected: (_) => appState.toggleUseful(c),
              ),
              if (c.usedInRiskId == null)
                ActionChip(
                  tooltip: 'Pick the risk whose analysis this comment fed into. The author gets ${Points.usedComment} points',
                  avatar: const Icon(Icons.push_pin_outlined, size: 18),
                  label: Text('Used in another risk · +${Points.usedComment} pts'),
                  onPressed: () async {
                    final id = await _pickRisk(context, exclude: risk.id);
                    if (id != null) appState.setUsedIn(c, id);
                  },
                )
              else
                InputChip(
                  avatar: const Icon(Icons.push_pin, size: 18),
                  label: Text('Used in the analysis of ${c.usedInRiskId}'),
                  selected: true,
                  onDeleted: () => appState.setUsedIn(c, null),
                ),
              if (pending)
                TextButton.icon(
                  onPressed: () => appState.setReviewed(c, true),
                  icon: const Icon(Icons.done, size: 18),
                  label: const Text('Mark reviewed'),
                )
              else if (!c.useful && c.usedInRiskId == null)
                TextButton.icon(
                  onPressed: () => appState.setReviewed(c, false),
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Reviewed · undo'),
                ),
            ],
          ),
          if (signed.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.verified_outlined, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(child: Text(signed.join(' · '), style: t.bodySmall)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Future<String?> _pickRisk(BuildContext context, {required String exclude}) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RiskPicker(exclude: exclude),
    );

class _RiskPicker extends StatefulWidget {
  final String exclude;
  const _RiskPicker({required this.exclude});

  @override
  State<_RiskPicker> createState() => _RiskPickerState();
}

class _RiskPickerState extends State<_RiskPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = appState.risks
        .where((r) => r.id != widget.exclude && r.isActive)
        .where((r) => q.isEmpty || '${r.id} ${r.title} ${r.country}'.toLowerCase().contains(q))
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Used in the analysis of which risk?', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search active risks', isDense: true),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final r in list)
                  ListTile(
                    title: Text(r.oneLiner, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${r.id} · ${r.country}'),
                    trailing: LevelBadge(r.level),
                    onTap: () => Navigator.pop(context, r.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The expert input for ACAPS's own systems: the risk's Risk Radar / API
/// fields plus aggregated expert answers (and, if chosen, named contributors).
/// ACAPS's website is fed from its API, so this is data for ACAPS to pull in,
/// not a page to upload.
void _showPublicPreview(BuildContext context, Risk r) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PublishSheet(risk: r),
  );
}

class _PublishSheet extends StatefulWidget {
  final Risk risk;
  const _PublishSheet({required this.risk});

  @override
  State<_PublishSheet> createState() => _PublishSheetState();
}

class _PublishSheetState extends State<_PublishSheet> {
  bool _credits = true;

  void _export(List<Risk> rs, String name) {
    final json = appState.publicViewJson(rs, credits: _credits);
    if (canDownload) {
      downloadText(name, json);
    } else {
      _copy(json);
    }
  }

  void _copy(String json) {
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON copied')));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final r = widget.risk;
    final n = appState.respondents(r).length;
    final all = appState.publishableRisks;
    final credited = appState.creditsFor(r);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('Expert input for ACAPS · ${r.id}', style: t.titleLarge),
          const SizedBox(height: 4),
          Text('Ready for ACAPS\'s own systems: the risk\'s fields use the same names as the Risk Radar '
              'export and API, with the experts\' aggregated answers added. '
              'Aggregates only: no comments, no respondent countries, no names next to answers. '
              'Results are hidden below $minPanel respondents.', style: t.bodySmall),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _credits,
            onChanged: (v) => setState(() => _credits = v),
            title: const Text('Include experts who chose to be named'),
            subtitle: const Text('Each expert chooses per risk: real name, pseudonym or anonymous. The default matches their profile\'s anonymity level.'),
          ),
          if (_credits && n >= minPanel)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cs.surfaceContainerHighest.withAlpha(120), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contributors', style: t.labelLarge),
                  const SizedBox(height: 6),
                  if (credited.isEmpty)
                    Text('Nobody asked to be named.', style: t.bodySmall)
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in credited)
                          Pill(c.name, icon: c.as == Credit.realName ? Icons.person_outline : Icons.masks_outlined),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Text('+ ${n - credited.length} anonymous', style: t.bodySmall),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _export([r], 'expert-input-${r.id.toLowerCase()}.json'),
                icon: Icon(canDownload ? Icons.download : Icons.copy, size: 18),
                label: const Text('This risk (JSON)'),
              ),
              OutlinedButton.icon(
                onPressed: all.isEmpty ? null : () => _export(all, 'expert-input-all.json'),
                icon: Icon(canDownload ? Icons.download : Icons.copy, size: 18),
                label: Text('All risks with enough answers · ${all.length} (JSON)'),
              ),
              TextButton.icon(
                onPressed: () => _copy(appState.publicViewJson([r], credits: _credits)),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy JSON'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (n < minPanel)
            InfoBanner(icon: Icons.visibility_off_outlined, text: 'Only $n respondents: no expert results or names are shared for this risk. The export contains the ACAPS fields only.')
          else ...[
            Text('${r.oneLiner}\n$n experts', style: t.titleSmall),
            const SizedBox(height: 14),
            Text('Forecast: will it materialise within 6 months?', style: t.labelLarge),
            const SizedBox(height: 6),
            _GroupForecast(risk: r),
            Distribution(counts: _forecastCounts(r), acaps: r.acapsLikelihood, labels: forecastButtonLabels),
          ],
        ],
      ),
    );
  }
}

List<int> _forecastCounts(Risk r) => countsOf(appState.forecastsFor(r));

/// "Group: High (67–90%)" and how far experts agree, same as experts see it.
class _GroupForecast extends StatelessWidget {
  final Risk risk;
  const _GroupForecast({required this.risk});

  @override
  Widget build(BuildContext context) {
    final g = GroupView.of(appState.forecastsFor(risk));
    if (g == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [GroupLine(group: g, forecast: true, noun: 'forecast'), TrendLine(risk: risk)],
    );
  }
}

// ===========================================================================
// Experts: one directory, sortable by rating
// ===========================================================================

/// The two trust signals moderators see for an expert: how they got in (an
/// ACAPS invite or an expert's referral) and what they do in the app.
/// Neither says who they are; colleagues and the expert never see this.
class TrustPills extends StatelessWidget {
  final Expert expert;
  const TrustPills(this.expert, {super.key});

  static IconData joinIcon(JoinedVia j) =>
      j == JoinedVia.acapsInvite ? Icons.verified_user_outlined : Icons.handshake_outlined;

  static IconData activityIcon(Activity a) => switch (a) {
        Activity.newcomer => Icons.fiber_new_outlined,
        Activity.active => Icons.bolt,
        Activity.established => Icons.workspace_premium_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final a = appState.expertActivity(expert);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        Tooltip(
          message: expert.joinedVia == JoinedVia.acapsInvite
              ? 'Joined with a single-use invite link from an ACAPS moderator'
              : 'Joined with the referral link of an expert already in the group',
          child: Pill(expert.joinedVia.label, icon: joinIcon(expert.joinedVia)),
        ),
        Tooltip(message: a.why, child: Pill(a.label, icon: activityIcon(a))),
      ],
    );
  }
}

enum _ExpertSort { points, accuracy, answers, name }

extension on _ExpertSort {
  String get label => switch (this) {
        _ExpertSort.points => 'Points',
        _ExpertSort.accuracy => 'Accuracy',
        _ExpertSort.answers => 'Answers',
        _ExpertSort.name => 'Name',
      };
}

class _ExpertsTab extends StatefulWidget {
  const _ExpertsTab();

  @override
  State<_ExpertsTab> createState() => _ExpertsTabState();
}

class _ExpertsTabState extends State<_ExpertsTab> {
  String _q = '';
  String? _country;
  _ExpertSort _sort = _ExpertSort.points;

  /// Filter by how experts joined (null = everyone).
  JoinedVia? _joined;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: appState, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final q = _q.toLowerCase();
    final rows = appState.experts
        .where((e) => _country == null || e.inPanel(_country!))
        .where((e) => _joined == null || e.joinedVia == _joined)
        .where((e) => q.isEmpty || '${displayName(e, Viewer.moderator)} ${e.pseudonym} ${e.homeCountry}'.toLowerCase().contains(q))
        .map((e) => (e, appState.statsOf(e), appState.responsesOf(e).length))
        .toList()
      ..sort((a, b) => switch (_sort) {
            _ExpertSort.points => b.$2.points.compareTo(a.$2.points),
            _ExpertSort.accuracy => (a.$2.brier ?? 2).compareTo(b.$2.brier ?? 2),
            _ExpertSort.answers => b.$3.compareTo(a.$3),
            _ExpertSort.name => displayName(a.$1, Viewer.moderator).compareTo(displayName(b.$1, Viewer.moderator)),
          });
    final panelN = _country == null ? null : appState.panelFor(_country!).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          children: [
            Expanded(child: Text('Experts', style: t.headlineSmall)),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(appBar: AppBar(title: const Text('Rating as experts see it')), body: const RatingTab()),
              )),
              icon: const Icon(Icons.emoji_events_outlined, size: 18),
              label: const Text('Leaderboard'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name, pseudonym or country', isDense: true),
          onChanged: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownMenu<String?>(
                expandedInsets: EdgeInsets.zero,
                initialSelection: _country,
                menuHeight: 320,
                label: const Text('Country'),
                textStyle: const TextStyle(fontSize: 13.5),
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: null, label: 'All countries'),
                  for (final c in appState.countries) DropdownMenuEntry(value: c, label: c),
                ],
                onSelected: (v) => setState(() => _country = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownMenu<_ExpertSort>(
                expandedInsets: EdgeInsets.zero,
                initialSelection: _sort,
                label: const Text('Sort by'),
                textStyle: const TextStyle(fontSize: 13.5),
                dropdownMenuEntries: [for (final s in _ExpertSort.values) DropdownMenuEntry(value: s, label: s.label)],
                onSelected: (v) {
                  if (v != null) setState(() => _sort = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // The door check: how experts got in (moderators only).
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ChoiceChip(label: const Text('Everyone'), selected: _joined == null, onSelected: (_) => setState(() => _joined = null)),
            for (final j in JoinedVia.values)
              ChoiceChip(
                avatar: Icon(TrustPills.joinIcon(j), size: 16),
                label: Text(j.label),
                selected: _joined == j,
                onSelected: (_) => setState(() => _joined = _joined == j ? null : j),
              ),
          ],
        ),
        // Panel size for the chosen country. Invites: the link button in the top bar.
        if (_country != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Icon(panelN! < minPanel ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                    size: 18, color: panelN < minPanel ? cs.error : cs.primary),
                const SizedBox(width: 6),
                Expanded(child: Text('$_country: $panelN ${panelN == 1 ? 'expert' : 'experts'} · target 5-10, minimum $minPanel', style: t.bodySmall)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text('${rows.length} ${rows.length == 1 ? 'expert' : 'experts'}', style: t.labelLarge),
        ),
        if (rows.isEmpty) const _Empty('Nobody here yet.'),
        for (final (e, st, answers) in rows)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: Avatar(displayName(e, Viewer.moderator), size: 36),
              title: Text(displayName(e, Viewer.moderator)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('L${e.level.number} · ${e.countries.join(', ')} · $answers answers'
                      '${st.brier == null ? '' : ' · accuracy ${accuracyPct(st.brier!)}%'}'),
                  const SizedBox(height: 4),
                  TrustPills(e),
                ],
              ),
              trailing: Text('${st.points}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              onTap: () => _showExpert(context, e),
            ),
          ),
      ],
    );
  }
}

void _showExpert(BuildContext context, Expert e) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final t = Theme.of(context).textTheme;
      final cs = Theme.of(context).colorScheme;
      final name = displayName(e, Viewer.moderator);
      final st = appState.statsOf(e);
      final cm = appState.commentsBy(e);
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              children: [
                Avatar(name, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: t.titleLarge),
                      Text('Level ${e.level.number}: ${e.level.label}', style: t.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SectionLabel('Trust', padding: EdgeInsets.only(top: 16, bottom: 6)),
            TrustPills(e),
            const SizedBox(height: 4),
            Text(
              '${e.joinedVia == JoinedVia.acapsInvite ? 'Joined with a single-use invite link from an ACAPS moderator.' : 'Joined with the referral link of an expert already in the group.'} '
              '${appState.expertActivity(e).why}. '
              'Neither says who they are; only moderators see this.',
              style: t.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Pill('Countries: ${e.countries.join(', ')}', icon: Icons.place_outlined),
                Pill('${appState.responsesOf(e).length} answers', icon: Icons.how_to_vote_outlined),
                Pill('${cm.length} comments · ${cm.where((c) => c.useful).length} useful', icon: Icons.forum_outlined),
                if (appState.referralsBy(e) case final n when n > 0)
                  Pill('$n ${n == 1 ? 'colleague' : 'colleagues'} joined via their link', icon: Icons.group_add_outlined),
                Pill('${st.points} points', icon: Icons.emoji_events_outlined),
                if (st.brier != null) Pill('accuracy ${accuracyPct(st.brier!)}%', icon: Icons.track_changes),
                if (!e.onRating) const Pill('not in rating', icon: Icons.visibility_off_outlined),
                if (e.hideFromOtherCountries) const Pill('hidden from other countries', icon: Icons.travel_explore),
              ],
            ),
            if (appState.badgesOf(e).isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: [for (final b in appState.badgesOf(e)) AwardIcon(b, size: 26)]),
            ],
            const SectionLabel('Database record'),
            Text(
              e.level == Anonymity.anonymous
                  ? 'Level 3: "real_name" is null. The name is deleted, not hidden.'
                  : 'Exactly what is stored for this expert.',
              style: t.bodySmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(e.toJson()),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.35),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ===========================================================================
// Profile: this moderator's own account
// ===========================================================================

class _ModProfileTab extends StatefulWidget {
  const _ModProfileTab();

  @override
  State<_ModProfileTab> createState() => _ModProfileTabState();
}

class _ModProfileTabState extends State<_ModProfileTab> {
  bool _confirmReset = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: appState, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final m = appState.moderator;
    if (m == null) return const SizedBox();
    final a = appState.activityOf(m);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          children: [
            Avatar(m.name, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name, style: t.titleLarge),
                  const SizedBox(height: 6),
                  const Pill('ACAPS moderator', icon: Icons.admin_panel_settings_outlined),
                ],
              ),
            ),
          ],
        ),

        const SectionLabel('Your activity'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                _ModStat(value: '${a.reviewed}', label: 'reviewed'),
                _ModStat(value: '${a.useful}', label: 'marked useful'),
                _ModStat(value: '${a.used}', label: 'used in analysis'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('Your reviews are signed with your name, so other moderators can see who handled what. '
            'Experts only see "ACAPS".', style: t.bodySmall),

        const SectionLabel('Display'),
        Text('Saved for your account only.', style: t.bodySmall),
        const SizedBox(height: 10),
        const DisplaySettings(),

        const SectionLabel('Account'),
        OutlinedButton.icon(
          onPressed: appState.signOut,
          icon: const Icon(Icons.switch_account_outlined),
          label: const Text('Switch user'),
        ),
        const SizedBox(height: 8),
        if (!_confirmReset)
          OutlinedButton.icon(
            onPressed: () => setState(() => _confirmReset = true),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset demo'),
          )
        else
          Card(
            color: cs.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Erase all answers, comments, reviews and new profiles on this device?', style: TextStyle(color: cs.onErrorContainer)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => setState(() => _confirmReset = false), child: const Text('Cancel'))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError, minimumSize: const Size.fromHeight(44)),
                          onPressed: appState.resetDemo,
                          child: const Text('Erase'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ModStat extends StatelessWidget {
  final String value;
  final String label;
  const _ModStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}
