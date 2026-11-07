import 'package:flutter_test/flutter_test.dart';
import 'package:ground_truth/models.dart';
import 'package:ground_truth/risk_source.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ground_truth/store.dart';

import 'fixture_risks.dart';

void main() {
  test('Trigger parser extracts title, description and completion', () {
    const raw = 'Trigger ID: R1055 - T0649\n'
        'Title: Further aid cuts in eastern Chad\n'
        'Description: \n:Reduced food, health, shelter, or cash assistance\n'
        'Sources: \n(x)\nCompletion rate: 90%\n';
    final t = parseTriggers(raw);
    expect(t.length, 1);
    expect(t.first.id, 'R1055 - T0649');
    expect(t.first.title, 'Further aid cuts in eastern Chad');
    expect(t.first.description, 'Reduced food, health, shelter, or cash assistance');
    expect(t.first.completion, 90);
  });

  test('A Supabase risks row maps onto the same Risk fields', () {
    final r = Risk.fromDb({
      'risk_id': 'R9999',
      'title': 'Floods displace thousands in La Niña year',
      'risk_type': 'New emerging risk',
      'iso': 'TCD, SDN',
      'country': 'Chad, Sudan',
      'rationale': 'See [ACLED 08/04/2026](https://acleddata.com).',
      'impact': 4,
      'probability': 'High',
      'risk_level': 'High',
      'risk_trend': 'Deteriorated',
      'status': 'Active',
      'expected_exposure': '>500,000',
      'expected_priority_needs': ['Shelter', 'WASH'],
      'hazard_materialisation': null,
      'impact_materialisation_description': '',
      'triggers_raw': 'Trigger ID: R9999 - T1\nTitle: Rains\nDescription: Heavy rains\nCompletion rate: 30%\n',
    });
    expect(r.id, 'R9999');
    expect(r.title, contains('Niña'));
    expect(r.country, 'Chad, Sudan');
    expect(r.iso, 'TCD, SDN');
    expect(r.probabilityIdx, 3);
    expect(r.impact, 4);
    expect(r.needs, 'Shelter, WASH');
    expect(r.needList, ['WASH', 'Shelter']); // ACAPS's order
    expect(r.rationale, 'See ACLED 08/04/2026.');
    expect(r.materialisation, isEmpty);
    expect(r.triggers.single.completion, 30);
    expect(r.isActive, isTrue);
  });

  test('A risk survives the on-device copy unchanged', () {
    final r = snapshotFromRows(FixtureRiskSource.rows()).risks.firstWhere((x) => x.id == demoRiskId);
    final back = Risk.fromJson(r.toJson());
    expect(back.toJson(), r.toJson());
    expect(back.triggers.first.completion, r.triggers.first.completion);
  });

  test('The fixture is the ACAPS API snapshot: the demo risk is active, removed risks are gone', () {
    final snap = snapshotFromRows(FixtureRiskSource.rows());
    expect(snap.risks.length, greaterThan(100));
    expect(snap.syncedAt, isNotNull);
    final demo = snap.risks.firstWhere((r) => r.id == demoRiskId);
    expect(demo.isActive, isTrue);
    expect(demo.surveyItems.length, 3);
    expect(snap.risks.where((r) => r.id == 'R1043'), isEmpty); // no longer in the Risk Radar API
  });

  test('Offline: the app uses the copy of the risks saved on the device', () async {
    SharedPreferences.setMockInitialValues({});
    useFixtureRisks();
    final online = AppState();
    await online.load();
    expect(online.error, isNull);
    expect(online.risksFromCache, isFalse);
    final n = online.risks.length;

    riskSource = const OfflineRiskSource();
    final offline = AppState();
    await offline.load();
    expect(offline.error, isNull);
    expect(offline.risksFromCache, isTrue);
    expect(offline.risks.length, n);
    expect(offline.byId(demoRiskId)?.surveyItems.length, 3);
    useFixtureRisks();
  });

  test('Offline with nothing saved yet: a clear error instead of an empty app', () async {
    SharedPreferences.setMockInitialValues({});
    riskSource = const OfflineRiskSource();
    final s = AppState();
    await s.load();
    expect(s.loaded, isTrue);
    expect(s.error, contains('No risks'));
    useFixtureRisks();
  });
}
