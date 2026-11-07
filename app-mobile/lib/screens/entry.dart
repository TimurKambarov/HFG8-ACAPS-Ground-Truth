import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;

import '../auth.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'profile.dart';

/// Step 1: the group is closed. You only get in with an ACAPS QR code.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _redeem(String code) {
    if (appState.redeemInvite(code) == null) {
      setState(() => _error = 'This is not a valid ACAPS invite. The groups are closed: ask your ACAPS contact for a QR code.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _Hero(subtitle: 'A trusted, closed network of humanitarian experts. A few minutes a week to ground-truth ACAPS risk analysis.'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.qr_code_2, size: 110, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Scan the QR code you received from ACAPS', textAlign: TextAlign.center, style: t.titleMedium),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _redeem(inviteCodes.keys.first),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR code (demo)'),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: _redeem,
                  decoration: InputDecoration(
                    labelText: 'Or type the invite code',
                    hintText: inviteCodes.keys.first,
                    errorText: _error,
                    errorMaxLines: 3,
                    suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => _redeem(_code.text)),
                  ),
                ),
                if (Auth.configured) ...[
                  const SizedBox(height: 28),
                  Text('Already a member?', textAlign: TextAlign.center, style: t.bodyMedium),
                  const SizedBox(height: 8),
                  const _LoginButton(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 2: for the MVP you pick a synthetic demo user instead of logging in.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final personas = appState.experts.where((e) => e.persona || !e.simulated).toList();

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(subtitle: 'Invite accepted: ${appState.invitePanel} panel.'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (Auth.configured) ...[
                  const SectionLabel('Your account'),
                  const _LoginButton(),
                  const SizedBox(height: 8),
                ],
                const SectionLabel('Continue as a demo expert'),
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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: cs.tertiary.withAlpha(50), child: Icon(Icons.admin_panel_settings_outlined, color: cs.onSurface)),
                      title: const Text('ACAPS moderator', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Panels, comments, rating, database view'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: appState.signInModerator,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('I am new: create my profile'),
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
      appBar: AppBar(title: const Text('Your profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
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

class _LoginButton extends StatelessWidget {
  const _LoginButton();

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
        icon: const Icon(Icons.login),
        label: const Text('Log in'),
      );
}

/// Real login against Supabase. Experts use their pseudonym, moderators their email.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _who = TextEditingController();
  final _pw = TextEditingController();
  bool _showPw = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _who.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_who.text.trim().isEmpty || _pw.text.isEmpty) {
      setState(() => _error = 'Enter your pseudonym (or email) and your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await Auth.logIn(_who.text, _pw.text);
      if (!mounted) return;
      TextInput.finishAutofillContext();
      appState.signInAccount(profile);
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = explain(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isEmail = _who.text.contains('@');
    return Scaffold(
      appBar: AppBar(title: const Text('Log in')),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (!Auth.ready) ...[
              InfoBanner(icon: Icons.cloud_off_outlined, text: Auth.problem ?? 'Login is not available in this build.'),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _who,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Pseudonym or email',
                prefixIcon: Icon(isEmail ? Icons.mail_outline : Icons.alternate_email),
                helperText: isEmail ? 'Logging in as ACAPS moderator.' : 'Experts: your pseudonym. Moderators: your email.',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pw,
              obscureText: !_showPw,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _showPw ? 'Hide password' : 'Show password',
                  icon: Icon(_showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _showPw = !_showPw),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _busy || !Auth.ready ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Log in'),
            ),
            const SizedBox(height: 16),
            Text('Forgot your password? Ask your ACAPS contact.', textAlign: TextAlign.center, style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final String subtitle;
  const _Hero({required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 36, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, AppColors.ink]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar, color: Colors.white, size: 34),
              const Spacer(),
              IconButton(
                tooltip: 'Theme and text size',
                onPressed: () => showDisplaySettings(context),
                icon: const Icon(Icons.text_fields, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Ground Truth', style: t.headlineMedium?.copyWith(color: Colors.white)),
          const SizedBox(height: 8),
          Text(subtitle, style: t.bodyLarge?.copyWith(color: Colors.white.withAlpha(220), height: 1.4)),
        ],
      ),
    );
  }
}
