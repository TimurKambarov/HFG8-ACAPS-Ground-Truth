import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lab.dart';

/// Everything the signed-in user can see about themselves, plus rule checks
/// that should all come back "refused".
class WhoAmIScreen extends StatefulWidget {
  const WhoAmIScreen({super.key});

  @override
  State<WhoAmIScreen> createState() => _WhoAmIScreenState();
}

class _Data {
  final User user;
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? contact;
  final List<Map<String, dynamic>> visibleProfiles;
  final List<Map<String, dynamic>> log;
  _Data(this.user, this.profile, this.contact, this.visibleProfiles, this.log);
  bool get isModerator => profile?['role'] == 'moderator';
}

class _Check {
  final String label;
  final bool moderatorOnly;
  final bool expertOnly;
  final Future<String?> Function(_Data d) run; // null = refused as expected
  const _Check(this.label, this.run, {this.moderatorOnly = false, this.expertOnly = false});
}

class _WhoAmIScreenState extends State<WhoAmIScreen> {
  late Future<_Data> _data = _load();
  final Map<String, ({bool ok, String text})> _results = {};

  Future<_Data> _load() async {
    final user = (await sb.auth.getUser()).user!; // fresh from the server, not the cached session
    final uid = user.id;
    final profile = await sb.from('profiles').select().eq('id', uid).maybeSingle();
    final contact = await sb.from('expert_contacts').select().eq('user_id', uid).maybeSingle();
    final visible = await sb.from('profiles').select('role, pseudonym, anonymity, real_name, home_country').order('created_at');
    final log = await sb.from('activity_log').select('event, details, created_at').order('created_at', ascending: false).limit(10);
    return _Data(user, profile, contact, visible, log);
  }

  void _refresh() => setState(() => _data = _load());

  /// Runs [write]; returns null if the database refused it.
  static Future<String?> _expectRefused(Future<Object?> Function() write) async {
    try {
      final r = await write();
      if (r is List && r.isEmpty) return null; // RLS filtered every row
      return 'Accepted: $r';
    } on PostgrestException {
      return null;
    }
  }

  late final List<_Check> _checks = [
    _Check('Sign-up without an invite code', (_) => Lab.probeSignUpWithoutInvite()),
    _Check(
      'Change my pseudonym',
      (d) => _expectRefused(() => sb.from('profiles').update({'pseudonym': d.profile!['pseudonym']}).eq('id', d.user.id).select()),
    ),
    _Check(
      'Make myself moderator',
      (d) => _expectRefused(() => sb.from('profiles').update({'role': 'moderator'}).eq('id', d.user.id).select()),
      expertOnly: true,
    ),
    _Check(
      'Switch a moderator to anonymous',
      (d) => _expectRefused(() => sb.from('profiles').update({'anonymity': 'anonymous'}).eq('id', d.user.id).select()),
      moderatorOnly: true,
    ),
    _Check('Read the invite code list directly', (_) => _expectRefused(() => sb.from('invite_codes').select())),
    _Check(
      'Read other users\' contact emails',
      (d) => _expectRefused(() => sb.from('expert_contacts').select().neq('user_id', d.user.id)),
    ),
  ];

  Future<void> _runChecks(_Data d) async {
    for (final c in _applicable(d)) {
      String? r;
      try {
        r = await c.run(d);
      } catch (e) {
        r = 'Error: ${explain(e)}';
      }
      setState(() => _results[c.label] = r == null ? (ok: true, text: 'Refused, as expected') : (ok: false, text: r));
    }
  }

  Iterable<_Check> _applicable(_Data d) =>
      _checks.where((c) => !(c.moderatorOnly && !d.isModerator) && !(c.expertOnly && d.isModerator));

  @override
  Widget build(BuildContext context) => FutureBuilder<_Data>(
        future: _data,
        builder: (context, snap) => Scaffold(
          appBar: AppBar(
            title: const Text('Who am I'),
            actions: [
              IconButton(tooltip: 'Reload', onPressed: _refresh, icon: const Icon(Icons.refresh)),
              TextButton.icon(onPressed: () => sb.auth.signOut(), icon: const Icon(Icons.logout), label: const Text('Sign out')),
            ],
          ),
          body: snap.hasError
              ? Center(child: SelectableText(explain(snap.error!)))
              : !snap.hasData
                  ? const Center(child: CircularProgressIndicator())
                  : _body(context, snap.data!),
        ),
      );

  Widget _body(BuildContext context, _Data d) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final p = d.profile;
    final meta = d.user.userMetadata ?? {};
    final leftover = ['real_name', 'contact_email', 'invite'].where(meta.containsKey).toList();
    final name = p == null ? '?' : (d.isModerator ? p['real_name'] : p['pseudonym']);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('$name', style: t.headlineSmall),
            Chip(label: Text(p?['role'] ?? 'no profile!')),
            if (p != null) Chip(label: Text('${p['anonymity']}')),
            if (p?['home_country'] != null) Chip(label: Text('${p!['home_country']} panel')),
          ]),
          if (p == null)
            Text('No profile row: the sign-up trigger did not run. Was the migration applied?', style: TextStyle(color: c.error)),

          _section(t, 'Supabase Auth'),
          _kv('User id', d.user.id),
          _kv('Login email', d.user.email ?? '-'),
          _kv('Auth metadata', const JsonEncoder.withIndent('  ').convert(meta)),
          _flag(leftover.isEmpty, leftover.isEmpty
              ? 'No real name, contact email or invite left in Auth metadata.'
              : 'Still in Auth metadata: ${leftover.join(', ')}'),

          _section(t, 'My profile row (public.profiles)'),
          if (p != null) for (final e in p.entries) _kv(e.key, '${e.value}'),

          _section(t, 'My contact email (public.expert_contacts)'),
          _kv('email', d.contact?['email'] ?? 'none'),

          _section(t, 'Profiles I can see: ${d.visibleProfiles.length}'),
          Text(d.isModerator ? 'Moderators see every profile.' : 'Experts see only their own row.', style: t.bodySmall),
          _flag(d.isModerator || d.visibleProfiles.length == 1,
              d.isModerator || d.visibleProfiles.length == 1 ? 'Matches the rule.' : 'An expert can see other profiles!'),
          for (final r in d.visibleProfiles)
            _kv('${r['role']}', '${r['pseudonym']} · ${r['anonymity']} · ${r['real_name'] ?? 'no name'} · ${r['home_country'] ?? '-'}'),

          _section(t, 'My activity log (last 10)'),
          if (d.log.isEmpty) Text('Empty', style: t.bodySmall),
          for (final l in d.log) _kv('${l['event']}', '${l['created_at']}  ${jsonEncode(l['details'])}'),

          _section(t, 'Rule checks'),
          Text('Each of these should be refused by the database.', style: t.bodySmall),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(onPressed: () => _runChecks(d), icon: const Icon(Icons.play_arrow), label: const Text('Run all checks')),
          ),
          const SizedBox(height: 8),
          for (final ch in _applicable(d))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _results[ch.label] == null ? Icons.radio_button_unchecked : (_results[ch.label]!.ok ? Icons.check_circle : Icons.cancel),
                color: _results[ch.label] == null ? c.outline : (_results[ch.label]!.ok ? Colors.green.shade600 : c.error),
              ),
              title: Text(ch.label),
              subtitle: _results[ch.label] == null ? null : SelectableText(_results[ch.label]!.text),
            ),
        ]),
      ),
    );
  }

  Widget _section(TextTheme t, String s) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 6),
        child: Text(s, style: t.titleMedium),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 170, child: Text(k, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
          Expanded(child: SelectableText(v, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
        ]),
      );

  Widget _flag(bool ok, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Icon(ok ? Icons.check_circle : Icons.cancel, size: 18, color: ok ? Colors.green.shade600 : Colors.red),
          const SizedBox(width: 6),
          Expanded(child: Text(text)),
        ]),
      );
}
