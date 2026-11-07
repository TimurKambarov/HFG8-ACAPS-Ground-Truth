import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;

import '../auth.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'profile.dart';

/// Why a typed code did not work, in plain words.
String? inviteErrorMessage(InviteStatus? s) => switch (s) {
      null || InviteStatus.ok => null,
      InviteStatus.unknown => 'This is not a valid code. The groups are closed: ask your ACAPS contact, '
          'or a colleague in the group, for a code.',
      InviteStatus.used => 'This invite code has already been used. Each ACAPS invite works once, for one person: '
          'ask your ACAPS contact for a new one.',
      InviteStatus.revoked => 'This invite code was cancelled by ACAPS. Ask your ACAPS contact for a new one.',
      InviteStatus.expired => 'This code has expired. Ask your ACAPS contact for a new one.',
    };

/// Step 1, the start screen: the group is closed. New members get in with a
/// code: a personal, single-use invite from ACAPS (GT-…) or a colleague's
/// referral code (REF-…). There is no installed app yet, so people share
/// codes, not links. Existing members log in.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (cleanCode(_code.text).isEmpty) {
      setState(() => _error = 'Type the code you received.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // A valid code switches the app to the sign-up form.
      final status = await appState.enterCode(_code.text);
      if (mounted && status != InviteStatus.ok) setState(() => _error = inviteErrorMessage(status));
    } catch (e) {
      if (mounted) setState(() => _error = explain(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Demo mode: fills in one of the demo invite codes.
  void _useDemoCode() {
    final i = appState.demoInvite;
    if (i == null) {
      setState(() => _error = 'All demo invite codes have been used: each works once. '
          'Log in as a moderator to create a new one, or reset the demo.');
      return;
    }
    _code.text = i.code;
    _submit();
  }

  void _logIn() {
    if (Auth.ready) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
    } else {
      appState.openLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final demo = !Auth.ready;
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
                      border: Border.all(color: cs.primary, width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.vpn_key_outlined, size: 100, color: cs.primary),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Join with the code you received', textAlign: TextAlign.center, style: t.titleMedium),
                const SizedBox(height: 6),
                Text('A personal invite code from ACAPS (works once), or the referral code of a colleague in the group.',
                    textAlign: TextAlign.center, style: t.bodySmall),
                const SizedBox(height: 16),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, letterSpacing: 1),
                  decoration: InputDecoration(
                    labelText: 'I have a code',
                    hintText: 'GT-XXXX-XXXX or REF-XXXX-XXXX',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    errorText: _error,
                    errorMaxLines: 4,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Icon(Icons.arrow_forward),
                  label: const Text('Continue'),
                ),
                if (demo) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _busy ? null : _useDemoCode,
                    icon: const Icon(Icons.person_add_alt, size: 18),
                    label: const Text('Register with a demo code'),
                  ),
                  Text('Demo: codes are kept on this device. Start with run.ps1 for real accounts.',
                      textAlign: TextAlign.center, style: t.bodySmall),
                ],
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
                  onPressed: _logIn,
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

/// Demo mode: log in as an existing member by picking a synthetic demo user
/// or a moderator (no passwords). With real accounts, [LoginScreen] is used.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final personas = appState.experts.where((e) => e.persona || (!e.simulated && !isAccountId(e.id))).toList();

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
                Text('New here? Go back and enter the code you were sent.', style: t.bodySmall),
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
                          backgroundColor: cs.tertiary.withAlpha(50),
                          child: Icon(Icons.admin_panel_settings_outlined, color: cs.onSurface),
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

/// A password field with a show/hide button.
class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String? helper;
  final bool newPassword;
  final VoidCallback? onSubmitted;
  final ValueChanged<String>? onChanged;
  const _PasswordField({
    required this.controller,
    this.helper,
    this.newPassword = false,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        obscureText: !_show,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
        decoration: InputDecoration(
          labelText: 'Password',
          helperText: widget.helper,
          helperMaxLines: 2,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            tooltip: _show ? 'Hide password' : 'Show password',
            icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _show = !_show),
          ),
        ),
      );
}

/// Step 2 after a valid code: the expert's profile (and, with real accounts,
/// a password). A moderator code shows [_ModeratorSignUp] instead.
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
  final _password = TextEditingController();
  late String _home = appState.invitePanel ?? 'Chad';
  final Set<String> _interests = {};
  bool _notify = true;
  bool _rating = true;
  bool _hideAbroad = false;
  bool _busy = false;
  String? _error;

  /// Real accounts: the expert also chooses a password.
  bool get _account => Auth.ready;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _pseudo.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid =>
      pseudonymPattern.hasMatch(_pseudo.text.trim()) &&
      (!_level.needsRealName || (_first.text.trim().isNotEmpty && _last.text.trim().isNotEmpty)) &&
      (!_account || _password.text.length >= minPassword);

  Future<void> _join() async {
    final realName = '${_first.text.trim()} ${_last.text.trim()}';
    final hide = _level != Anonymity.anonymous && _hideAbroad;
    if (!_account) {
      appState.register(
        level: _level,
        realName: realName,
        pseudonym: _pseudo.text,
        homeCountry: _home,
        interests: {..._interests},
        notifications: _notify,
        onRating: _rating,
        hideFromOtherCountries: hide,
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await appState.registerAccount(
        password: _password.text,
        level: _level,
        realName: realName,
        pseudonym: _pseudo.text,
        homeCountry: _home,
        interests: {..._interests},
        notifications: _notify,
        onRating: _rating,
        hideFromOtherCountries: hide,
      );
      TextInput.finishAutofillContext();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = explain(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (appState.pendingIsModerator) return const _ModeratorSignUp();
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your profile'),
        // First screen after entering a code: back goes to the start.
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: appState.backToStart),
      ),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            const SizedBox(height: 12),
            InfoBanner(
              icon: Icons.vpn_key_outlined,
              text: appState.pendingIsReferral
                  ? 'You were invited by a colleague in the ACAPS expert group. Welcome. '
                      'They will see that someone joined with their code (and, later, how many risks you have answered), '
                      'never your name, pseudonym, answers or comments. You choose your own anonymity below.'
                  : 'Your invite code is valid. It is used up when you join: it works once, for one person, '
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
            SectionLabel('${_level.needsRealName ? 3 : 2}. ${_account ? 'Login, ' : ''}pseudonym and countries'),
            TextField(
              controller: _pseudo,
              onChanged: (_) => setState(() {}),
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.newUsername],
              decoration: InputDecoration(
                labelText: 'Pseudonym',
                prefixIcon: const Icon(Icons.alternate_email),
                helperText: '${_level == Anonymity.anonymous ? 'Only you see it.' : 'What colleagues see.'} $pseudonymRule',
                helperMaxLines: 3,
                errorText: _pseudo.text.trim().isEmpty || pseudonymPattern.hasMatch(_pseudo.text.trim()) ? null : pseudonymRule,
                errorMaxLines: 3,
              ),
            ),
            if (_account) ...[
              const SizedBox(height: 12),
              _PasswordField(
                controller: _password,
                newPassword: true,
                helper: 'At least $minPassword characters. You log in with your pseudonym and this password.',
                onChanged: (_) => setState(() {}),
              ),
            ],
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _valid && !_busy ? _join : null,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Join the group'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Real accounts: a moderator code creates an ACAPS moderator account. They
/// log in with their real email and are always known by name.
class _ModeratorSignUp extends StatefulWidget {
  const _ModeratorSignUp();

  @override
  State<_ModeratorSignUp> createState() => _ModeratorSignUpState();
}

class _ModeratorSignUpState extends State<_ModeratorSignUp> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().contains(' ') && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim()) && _password.text.length >= minPassword;

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await appState.registerModerator(realName: _name.text, email: _email.text, password: _password.text);
      TextInput.finishAutofillContext();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = explain(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ACAPS moderator account'),
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: appState.backToStart),
      ),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const InfoBanner(
              icon: Icons.admin_panel_settings_outlined,
              text: 'This is a moderator code. Moderators sign their reviews, so they use their real name and work email.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              onChanged: (_) => setState(() {}),
              autofillHints: const [AutofillHints.name],
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.badge_outlined)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Work email', prefixIcon: Icon(Icons.mail_outline), helperText: 'Your login name.'),
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _password,
              newPassword: true,
              helper: 'At least $minPassword characters.',
              onChanged: (_) => setState(() {}),
              onSubmitted: _submit,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _valid && !_busy ? _submit : null,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Create moderator account'),
            ),
          ],
        ),
      ),
    );
  }
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
            _PasswordField(controller: _pw, onSubmitted: _submit),
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
