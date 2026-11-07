// Tests never call Supabase: they load a snapshot of the `risks` table
// (test/fixtures/risks.json, taken right after scripts/sync_risks.dart ran
// against the ACAPS Risk Radar API).
//
// Refresh the snapshot after a sync with, from the repo root:
//   curl "$SUPABASE_URL/rest/v1/risks?select=<columns in lib/risk_source.dart>&order=risk_id" \
//     -H "apikey: $SUPABASE_PUBLISHABLE_KEY" > app-mobile/test/fixtures/risks.json

import 'dart:convert';
import 'dart:io';

import 'package:ground_truth/risk_source.dart';

class FixtureRiskSource implements RiskSource {
  const FixtureRiskSource();

  /// The table rows exactly as Supabase returns them.
  static List<Map<String, dynamic>> rows() {
    // Read synchronously: widget tests run in a fake-async zone where real
    // file I/O would never complete.
    final raw = File('test/fixtures/risks.json').readAsStringSync();
    return [for (final r in jsonDecode(raw) as List) (r as Map).cast<String, dynamic>()];
  }

  @override
  Future<RiskSnapshot> fetch() async => snapshotFromRows(rows());
}

/// A source that is always offline, to test the on-device copy.
class OfflineRiskSource implements RiskSource {
  const OfflineRiskSource();

  @override
  Future<RiskSnapshot> fetch() async => throw const SocketException('offline');
}

void useFixtureRisks() => riskSource = const FixtureRiskSource();
