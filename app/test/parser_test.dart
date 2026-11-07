import 'package:flutter_test/flutter_test.dart';
import 'package:ground_truth/csv.dart';
import 'package:ground_truth/models.dart';

void main() {
  test('CSV parser handles quotes and multi-line fields', () {
    final rows = parseCsv('a,b\n"x, ""y""","line1\nline2"\n');
    expect(rows.length, 2);
    expect(rows[1][0], 'x, "y"');
    expect(rows[1][1], 'line1\nline2');
  });

  test('Trigger parser extracts title, description and completion', () {
    const raw = 'Trigger ID: R1043 - T0618\n'
        'Title: Expansion of cross-border attacks\n'
        'Description: \n:Additional drone strikes near the border\n'
        'Sources: \n(x)\nCompletion rate: 40%\n';
    final t = parseTriggers(raw);
    expect(t.length, 1);
    expect(t.first.id, 'R1043 - T0618');
    expect(t.first.title, 'Expansion of cross-border attacks');
    expect(t.first.description, 'Additional drone strikes near the border');
    expect(t.first.completion, 40);
  });

  test('Risk Radar API record maps to a Risk', () {
    final r = Risk.fromApi({
      'risk_id': 'R1037',
      'risk_title': 'Escalating violence reignites civil war\n',
      'risk_type': 'Marked deterioration in an existing crisis',
      'iso3': ['SSD'],
      'country': ['South Sudan'],
      'rationale': 'Clashes rose. [ACLED 08/04/2026](https://acleddata.com)',
      'probability': 'High',
      'impact': '4',
      'risk_level': 'High',
      'risk_trend': null,
      'status': 'Active',
      'hazard_materialisation_description': null,
      'impact_materialisation_description': null,
      'expected_exposure': '>500,000',
      'expected_priority_needs': 'Food security Health',
      'triggers_summary': 'Trigger ID: R1037 - T0603\nTitle: Fighting in Upper Nile\nDescription: \nShelling near Nasir\n',
    });
    expect(r.id, 'R1037');
    expect(r.title, 'Escalating violence reignites civil war');
    expect(r.country, 'South Sudan');
    expect(r.iso, 'SSD');
    expect(r.rationale, 'Clashes rose. ACLED 08/04/2026');
    expect(r.probabilityIdx, 3);
    expect(r.impact, 4);
    expect(r.isActive, isTrue);
    expect(r.custom, isTrue);
    expect(r.trend, '');
    expect(r.triggers.single.title, 'Fighting in Upper Nile');
    expect(r.triggers.single.description, 'Shelling near Nasir');
  });
}
