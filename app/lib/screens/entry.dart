import 'package:flutter/material.dart';

import '../design.dart';
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
    // The cover is always night, whatever the theme: the first impression.
    final contrast = appState.theme == AppTheme.contrast;
    return Theme(
      data: contrast ? buildContrastTheme() : buildTheme(Brightness.dark),
      child: Builder(builder: (context) {
        final t = Theme.of(context).textTheme;
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                const _TopBar(),
                const SizedBox(height: 8),
                const _Constellation(height: 200),
                const SizedBox(height: 18),
                Text('Ground\nTruth', style: t.displaySmall?.copyWith(fontSize: 56, height: 0.95, letterSpacing: -2)),
                const SizedBox(height: 14),
                Text(
                  'A trusted, closed network of humanitarian experts. A few minutes a week to ground-truth ACAPS risk analysis.',
                  style: t.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 22),
                const _Facts(),
                const SizedBox(height: 26),
                Text('Join with the invite link you received from ACAPS', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Your link is your way in: it is personal and works once. '
                    'In the demo, Register uses one of the demo invite links.',
                    style: t.bodySmall),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _openDemoLink,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text('Register'), SizedBox(width: 10), Icon(Icons.arrow_forward, size: 20)],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  InfoBanner(icon: Icons.link_off, color: cs.error, text: _error!),
                ],
                const SizedBox(height: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: appState.openLogin,
                  child: const Text('Log in'),
                ),
                const SizedBox(height: 10),
                Text('Already a member? Log in with your pseudonym.', textAlign: TextAlign.center, style: t.bodySmall),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// "GROUND TRUTH · ACAPS" and the display settings.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        const AcapsMark(size: 12),
        const SizedBox(width: 8),
        Expanded(child: Text('GROUND TRUTH · FOR ACAPS', style: mono(11.5, weight: FontWeight.w700, color: cs.onSurface, spacing: 1.6))),
        IconButton(
          tooltip: 'Theme and text size',
          onPressed: () => showDisplaySettings(context),
          icon: Icon(Icons.text_fields, color: cs.onSurface),
        ),
      ],
    );
  }
}

/// Three promises as numbers.
class _Facts extends StatelessWidget {
  const _Facts();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget fact(String big, String small) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: cs.onSurface, width: 2))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(big, style: mono(24, weight: FontWeight.w700, color: cs.onSurface, spacing: -0.5)),
                const SizedBox(height: 2),
                Text(small, style: TextStyle(fontSize: 12, height: 1.25, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        fact('5–10', 'experts per country, invited'),
        fact('2 min', 'per risk, about once a week'),
        fact('0', 'names in anything made public'),
      ],
    );
  }
}

/// A field of anonymous experts as dots. One is you (blue, with a halo);
/// the ink square is ACAPS. The dots come on one by one.
class _Constellation extends StatefulWidget {
  final double height;
  const _Constellation({required this.height});

  @override
  State<_Constellation> createState() => _ConstellationState();
}

class _ConstellationState extends State<_Constellation> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _ConstellationPainter(t: _c.value, dot: cs.onSurfaceVariant, ink: cs.onSurface, you: youColor(context)),
        ),
      ),
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  final double t;
  final Color dot, ink, you;
  _ConstellationPainter({required this.t, required this.dot, required this.ink, required this.you});

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 13, rows = 7;
    final dx = size.width / cols, dy = size.height / rows;
    // Deterministic "panels": clusters of brighter dots around a few centres.
    final centres = [const Offset(2.5, 2), const Offset(6, 4.5), const Offset(10, 2.2)];
    var k = 0;
    Offset? youAt;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        k++;
        final at = Offset(dx * (c + 0.5), dy * (r + 0.5));
        final near = centres.any((p) => (Offset(c.toDouble(), r.toDouble()) - p).distance < 1.6);
        final appear = ((t * 1.4) - (k / (rows * cols))).clamp(0.0, 1.0);
        if (appear <= 0) continue;
        if (r == 4 && c == 6) {
          youAt = at;
          continue;
        }
        if (r == 2 && c == 10) {
          final s = 9.0 * appear;
          canvas.drawRect(Rect.fromCenter(center: at, width: s, height: s), Paint()..color = ink);
          continue;
        }
        canvas.drawCircle(at, (near ? 4.2 : 2.2) * appear, Paint()..color = near ? dot : dot.withAlpha(90));
      }
    }
    if (youAt != null && t > 0.55) {
      final a = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
      // Ripples around you: your view reaches the group, your name does not.
      for (final (r, alpha) in const [(34.0, 50), (24.0, 90)]) {
        canvas.drawCircle(
            youAt,
            r * a,
            Paint()
              ..color = you.withAlpha((alpha * a).round())
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
      }
      canvas.drawCircle(youAt, 14 * a, Paint()..color = you.withAlpha(60));
      canvas.drawCircle(youAt, 7 * a, Paint()..color = you);
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) => old.t != t || old.you != you || old.dot != dot;
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
          const _Hero(subtitle: 'Log in'),
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
                        title: Text(e.pseudonym, style: const TextStyle(fontWeight: FontWeight.w800)),
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
                        leading: Container(
                          width: 36,
                          height: 36,
                          color: cs.onSurface,
                          child: Icon(Icons.admin_panel_settings_outlined, color: cs.surface, size: 20),
                        ),
                        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800)),
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
        ],
      ),
      // Always in reach, at the bottom of the screen.
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton(
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
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text('Join the group'), SizedBox(width: 10), Icon(Icons.arrow_forward, size: 20)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact night band for the log-in screen: same marks as the cover.
class _Hero extends StatelessWidget {
  final String subtitle;
  const _Hero({required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final contrast = appState.theme == AppTheme.contrast;
    return Theme(
      data: contrast ? buildContrastTheme() : buildTheme(Brightness.dark),
      child: Builder(builder: (context) {
        final t = Theme.of(context).textTheme;
        final cs = Theme.of(context).colorScheme;
        return Container(
          color: cs.surface,
          padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _TopBar(),
              const _Constellation(height: 90),
              const SizedBox(height: 8),
              Text('Ground Truth', style: t.headlineMedium),
              const SizedBox(height: 4),
              Text(subtitle.toUpperCase(), style: mono(12, weight: FontWeight.w700, color: cs.onSurfaceVariant, spacing: 1.4)),
            ],
          ),
        );
      }),
    );
  }
}
