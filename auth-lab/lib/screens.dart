import 'package:flutter/material.dart';

import 'lab.dart';

/// Narrow centred column used by every form.
class Page extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const Page({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(padding: const EdgeInsets.all(20), children: children),
            ),
          ),
        ),
      );
}

class ErrorBox extends StatelessWidget {
  final String? text;
  const ErrorBox(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    if (text == null) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(8)),
      child: SelectableText(text!, style: TextStyle(color: c.onErrorContainer)),
    );
  }
}

class Note extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool warn;
  const Note(this.icon, this.text, {super.key, this.warn = false});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warn ? c.tertiaryContainer : c.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: warn ? c.onTertiaryContainer : c.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: warn ? c.onTertiaryContainer : c.onSurfaceVariant))),
      ]),
    );
  }
}

void _backToStart(BuildContext context) => Navigator.of(context).popUntil((r) => r.isFirst);

// -----------------------------------------------------------------------------
// Start
// -----------------------------------------------------------------------------

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Page(title: 'Auth Lab', children: [
      Text('Ground Truth · sign-up and login test bench', style: t.titleMedium),
      const SizedBox(height: 4),
      Text('Talks to the real Supabase project. Use synthetic names only.', style: t.bodySmall),
      const SizedBox(height: 24),
      FilledButton.icon(
        icon: const Icon(Icons.qr_code_2),
        label: const Text('I have an invite code'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InviteScreen())),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        icon: const Icon(Icons.login),
        label: const Text('Log in'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
      ),
      const SizedBox(height: 24),
      Text('Test codes: GT-CHAD-7Q4X (Chad experts), GT-SDN-3K9M (Sudan experts), GT-ACAPS-MOD1 (moderators)',
          style: t.bodySmall),
      Text('Expert login address: <pseudonym>@${Lab.loginDomain}', style: t.bodySmall),
    ]);
  }
}

// -----------------------------------------------------------------------------
// Invite code
// -----------------------------------------------------------------------------

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

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final inv = await Lab.checkInvite(_code.text);
      if (!mounted) return;
      if (inv == null) {
        setState(() => _error = 'This is not a valid ACAPS invite, or it has expired or been used up.');
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => inv.isModerator ? ModeratorSignUp(inv) : ExpertSignUp(inv)),
        );
      }
    } catch (e) {
      setState(() => _error = explain(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Page(title: 'Invite code', children: [
        TextField(
          controller: _code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Invite code', hintText: 'GT-CHAD-7Q4X'),
          onSubmitted: (_) => _check(),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _check, child: Text(_busy ? 'Checking…' : 'Continue')),
        ErrorBox(_error),
        const Note(Icons.info_outline, 'Checking a code does not use it up. Only a completed sign-up counts.'),
      ]);
}

// -----------------------------------------------------------------------------
// Expert sign-up
// -----------------------------------------------------------------------------

class ExpertSignUp extends StatefulWidget {
  final Invite invite;
  const ExpertSignUp(this.invite, {super.key});

  @override
  State<ExpertSignUp> createState() => _ExpertSignUpState();
}

class _ExpertSignUpState extends State<ExpertSignUp> {
  Level _level = Level.pseudonymous;
  final _name = TextEditingController();
  final _pseudo = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _mail = TextEditingController();
  bool _addMail = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _pseudo, _pw, _pw2, _mail]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _problem {
    if (_level.needsName && _name.text.trim().isEmpty) return 'Enter your real name, or choose level 3.';
    if (!pseudonymPattern.hasMatch(_pseudo.text.trim())) return 'Pseudonym: $pseudonymRule';
    if (_pw.text.length < minPassword) return 'Password: at least $minPassword characters.';
    if (_pw.text != _pw2.text) return 'The two passwords differ.';
    if (_addMail && !_mail.text.contains('@')) return 'Enter an email, or switch "Add an email" off.';
    return null;
  }

  Future<void> _submit() async {
    final p = _problem;
    if (p != null) return setState(() => _error = p);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await Lab.signUpExpert(
        invite: widget.invite,
        pseudonym: _pseudo.text,
        level: _level,
        realName: _level.needsName ? _name.text : null,
        password: _pw.text,
        contactEmail: _addMail ? _mail.text : null,
      );
      if (!mounted) return;
      if (r.session == null) {
        setState(() => _error = 'Account created but not signed in: "Confirm email" is still on in Supabase. '
            'Turn it off, delete this user in Authentication → Users, and try again.');
        return;
      }
      _backToStart(context);
    } catch (e) {
      setState(() => _error = explain(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    void redraw(_) => setState(() {});
    return Page(title: 'Join as expert', children: [
      Note(Icons.verified_outlined, 'Invite accepted: ${widget.invite.summary}'),
      const SizedBox(height: 8),
      Text('1. How visible do you want to be?', style: t.titleSmall),
      RadioGroup<Level>(
        groupValue: _level,
        onChanged: (v) => setState(() => _level = v ?? _level),
        child: Column(children: [
          for (final l in Level.values)
            RadioListTile<Level>(
              contentPadding: EdgeInsets.zero,
              value: l,
              title: Text(l.label),
              subtitle: Text(l.description),
            ),
        ]),
      ),
      if (_level.needsName) ...[
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          onChanged: redraw,
          decoration: InputDecoration(
            labelText: 'Real name',
            helperText: _level == Level.knownToAcaps ? 'Visible to ACAPS moderators.' : 'Kept only to verify your account.',
          ),
        ),
      ],
      const SizedBox(height: 20),
      Text('2. Login', style: t.titleSmall),
      const SizedBox(height: 8),
      TextField(
        controller: _pseudo,
        onChanged: redraw,
        decoration: InputDecoration(
          labelText: 'Pseudonym',
          prefixIcon: const Icon(Icons.alternate_email),
          helperText: pseudonymRule,
          helperMaxLines: 2,
          errorText: _pseudo.text.isEmpty || pseudonymPattern.hasMatch(_pseudo.text.trim()) ? null : pseudonymRule,
          errorMaxLines: 2,
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _pw,
        obscureText: true,
        onChanged: redraw,
        decoration: const InputDecoration(labelText: 'Password', helperText: 'At least $minPassword characters.'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _pw2,
        obscureText: true,
        onChanged: redraw,
        decoration: const InputDecoration(labelText: 'Repeat password'),
      ),
      const SizedBox(height: 20),
      Text('3. Email (optional)', style: t.titleSmall),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _addMail,
        onChanged: (v) => setState(() => _addMail = v),
        title: const Text('Add an email for notifications'),
        subtitle: const Text('You still log in with your pseudonym. Colleagues and moderators never see it.'),
      ),
      if (_addMail) ...[
        TextField(
          controller: _mail,
          keyboardType: TextInputType.emailAddress,
          onChanged: redraw,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        if (_level == Level.anonymous)
          const Note(
            Icons.warning_amber_rounded,
            'You chose level 3 (fully anonymous). An email can identify you: ACAPS project admins can see it '
            'in the database. Leave it out to stay fully anonymous.',
            warn: true,
          ),
      ],
      const SizedBox(height: 20),
      FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Creating account…' : 'Create account')),
      ErrorBox(_error),
    ]);
  }
}

// -----------------------------------------------------------------------------
// Moderator sign-up
// -----------------------------------------------------------------------------

class ModeratorSignUp extends StatefulWidget {
  final Invite invite;
  const ModeratorSignUp(this.invite, {super.key});

  @override
  State<ModeratorSignUp> createState() => _ModeratorSignUpState();
}

class _ModeratorSignUpState extends State<ModeratorSignUp> {
  final _name = TextEditingController();
  final _mail = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _mail, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _problem {
    if (_name.text.trim().isEmpty) return 'Enter your real name.';
    if (!_mail.text.contains('@')) return 'Enter your work email.';
    if (_mail.text.trim().toLowerCase().endsWith('@${Lab.loginDomain}')) return 'Use a real email address.';
    if (_pw.text.length < minPassword) return 'Password: at least $minPassword characters.';
    if (_pw.text != _pw2.text) return 'The two passwords differ.';
    return null;
  }

  Future<void> _submit() async {
    final p = _problem;
    if (p != null) return setState(() => _error = p);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await Lab.signUpModerator(invite: widget.invite, realName: _name.text, email: _mail.text, password: _pw.text);
      if (!mounted) return;
      if (r.session == null) {
        setState(() => _error = 'Account created but not signed in: "Confirm email" is still on in Supabase.');
        return;
      }
      _backToStart(context);
    } catch (e) {
      setState(() => _error = explain(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Page(title: 'Join as moderator', children: [
        Note(Icons.verified_outlined, 'Invite accepted: ${widget.invite.summary}'),
        const Note(Icons.badge_outlined, 'Moderators are not anonymous: your name signs your reviews.'),
        const SizedBox(height: 8),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Real name')),
        const SizedBox(height: 12),
        TextField(
          controller: _mail,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Work email', helperText: 'You log in with this email.'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pw,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password', helperText: 'At least $minPassword characters.'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pw2,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Repeat password'),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Creating account…' : 'Create account')),
        ErrorBox(_error),
      ]);
}

// -----------------------------------------------------------------------------
// Log in
// -----------------------------------------------------------------------------

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
    if (_who.text.trim().isEmpty || _pw.text.isEmpty) return setState(() => _error = 'Fill in both fields.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Lab.logIn(_who.text, _pw.text);
      if (mounted) _backToStart(context);
    } catch (e) {
      setState(() => _error = explain(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Page(title: 'Log in', children: [
        TextField(
          controller: _who,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Pseudonym or email',
            helperText: _who.text.contains('@')
                ? 'Logging in as moderator (email).'
                : 'Experts: your pseudonym. Moderators: your email.',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pw,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Logging in…' : 'Log in')),
        ErrorBox(_error),
      ]);
}
