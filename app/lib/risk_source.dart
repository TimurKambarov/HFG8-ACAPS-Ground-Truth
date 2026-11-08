/// Where the risks come from: the Supabase `risks` table, which
/// scripts/sync_risks.dart keeps equal to the live ACAPS Risk Radar API.
///
/// The app only reads. It never calls the ACAPS API itself and never writes
/// risks: the sync script does that with the secret key, and only when the
/// API has something new (an up-to-date database is left alone).
///
/// The last risks loaded are kept on the device (see AppState), so the app
/// still opens offline or in a build without the Supabase keys, as long as it
/// loaded the risks once before.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth.dart';
import 'models.dart';

/// The risks plus when the newest of them was last changed by the sync.
class RiskSnapshot {
  final List<Risk> risks;

  /// Latest `imported_at` among the rows: when the sync last changed anything.
  final DateTime? syncedAt;
  const RiskSnapshot(this.risks, this.syncedAt);
}

abstract class RiskSource {
  Future<RiskSnapshot> fetch();
}

/// Columns the app needs (the table has more, e.g. sources and vulnerability).
const _columns = 'risk_id,title,risk_type,iso,country,rationale,impact,probability,risk_level,risk_trend,status,'
    'expected_exposure,expected_priority_needs,hazard_materialisation,impact_materialisation_description,'
    'triggers_raw,imported_at';

class SupabaseRiskSource implements RiskSource {
  const SupabaseRiskSource();

  @override
  Future<RiskSnapshot> fetch() async {
    if (!Auth.ready) {
      throw StateError(Auth.problem ??
          'This build has no Supabase keys, so the risks cannot be loaded. Start it with run.ps1 (see README).');
    }
    final rows = await Supabase.instance.client
        .from('risks')
        .select(_columns)
        .order('risk_id')
        .timeout(const Duration(seconds: 20));
    return snapshotFromRows(rows);
  }
}

/// Table rows -> risks. Rows without an id or title are skipped.
RiskSnapshot snapshotFromRows(List<Map<String, dynamic>> rows) {
  DateTime? latest;
  final risks = <Risk>[];
  for (final m in rows) {
    final r = Risk.fromDb(m);
    if (r.id.isEmpty || r.title.isEmpty) continue;
    risks.add(r);
    final at = DateTime.tryParse('${m['imported_at'] ?? ''}');
    if (at != null && (latest == null || at.isAfter(latest))) latest = at;
  }
  return RiskSnapshot(risks, latest?.toLocal());
}

/// Used by the app. Tests replace it with a fixed list.
RiskSource riskSource = const SupabaseRiskSource();
