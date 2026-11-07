// =============================================================================
// Risk sync: ACAPS Risk Radar API  ->  Supabase
// =============================================================================
//
// Pulls every risk from the live ACAPS API and upserts it into the Supabase
// tables `risks`, `risk_countries` and `risk_triggers` (same columns as
// scripts/load_risks_to_supabase.py, which loads the CSV export instead).
// The Flutter app reads those tables, so after a run every user sees the
// current Risk Radar: new risks appear, closed risks move to the Archive.
//
// Run it by hand or let the weekly GitHub Action do it
// (.github/workflows/weekly-risk-sync.yml):
//
//   dart run scripts/sync_risks.dart            # sync
//   dart run scripts/sync_risks.dart --dry-run  # fetch and compare only, write nothing
//
// Plain Dart, no packages: runs anywhere the Dart SDK is (Flutter ships it).
//
// Credentials, from environment variables or the git-ignored API.key file in
// the repo root (KEY=value lines):
//   SUPABASE_URL, SUPABASE_SECRET_KEY   the secret key bypasses row level
//                                       security: scripts and servers only
//   ACAPS_EMAIL, ACAPS_PASSWORD         the ACAPS API account
//
// Safe to re-run: rows are upserted by primary key. Risks the API does not
// list (e.g. ones only in the CSV export) are left as they are.
// =============================================================================

import 'dart:convert';
import 'dart:io';

const _acaps = 'https://api.acaps.org';

// Allowed values, from the CHECK constraints in
// supabase/migrations/20261106000000_init.sql. Anything else is stored as null
// instead of failing the whole batch.
const _riskTypes = {
  'New emerging risk',
  'Marked deterioration in an existing crisis',
  'Future impact of a hazard which has already taken place',
};
const _probabilities = {'Very Low', 'Low', 'Medium', 'High', 'Very High'};
const _levels = {'Low', 'Medium', 'High'};
const _trends = {'Improved', 'Stable', 'Deteriorated'};
const _statuses = {'Active', 'Materialised', 'Not materialised'};
const _materialised = {'Hazard', 'Impact', 'Hazard and impact'};
const _exposures = {'<20,000', '20,000-100,000', '100,000-250,000', '250,000-500,000', '>500,000'};

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final env = _credentials();
  String need(String k) => env[k] ?? (throw StateError('Set $k (environment variable or API.key).'));

  // --- 1. Read the Risk Radar from ACAPS -------------------------------------
  final acaps = _Http();
  final token = await acaps.acapsToken(need('ACAPS_EMAIL'), need('ACAPS_PASSWORD'));
  final records = await acaps.riskRadar(token);
  stdout.writeln('ACAPS API: ${records.length} risks');

  // --- 2. Turn them into table rows ------------------------------------------
  final risks = <Map<String, Object?>>[];
  final countries = <Map<String, Object?>>[];
  final triggers = <Map<String, Object?>>[];
  for (final m in records) {
    final row = _riskRow(m);
    if (row == null) continue;
    risks.add(row);
    final id = row['risk_id'] as String;
    final isos = _list(m['iso3']), names = _list(m['country']);
    for (var i = 0; i < isos.length && i < names.length; i++) {
      countries.add({'risk_id': id, 'iso': isos[i], 'country': names[i]});
    }
    triggers.addAll(_triggerRows(id, _text(m['triggers_summary'])));
  }

  // --- 3. Compare with what Supabase has now (for the log) -------------------
  final db = _Supabase(need('SUPABASE_URL'), need('SUPABASE_SECRET_KEY'));
  final before = {for (final r in await db.select('risks', 'risk_id,status')) r['risk_id'] as String: r['status'] as String?};
  final added = [for (final r in risks) if (!before.containsKey(r['risk_id'])) r['risk_id']];
  final changed = [
    for (final r in risks)
      if (before.containsKey(r['risk_id']) && before[r['risk_id']] != r['status'])
        '${r['risk_id']}: ${before[r['risk_id']] ?? 'no status'} -> ${r['status'] ?? 'no status'}',
  ];
  stdout.writeln('Supabase before: ${before.length} risks');
  stdout.writeln('New risks: ${added.isEmpty ? 'none' : added.join(', ')}');
  stdout.writeln('Status changes: ${changed.isEmpty ? 'none' : '\n  ${changed.join('\n  ')}'}');

  if (dryRun) {
    stdout.writeln('Dry run: nothing written.');
    return;
  }

  // --- 4. Write ---------------------------------------------------------------
  await db.upsert('risks', risks, 'risk_id');
  // Child rows: replace them for the risks we loaded, so removed triggers disappear.
  final ids = [for (final r in risks) '"${r['risk_id']}"'].join(',');
  await db.delete('risk_countries', 'risk_id=in.($ids)');
  await db.upsert('risk_countries', countries, 'risk_id,iso');
  await db.delete('risk_triggers', 'risk_id=in.($ids)');
  await db.upsert('risk_triggers', triggers, 'trigger_id');

  for (final t in ['risks', 'risk_countries', 'risk_triggers']) {
    stdout.writeln('$t: ${await db.count(t)} rows in Supabase');
  }
  acaps.close();
  db.close();
}

// =============================================================================
// Mapping: one API record -> one `risks` row
// =============================================================================

/// API field names differ from the table's (see the column list in the
/// migration). Values are trimmed, "" becomes null, and values outside the
/// table's CHECK lists become null.
Map<String, Object?>? _riskRow(Map<String, dynamic> m) {
  final id = _text(m['risk_id']);
  final title = _text(m['risk_title']);
  if (id == null || title == null) return null;
  String? pick(String k, Set<String> allowed) {
    final v = _text(m[k]);
    return v != null && allowed.contains(v) ? v : null;
  }

  int? score(String k) {
    final n = int.tryParse(_text(m[k]) ?? '');
    return n != null && n >= 1 && n <= 5 ? n : null;
  }

  return {
    'risk_id': id,
    'title': title,
    'risk_type': pick('risk_type', _riskTypes),
    'iso': _list(m['iso3']).join(', '),
    'country': _list(m['country']).join(', '),
    'rationale': _text(m['rationale']),
    'source': _text(m['source']),
    'intensity_of_hazard': score('intensity_of_hazard'),
    'impact': score('impact'),
    'probability': pick('probability', _probabilities),
    'risk_level': pick('risk_level', _levels),
    'risk_trend': pick('risk_trend', _trends),
    'status': pick('status', _statuses),
    'what_materialised': pick('what_materialised', _materialised),
    'hazard_materialisation': _text(m['hazard_materialisation_description']),
    'materialisation_sources': _text(m['materialisation_sources']),
    'triggers_raw': _text(m['triggers_summary']),
    'vulnerability': _text(m['current_vulnerability_coping_capacity']),
    'vulnerability_sources': _text(m['vulnerability_coping_capacity_source']),
    'expected_exposure': pick('expected_exposure', _exposures),
    'expected_impact': _text(m['expected_impact']),
    'expected_impact_sources': _text(m['expected_impact_source']),
    'expected_priority_needs': _list(m['expected_priority_needs']),
    'impact_materialisation_description': _text(m['impact_materialisation_description']),
    'rationale_update': _text(m['rationale_updates']),
    'imported_at': DateTime.now().toUtc().toIso8601String(),
  };
}

/// Parses the "Trigger ID: / Title: / Description:" blocks
/// (mirrors parseTriggers in app/lib/models.dart and the Python loader).
List<Map<String, Object?>> _triggerRows(String riskId, String? raw) {
  if (raw == null || !raw.contains('Trigger ID:')) return const [];
  final out = <Map<String, Object?>>[];
  final seen = <String>{};
  var pos = 0;
  for (final chunk in raw.split('Trigger ID:').skip(1)) {
    final id = chunk.split('\n').first.trim();
    if (id.isEmpty || !seen.add(id)) continue; // trigger_id is the primary key
    pos++;
    var title = RegExp(r'Title:[ \t]*(.*)').firstMatch(chunk)?.group(1)?.trim() ?? '';
    var desc = RegExp(r'Description:\s*([\s\S]*?)(?:\n\s*Sources:|\n\s*Completion rate:|$)').firstMatch(chunk)?.group(1)?.trim() ?? '';
    while (desc.startsWith(':')) {
      desc = desc.substring(1).trim();
    }
    desc = desc.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (x) => x[1]!);
    final completion = RegExp(r'Completion rate:\s*(\d+)\s*%').firstMatch(chunk)?.group(1);
    final pct = completion == null ? null : int.parse(completion);
    out.add({
      'trigger_id': id,
      'risk_id': riskId,
      'position': pos,
      'title': title.isEmpty ? id : title,
      'description': desc.isEmpty ? null : desc,
      'completion_rate': pct != null && pct <= 100 ? pct : null,
      'raw': 'Trigger ID:$chunk'.trim(),
    });
  }
  return out;
}

/// Trimmed text, null for null or "". Lists are joined with ", ".
String? _text(Object? v) {
  if (v == null) return null;
  final s = (v is List ? v.map((x) => '$x'.trim()).where((x) => x.isNotEmpty).join(', ') : '$v')
      .replaceAll('\r\n', '\n')
      .trim();
  return s.isEmpty ? null : s;
}

/// A list field (the API sends lists for countries, ISO codes and needs).
List<String> _list(Object? v) => v is List
    ? [for (final x in v) if ('$x'.trim().isNotEmpty) '$x'.trim()]
    : (_text(v)?.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() ?? const []);

// =============================================================================
// Credentials
// =============================================================================

Map<String, String> _credentials() {
  final out = <String, String>{};
  // API.key in the repo root (this file lives in scripts/).
  final keyFile = File.fromUri(Platform.script.resolve('../API.key'));
  if (keyFile.existsSync()) {
    for (final line in keyFile.readAsLinesSync()) {
      final i = line.indexOf('=');
      if (i > 0 && !line.trimLeft().startsWith('#')) out[line.substring(0, i).trim()] = line.substring(i + 1).trim();
    }
  }
  // Environment variables win (GitHub Actions passes its secrets this way).
  for (final k in ['SUPABASE_URL', 'SUPABASE_SECRET_KEY', 'ACAPS_EMAIL', 'ACAPS_PASSWORD']) {
    final v = Platform.environment[k];
    if (v != null && v.isNotEmpty) out[k] = v;
  }
  return out;
}

// =============================================================================
// HTTP helpers (dart:io only)
// =============================================================================

class _Http {
  final _client = HttpClient();

  Future<(int, String)> send(String method, Uri url, {Map<String, String> headers = const {}, Object? body}) async {
    final req = await _client.openUrl(method, url);
    headers.forEach(req.headers.set);
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(body)));
    }
    final res = await req.close();
    return (res.statusCode, await res.transform(utf8.decoder).join());
  }

  Future<String> acapsToken(String email, String password) async {
    final (code, body) = await send('POST', Uri.parse('$_acaps/api/v1/token-auth/'), body: {'username': email, 'password': password});
    if (code != 200) throw StateError('ACAPS login failed ($code): $body');
    return (jsonDecode(body) as Map)['token'] as String;
  }

  /// Every page of risk-radar/risk-radar/, at most one request per second.
  Future<List<Map<String, dynamic>>> riskRadar(String token) async {
    final out = <Map<String, dynamic>>[];
    Uri? url = Uri.parse('$_acaps/api/v1/risk-radar/risk-radar/');
    while (url != null) {
      if (out.isNotEmpty) await Future<void>.delayed(const Duration(seconds: 1));
      final (code, body) = await send('GET', url, headers: {'Authorization': 'Token $token'});
      if (code != 200) throw StateError('ACAPS API error $code on $url: $body');
      final data = jsonDecode(body) as Map<String, dynamic>;
      out.addAll([for (final m in data['results'] as List) (m as Map).cast<String, dynamic>()]);
      final next = data['next'] as String?;
      url = next == null ? null : Uri.parse(next);
    }
    return out;
  }

  void close() => _client.close();
}

/// Minimal PostgREST client for the Supabase tables (secret key).
class _Supabase extends _Http {
  final String base;
  final Map<String, String> _auth;
  _Supabase(String url, String key)
      : base = '${url.replaceAll(RegExp(r'/+$'), '')}/rest/v1',
        _auth = {'apikey': key, 'Authorization': 'Bearer $key'};

  Never _fail(String table, int code, String body) {
    if (code == 404 || body.contains('PGRST205') || body.contains('does not exist')) {
      throw StateError("Table '$table' not found. Run supabase/migrations/20261106000000_init.sql "
          'in the Supabase SQL Editor first.\n$body');
    }
    throw StateError('$table: HTTP $code\n$body');
  }

  Future<List<Map<String, dynamic>>> select(String table, String columns) async {
    final (code, body) = await send('GET', Uri.parse('$base/$table?select=$columns'), headers: _auth);
    if (code != 200) _fail(table, code, body);
    return [for (final r in jsonDecode(body) as List) (r as Map).cast<String, dynamic>()];
  }

  Future<void> upsert(String table, List<Map<String, Object?>> rows, String onConflict) async {
    for (var i = 0; i < rows.length; i += 50) {
      final (code, body) = await send('POST', Uri.parse('$base/$table?on_conflict=$onConflict'),
          headers: {..._auth, 'Prefer': 'resolution=merge-duplicates,return=minimal'},
          body: rows.sublist(i, i + 50 > rows.length ? rows.length : i + 50));
      if (code >= 300) _fail(table, code, body);
    }
  }

  Future<void> delete(String table, String filter) async {
    final (code, body) = await send('DELETE', Uri.parse('$base/$table?$filter'), headers: _auth);
    if (code >= 300) _fail(table, code, body);
  }

  Future<int> count(String table) async {
    final req = await _client.openUrl('GET', Uri.parse('$base/$table?select=*&limit=1'));
    _auth.forEach(req.headers.set);
    req.headers.set('Prefer', 'count=exact');
    final res = await req.close();
    await res.drain<void>();
    return int.tryParse(res.headers.value('content-range')?.split('/').last ?? '') ?? -1;
  }
}
