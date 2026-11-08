import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ground_truth/acaps_api.dart';
import 'package:ground_truth/models.dart';
import 'package:ground_truth/screens/import_risk.dart';
import 'package:ground_truth/store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake ACAPS API: a token, then two pages of the Risk Radar.
MockClient _fakeApi() => MockClient((req) async {
      if (req.url.path == '/api/v1/token-auth/') return http.Response('{"token":"t"}', 200);
      expect(req.headers['Authorization'], 'Token t');
      Map<String, dynamic> risk(String id, String title, String status) => {
            'risk_id': id,
            'risk_title': title,
            'risk_type': 'New emerging risk',
            'iso3': ['TCD'],
            'country': ['Chad'],
            'rationale': 'Why ACAPS expects it.',
            'probability': 'Medium',
            'impact': '3',
            'risk_level': 'Medium',
            'status': status,
            'triggers_summary': 'Trigger ID: $id - T1\nTitle: Border clashes\nDescription: \nMore attacks\n',
            'last_risk_update': '2026-11-01',
          };
      final page2 = req.url.queryParameters['page'] == '2';
      return http.Response(
        jsonEncode({
          'next': page2 ? null : 'https://api.acaps.org/api/v1/risk-radar/risk-radar/?page=2',
          'results': page2
              ? [risk('R9001', 'Fresh risk from the API', 'Active')]
              // R1043 is Active in the bundled export: ACAPS has closed it since.
              : [risk('R1043', 'Already in the app', 'Materialised')],
        }),
        200,
      );
    });

Future<void> _setUp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.runAsync(() => appState.load());
  await appState.resetDemo();
  appState.signInModerator();
  AcapsApi.cache = null;
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Opens the screen from a button, so it can pop with a result.
Future<void> _open(WidgetTester tester, RadarMode mode, void Function(Risk?) onResult) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async => onResult(await Navigator.of(context)
            .push<Risk>(MaterialPageRoute(builder: (_) => ImportRiskScreen(mode: mode, api: AcapsApi(client: _fakeApi()))))),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  // The client waits 1 s between pages, as the API asks.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1300)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sync statuses: review the changes, apply, survives a restart', (tester) async {
    await _setUp(tester);
    await _open(tester, RadarMode.syncStatuses, (_) {});

    expect(find.text('Sync statuses from Risk Radar'), findsOneWidget);
    // No import list on this screen.
    expect(find.text('Fresh risk from the API'), findsNothing);
    expect(find.text('Not in app'), findsNothing);

    // R1043 is Active in the bundled export; ACAPS has closed it since.
    expect(appState.byId('R1043')!.isActive, isTrue);
    expect(find.text('1 status update'), findsOneWidget);
    expect(find.text('R1043 · Active → Materialised (Archive)'), findsOneWidget);
    await tester.tap(find.text('Apply 1 update'));
    await tester.pumpAndSettle();
    expect(appState.byId('R1043')!.status, 'Materialised');
    expect(find.text('Statuses are up to date'), findsOneWidget);

    // Survives a restart; Reset demo goes back to the bundled export.
    await tester.runAsync(() => appState.load());
    expect(appState.byId('R1043')!.status, 'Materialised');
    await appState.resetDemo();
    expect(appState.byId('R1043')!.isActive, isTrue);
  });

  testWidgets('import a Risk Radar risk: list, review, publish', (tester) async {
    await _setUp(tester);
    Risk? result;
    await _open(tester, RadarMode.importRisks, (r) => result = r);

    expect(find.text('Import from Risk Radar'), findsOneWidget);
    // No status updates on this screen.
    expect(find.text('1 status update'), findsNothing);
    expect(appState.byId('R1043')!.isActive, isTrue);

    // Default filter: only risks not in the app yet.
    expect(find.textContaining('2 risks on the Risk Radar · 1 not in the app'), findsOneWidget);
    expect(find.text('Fresh risk from the API'), findsOneWidget);
    expect(find.text('Already in the app'), findsNothing);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('In app'), findsOneWidget);

    // Review: the form is prefilled from the API and keeps the ACAPS id.
    await tester.tap(find.text('Fresh risk from the API'));
    await tester.pumpAndSettle();
    expect(find.text('Review R9001 from ACAPS'), findsOneWidget);
    expect(find.textContaining('Pulled from the ACAPS Risk Radar API (last updated 2026-11-01)'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Fresh risk from the API'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Border clashes'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Chad'), findsOneWidget);

    // The app bar's Publish: the button at the bottom of the (long) form may be off-screen.
    await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.text('Publish')));
    await tester.pumpAndSettle();
    expect(result?.id, 'R9001');
    expect(result?.iso, 'TCD');
    final saved = appState.byId('R9001')!;
    expect(saved.isActive, isTrue);
    expect(saved.custom, isTrue);
    expect(saved.triggers.single.id, 'R9001 - T1');

    await tester.runAsync(() => appState.load());
    expect(appState.byId('R9001'), isNotNull);
    await appState.resetDemo();
    expect(appState.byId('R9001'), isNull);
  });
}
