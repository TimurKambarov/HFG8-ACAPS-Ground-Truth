import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'home.dart' show AwardIcon;

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late final _pseudo = TextEditingController(text: appState.me?.pseudonym ?? '');
  bool _confirmReset = false;

  @override
  void dispose() {
    _pseudo.dispose();
    super.dispose();
  }

  Future<void> _changeLevel(Anonymity next) async {
    final me = appState.me!;
    if (next == me.level) return;
    // Always confirm, showing who will see what after the change.
    final preview = Expert(id: '_preview', realName: me.realName ?? 'Your name', pseudonym: me.pseudonym, level: next, homeCountry: me.homeCountry,
        hideFromOtherCountries: me.hideFromOtherCountries);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(anonymityIcon(next)),
        title: Text('Change to level ${next.number}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${next.label}. ${next.description}'),
            const SizedBox(height: 14),
            _WhoRow(icon: Icons.verified_user_outlined, who: 'ACAPS moderators', sees: nameSeenBy(preview, ViewerRole.moderator)),
            _WhoRow(icon: Icons.groups_2_outlined, who: 'Colleagues from ${me.homeCountry}', sees: nameSeenBy(preview, ViewerRole.expert, sameCountry: true)),
            _WhoRow(icon: Icons.travel_explore, who: 'Colleagues from other countries', sees: nameSeenBy(preview, ViewerRole.expert)),
            _WhoRow(icon: Icons.public, who: 'Public', sees: nameSeenBy(preview, ViewerRole.public)),
            if (next == Anonymity.anonymous) ...[
              const SizedBox(height: 10),
              const Text('Your real name will be deleted from the database, not just hidden. '
                  'To go back to level 1 or 2 later, you will have to enter it again.',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ] else if (me.realName == null) ...[
              const SizedBox(height: 10),
              const Text('Next, you will be asked for your first and last name.'),
            ],
            const SizedBox(height: 10),
            const Text('This also changes how your past comments and rating entry are shown.', style: TextStyle(fontSize: 12.5)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(next == Anonymity.anonymous ? 'Delete my name' : 'Change level'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (next == Anonymity.anonymous) {
      appState.updateMe((e) => e.setLevel(next));
      return;
    }
    if (me.realName == null) {
      final name = await showDialog<String>(context: context, builder: (_) => const _NameDialog());
      if (name == null) return;
      appState.updateMe((e) => e.setLevel(next, name: name));
      return;
    }
    appState.updateMe((e) => e.setLevel(next));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final me = appState.me;
        if (me == null) return const SizedBox();
        final a = me.level;
        final name = displayName(me, appState.viewer);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              children: [
                Avatar(name, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: t.titleLarge),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        Pill('Level ${a.number}', icon: anonymityIcon(a)),
                        Pill(me.homeCountry, icon: Icons.place_outlined),
                      ]),
                    ],
                  ),
                ),
              ],
            ),

            // Forecasts and comment feedback live in the My forecasts tab.

            const SectionLabel('Anonymity level'),
            for (final opt in Anonymity.values)
              OptionTile(
                title: 'Level ${opt.number}: ${opt.label}',
                subtitle: opt.description,
                icon: anonymityIcon(opt),
                selected: a == opt,
                onTap: () => _changeLevel(opt),
              ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    _WhoRow(icon: Icons.verified_user_outlined, who: 'ACAPS moderators', sees: nameSeenBy(me, ViewerRole.moderator)),
                    const Divider(),
                    _WhoRow(icon: Icons.groups_2_outlined, who: 'Colleagues from ${me.homeCountry}', sees: nameSeenBy(me, ViewerRole.expert, sameCountry: true)),
                    const Divider(),
                    _WhoRow(icon: Icons.travel_explore, who: 'Colleagues from other countries', sees: nameSeenBy(me, ViewerRole.expert)),
                    const Divider(),
                    _WhoRow(icon: Icons.public, who: 'Public', sees: nameSeenBy(me, ViewerRole.public)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (a != Anonymity.anonymous)
              Card(
                child: CheckboxListTile(
                  value: me.hideFromOtherCountries,
                  onChanged: (v) => appState.updateMe((e) => e.hideFromOtherCountries = v ?? false),
                  secondary: const Icon(Icons.travel_explore),
                  title: const Text('Stay anonymous to colleagues from other countries'),
                  subtitle: Text('Colleagues from ${me.homeCountry} still see ${me.pseudonym}. '
                      'Everyone else sees "$anonymousName".'),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              me.realName == null
                  ? 'No real name is stored for you.'
                  : 'Stored real name: ${me.realName}. Only you see this here.',
              style: t.bodySmall,
            ),

            const SectionLabel('Invite a colleague'),
            _ReferralCard(me: me),

            const SectionLabel('Profile'),
            // The pseudonym is the login name, so it is fixed after sign-up.
            TextField(
              controller: _pseudo,
              readOnly: true,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Pseudonym',
                prefixIcon: Icon(Icons.alternate_email),
                helperText: 'Your login name. It cannot be changed.',
              ),
            ),
            const SizedBox(height: 12),
            CountryField(label: 'Your country', value: me.homeCountry, onChanged: (c) => appState.updateMe((e) => e.homeCountry = c)),
            const SizedBox(height: 12),
            InterestsField(selected: me.interests, exclude: me.homeCountry, onChanged: () => appState.updateMe((_) {})),

            const SectionLabel('Settings'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: me.notifications,
              onChanged: (v) => appState.updateMe((e) => e.notifications = v),
              title: const Text('Notify me when ACAPS updates a risk'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: me.onRating,
              onChanged: (v) => appState.updateMe((e) => e.onRating = v),
              title: const Text('Take part in the rating'),
            ),

            const SectionLabel('Display'),
            const DisplaySettings(),

            SectionLabel(appState.sessionAccountId != null ? 'Account' : 'Demo'),
            OutlinedButton.icon(
              onPressed: appState.signOut,
              icon: Icon(appState.sessionAccountId != null ? Icons.logout : Icons.switch_account_outlined),
              label: Text(appState.sessionAccountId != null ? 'Log out' : 'Switch user'),
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
                      Text('Erase all answers, comments and new profiles on this device?', style: TextStyle(color: cs.onErrorContainer)),
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
      },
    );
  }
}

/// The expert's own permanent referral code: colleagues they trust can join
/// the closed group with it. One code per expert, any number of colleagues.
/// There is no installed app yet, so the colleague types the code on the
/// start screen ("I have a code"); there is no link to open.
class _ReferralCard extends StatelessWidget {
  final Expert me;
  const _ReferralCard({required this.me});

  static String _message(String code) =>
      'I am part of the ACAPS Ground Truth expert group: a few minutes a month to ground-truth ACAPS '
      'humanitarian risk analysis, at the level of anonymity you choose.\n\n'
      'Join Ground Truth with my code: $code\n'
      'Open the app, tap "I have a code" and type it in.';

  void _copy(BuildContext context, String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what copied')));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final code = me.referralCode;
    final n = appState.referralsBy(me);
    final progress = appState.referralProgress(me);
    final syncError = appState.sessionAccountId == null ? null : appState.accountSyncError;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your referral code', style: t.titleSmall),
            const SizedBox(height: 4),
            Text('Share it with experts you trust: they type it in the app to join the group. '
                'It is permanent and works for any number of colleagues.', style: t.bodySmall),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cs.surfaceContainerHighest.withAlpha(140), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.vpn_key_outlined, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: code.isEmpty
                        ? Text(syncError ?? 'Loading your code…', style: t.bodySmall?.copyWith(color: syncError == null ? null : cs.error))
                        : SelectableText(code,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  ),
                  if (code.isEmpty && syncError != null)
                    IconButton(tooltip: 'Try again', onPressed: appState.refreshAccount, icon: const Icon(Icons.refresh)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: code.isEmpty ? null : () => _copy(context, code, 'Referral code'),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy code'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: code.isEmpty ? null : () => _copy(context, _message(code), 'Invitation message'),
              icon: const Icon(Icons.mail_outline, size: 18),
              label: const Text('Copy invitation message'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.group_add_outlined, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    n == 0
                        ? 'Nobody has joined with your code yet.'
                        : '$n ${n == 1 ? 'colleague' : 'colleagues'} joined with your code · +${n * Points.referral} points',
                    style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            // Each colleague's progress: stage only, never who they are.
            for (var i = 0; i < progress.length; i++)
              _ReferralRow(
                number: i + 1,
                answered: progress[i].answered,
                stage: progress[i].stage,
                joinedAt: progress[i].joinedAt,
                tracked: progress[i].tracked,
              ),
            const SizedBox(height: 12),
            // Toward the Referral Master badge (shown in the Rating).
            Row(
              children: [
                const AwardIcon(Award.referralMaster, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    n >= referralMasterMin
                        ? 'Referral Master: you invited $n experts who joined. The badge shows in the Rating.'
                        : '${referralMasterMin - n} more ${referralMasterMin - n == 1 ? 'colleague' : 'colleagues'} '
                            'to earn the Referral Master badge.',
                    style: t.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const InfoBanner(
              icon: Icons.info_outline,
              text: 'You get +${Points.referral} points as soon as a colleague signs up with your code.',
            ),
            const SizedBox(height: 8),
            Text('Anonymity: you only see how far each colleague has got (how many risks they answered), '
                'never their name, pseudonym, answers or comments. They do not see who invited them, '
                'and they were told about this when they joined.', style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// "Colleague 1  ●──●──○  Answered 1 of 3 risks": one referred colleague's
/// progress through the three stages, without anything that identifies them.
/// For real accounts only the join date is known ([tracked] false): answers
/// are not in the shared database yet.
class _ReferralRow extends StatelessWidget {
  final int number;
  final int answered;
  final ReferralStage stage;
  final DateTime joinedAt;
  final bool tracked;
  const _ReferralRow({required this.number, required this.answered, required this.stage, required this.joinedAt, this.tracked = true});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    const goal = Points.referralAnswersInPilot;
    final done = stage.index; // 0 joined, 1 first risk, 2 three risks
    final label = !tracked
        ? 'Joined ${formatDate(joinedAt)}'
        : switch (stage) {
            ReferralStage.joined => 'Joined · no risks answered yet',
            ReferralStage.firstRisk => 'Answered $answered of $goal risks',
            ReferralStage.threeRisks => '$goal+ risks answered: fully active',
          };
    Widget dot(bool on) => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? cs.primary : Colors.transparent,
            border: Border.all(color: on ? cs.primary : cs.outline, width: 2),
          ),
        );
    Widget line(bool on) => Expanded(child: Container(height: 2, color: on ? cs.primary : cs.outlineVariant));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          SizedBox(width: 92, child: Text('Colleague $number', style: const TextStyle(fontWeight: FontWeight.w700))),
          SizedBox(
            width: 70,
            child: Row(children: [dot(true), line(done >= 1), dot(done >= 1), line(done >= 2), dot(done >= 2)]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(child: Text(label, style: t.bodySmall)),
                if (stage == ReferralStage.threeRisks) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check_circle, size: 16, color: cs.primary),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _first = TextEditingController();
  final _last = TextEditingController();

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _first.text.trim().isNotEmpty && _last.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Enter your name again'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Your name was deleted when you became fully anonymous. Levels 1 and 2 need it.'),
          const SizedBox(height: 12),
          TextField(controller: _first, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'First name')),
          const SizedBox(height: 8),
          TextField(controller: _last, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Last name')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: ok ? () => Navigator.pop(context, '${_first.text.trim()} ${_last.text.trim()}') : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class CountryField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  const CountryField({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final countries = appState.countries;
    return DropdownMenu<String>(
      key: ValueKey(value),
      expandedInsets: EdgeInsets.zero,
      initialSelection: countries.contains(value) ? value : null,
      label: Text(label),
      leadingIcon: const Icon(Icons.place_outlined),
      menuHeight: 320,
      dropdownMenuEntries: [for (final c in countries) DropdownMenuEntry(value: c, label: c)],
      onSelected: (c) {
        if (c != null) onChanged(c);
      },
    );
  }
}

/// Countries you follow. Mutates [selected] and calls [onChanged].
class InterestsField extends StatelessWidget {
  final Set<String> selected;
  final String exclude;
  final VoidCallback onChanged;
  const InterestsField({super.key, required this.selected, required this.exclude, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final shown = (selected.toList()..remove(exclude))..sort();
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Other countries you follow', prefixIcon: Icon(Icons.travel_explore)),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final c in shown)
            InputChip(
              label: Text(c),
              onDeleted: () {
                selected.remove(c);
                onChanged();
              },
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
            onPressed: () async {
              final c = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _CountryPicker(exclude: {exclude, ...selected}),
              );
              if (c != null) {
                selected.add(c);
                onChanged();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _CountryPicker extends StatefulWidget {
  final Set<String> exclude;
  const _CountryPicker({required this.exclude});

  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = appState.countries
        .where((c) => !widget.exclude.contains(c) && c.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    // Lifted above the phone keyboard, so the search field stays visible.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search country'),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: ListView(
              children: [for (final c in list) ListTile(title: Text(c), onTap: () => Navigator.pop(context, c))],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _WhoRow extends StatelessWidget {
  final IconData icon;
  final String who;
  final String sees;
  const _WhoRow({required this.icon, required this.who, required this.sees});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(who)),
          Flexible(child: Text(sees, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
