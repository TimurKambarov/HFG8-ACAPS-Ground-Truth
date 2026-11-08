import 'package:flutter/material.dart';

import '../brand.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'profile.dart';

/// Why an opened invite link did not work, in plain words.
String? inviteErrorMessage(InviteStatus? s) => switch (s) {
      null || InviteStatus.ok => null,
      InviteStatus.unknown => 'This is not a valid ACAPS invite link. The groups are closed: ask your ACAPS contact for an invite link.',
      InviteStatus.used => 'This invite link has already been used. Each link works once, for one person: '
          'ask your ACAPS contact for a new one.',
      InviteStatus.revoked => 'This invite link was cancelled by ACAPS. Ask your ACAPS contact for a new one.',
    };

/// Step 1, the start screen: the group is closed. New members get in only by
/// opening the personal invite link ACAPS sent them (the app then starts with
/// ?invite=...). There is deliberately no field to paste links or codes into.
/// Existing members log in.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  String? _error;

  /// Demo "Register": as if the expert tapped the invite link ACAPS sent them.
  /// A valid link goes straight to the profile form.
  void _openDemoLink() {
    final i = appState.demoInvite;
    if (i == null) {
      setState(() => _error = 'All demo invite links have been used: each works once. '
          'Log in as a moderator to create a new one, or reset the demo.');
      return;
    }
    appState.redeemInvite(i.code);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _Hero(subtitle: 'A trusted, closed network of humanitarian experts. A few minutes a week to ground-truth ACAPS risk analysis.'),
          // Key figures strip, as on the website's data blocks.
          const _KeyFacts(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EdgeCard(
                  edge: AppColors.teal,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Eyebrow('New member'),
                      const SizedBox(height: 6),
                      Text('Join with the invite link you received from ACAPS', style: t.titleMedium),
                      const SizedBox(height: 6),
                      Text('Your link is your way in: it is personal and works once. '
                          'In the demo, Register uses one of the demo invite links.',
                          style: t.bodySmall),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _openDemoLink,
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Register'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        InfoBanner(icon: Icons.link_off, color: Theme.of(context).colorScheme.error, text: _error!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('Already a member?', style: t.bodySmall)),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: appState.openLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('Log in'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three facts about taking part, as big numbers.
class _KeyFacts extends StatelessWidget {
  const _KeyFacts();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
      margin: const EdgeInsets.only(bottom: 12),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: KeyFigure(value: '2', label: 'minutes per risk')),
          Expanded(child: KeyFigure(value: '6', label: 'month forecast window')),
          Expanded(child: KeyFigure(value: '3', label: 'levels of anonymity')),
        ],
      ),
    );
  }
}

/// Log in as an existing member (for the MVP: pick a synthetic demo user or
/// a moderator). New members never come here: a valid invite link goes
/// straight to the profile form. Also shown when an opened link did not work.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final personas = appState.experts.where((e) => e.persona || !e.simulated).toList();
    final error = inviteErrorMessage(appState.inviteError);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _Hero(subtitle: 'Log in', compact: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Way out first, so nobody has to scroll past every account.
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: appState.backToStart,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back to start'),
                  ),
                ),
                Text('New here? Open the personal invite link you were sent.', style: t.bodySmall),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  InfoBanner(icon: Icons.link_off, color: cs.error, text: error),
                ],
                const SectionLabel('Log in as a demo expert'),
                Text('All users are synthetic. No passwords in the demo.', style: t.bodySmall),
                const SizedBox(height: 8),
                for (final e in personas)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Card(
                      child: ListTile(
                        leading: Avatar(nameSeenBy(e, ViewerRole.expert)),
                        title: Text(e.pseudonym, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('Level ${e.level.number}: ${e.level.label} · ${e.homeCountry}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => appState.signInAs(e),
                      ),
                    ),
                  ),
                const SectionLabel('ACAPS moderators'),
                Text('Each moderator has their own account. Reviews are signed with their name.', style: t.bodySmall),
                const SizedBox(height: 8),
                for (final m in moderators)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.brightness == Brightness.light ? AppColors.navy : cs.primaryContainer,
                          child: Icon(Icons.admin_panel_settings_outlined,
                              color: cs.brightness == Brightness.light ? Colors.white : cs.onPrimaryContainer),
                        ),
                        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('ACAPS moderator'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => appState.signInModerator(m.id),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  Anonymity _level = Anonymity.pseudonymous;
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _pseudo = TextEditingController(text: 'Expert-${DateTime.now().millisecond % 90 + 10}');
  late String _home = appState.invitePanel ?? 'Chad';
  final Set<String> _interests = {};
  bool _notify = true;
  bool _rating = true;
  bool _hideAbroad = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _pseudo.dispose();
    super.dispose();
  }

  bool get _valid =>
      pseudonymPattern.hasMatch(_pseudo.text.trim()) && (!_level.needsRealName || (_first.text.trim().isNotEmpty && _last.text.trim().isNotEmpty));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your profile'),
        // First screen after opening an invite link: back goes to the start.
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: appState.backToStart),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const SizedBox(height: 12),
          InfoBanner(
            icon: Icons.link,
            text: appState.pendingReferrer != null
                ? 'You were invited by a colleague in the ACAPS expert group. Welcome. '
                    'They will see your progress (how many risks you have answered), never your name, '
                    'pseudonym, answers or comments. You choose your own anonymity below.'
                : 'Your invite link is valid. It is used up when you join: it works once, for one person, '
                    'and is not linked to your account, so your anonymity choice stays yours.',
          ),
          const SectionLabel('1. How visible do you want to be?'),
          for (final a in Anonymity.values)
            OptionTile(
              title: 'Level ${a.number}: ${a.label}',
              subtitle: a.description,
              icon: anonymityIcon(a),
              selected: _level == a,
              onTap: () => setState(() => _level = a),
            ),
          Text('The public never sees individual answers, whatever level you choose. You can change this later.', style: t.bodySmall),
          if (_level.needsRealName) ...[
            const SectionLabel('2. Your name'),
            Row(
              children: [
                Expanded(child: TextField(controller: _first, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'First name'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _last, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Last name'))),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _level == Anonymity.knownToAcaps ? 'Visible to ACAPS moderators only.' : 'Stored to verify your account. Nobody sees it in the app.',
              style: t.bodySmall,
            ),
          ] else ...[
            const SizedBox(height: 12),
            const InfoBanner(icon: Icons.visibility_off_outlined, text: 'Level 3: we do not ask for your name, and nothing that identifies you is stored.'),
          ],
          SectionLabel('${_level.needsRealName ? 3 : 2}. Pseudonym and countries'),
          TextField(
            controller: _pseudo,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Pseudonym',
              prefixIcon: const Icon(Icons.alternate_email),
              helperText: '${_level == Anonymity.anonymous ? 'Only you see it.' : 'What colleagues see.'} $pseudonymRule',
              helperMaxLines: 3,
              errorText: _pseudo.text.trim().isEmpty || pseudonymPattern.hasMatch(_pseudo.text.trim()) ? null : pseudonymRule,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 12),
          CountryField(label: 'Your country', value: _home, onChanged: (c) => setState(() => _home = c)),
          const SizedBox(height: 12),
          InterestsField(selected: _interests, exclude: _home, onChanged: () => setState(() {})),
          if (_level != Anonymity.anonymous)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _hideAbroad,
              onChanged: (v) => setState(() => _hideAbroad = v ?? false),
              title: const Text('Stay anonymous to colleagues from other countries'),
              subtitle: Text('Colleagues from $_home see your pseudonym; others see "$anonymousName".'),
            ),
          const SectionLabel('Settings'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _notify,
            onChanged: (v) => setState(() => _notify = v),
            title: const Text('Notify me when ACAPS updates a risk'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _rating,
            onChanged: (v) => setState(() => _rating = v),
            title: const Text('Take part in the rating'),
            subtitle: const Text('You appear under the name your level allows.'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _valid
                ? () {
                    appState.register(
                      level: _level,
                      realName: '${_first.text.trim()} ${_last.text.trim()}',
                      pseudonym: _pseudo.text,
                      homeCountry: _home,
                      interests: {..._interests},
                      notifications: _notify,
                      onRating: _rating,
                      hideFromOtherCountries: _level != Anonymity.anonymous && _hideAbroad,
                    );
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                : null,
            child: const Text('Join the group'),
          ),
        ],
      ),
    );
  }
}

/// Navy hero with contour lines and the large pin, like the ACAPS website's
/// navy bands.
class _Hero extends StatelessWidget {
  final String subtitle;
  final bool compact;
  const _Hero({required this.subtitle, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return BrandHeader(
      eyebrow: 'ACAPS · Expert network',
      title: 'Ground Truth',
      titleSize: compact ? 46 : 60,
      subtitle: subtitle,
      seed: compact ? 7 : 3,
      actions: [
        IconButton(
          tooltip: 'Theme and text size',
          onPressed: () => showDisplaySettings(context),
          icon: const Icon(Icons.text_fields),
        ),
      ],
    );
  }
}
