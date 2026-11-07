import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ground_truth/main.dart';
import 'package:ground_truth/models.dart';
import 'package:ground_truth/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _start(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  await tester.runAsync(() => appState.load());
  await appState.resetDemo();
  appState.theme = AppTheme.dark;
  appState.signInModerator();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const GroundTruthApp());
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [const Size(1900, 1000), const Size(400, 800)]) {
    testWidgets('moderator renders all tabs and sheets at ${size.width}', (tester) async {
      await _start(tester, size);
      expect(find.text('Inbox'), findsWidgets);

      // Inbox badge counts new comments only.
      expect(find.descendant(of: find.byType(Badge), matching: find.text('${appState.commentsToReview}')), findsWidgets);

      // No per-country invite buttons in the Inbox any more.
      expect(find.text('Invite'), findsNothing);

      // The invite button at the top generates a single-use link straight away:
      // no country to pick, no QR code.
      final before = appState.invites.length;
      await tester.tap(find.byTooltip('Invite an expert (single-use link)'));
      await tester.pumpAndSettle();
      expect(appState.invites.length, before + 1);
      expect(find.text('New invite link'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      expect(find.text('Copy invitation message'), findsOneWidget);
      expect(find.textContaining('?invite=GT-'), findsWidgets);
      expect(find.byType(DropdownMenu<String>), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      for (final tab in ['Risks', 'Comments', 'Experts', 'Profile', 'Inbox']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
      }

      // Experts tab: no second invite button.
      await tester.tap(find.text('Experts').last);
      await tester.pumpAndSettle();
      expect(find.text('Invite experts'), findsNothing);

      // Profile: this moderator's name and display settings.
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      expect(find.text('Sarah Okafor'), findsOneWidget);
      expect(find.text('Text size'), findsOneWidget);

      // Comments tab: review actions for the risk with most new comments.
      await tester.tap(find.text('Comments').last);
      await tester.pumpAndSettle();
      if (size.width < 900) {
        await tester.tap(find.textContaining('R1043 ·').first);
        await tester.pumpAndSettle();
      }
      expect(find.text('Mark reviewed'), findsWidgets);
      if (size.width < 900) {
        await tester.pageBack();
        await tester.pumpAndSettle();
      }

      // Invite button in the app bar, on any tab.
      await tester.tap(find.byTooltip('Invite an expert (single-use link)'));
      await tester.pumpAndSettle();
      expect(find.text('New invite link'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Expert-input sheet from the R1043 page lists contributors who opted in.
      await tester.tap(find.text('Risks').last);
      await tester.pumpAndSettle();
      if (size.width < 900) {
        await tester.tap(find.textContaining('R1043').first);
        await tester.pumpAndSettle();
      }
      // Scroll until the button is really tappable (not under the sticky bottom bar).
      final exportButton = find.text('Expert input').hitTestable();
      for (var i = 0; i < 20 && exportButton.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -150));
        await tester.pumpAndSettle();
      }
      await tester.tap(exportButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('Expert input for ACAPS'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Contributors'), 150, scrollable: find.byType(Scrollable).last);
      expect(find.text('Contributors'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      if (size.width < 900) {
        await tester.pageBack();
        await tester.pumpAndSettle();
      }

      // A trigger's comment chip on the Risks tab opens those comments.
      await tester.tap(find.text('Risks').last);
      await tester.pumpAndSettle();
      if (size.width < 900) {
        await tester.tap(find.textContaining('R1043').first);
        await tester.pumpAndSettle();
      }
      final chip = find.textContaining('· open');
      for (var i = 0; i < 30 && chip.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -250));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(chip.first);
      await tester.pumpAndSettle();
      await tester.tap(chip.first);
      await tester.pumpAndSettle();
      // Scrolled to that trigger's comments, with their per-comment actions.
      expect(find.text('ACTIONS FOR THIS COMMENT ONLY'), findsWidgets);
      if (size.width < 900) {
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
      }

      // New risk form opens from the Risks tab.
      await tester.tap(find.text('Risks').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('New risk'));
      await tester.pumpAndSettle();
      expect(find.text('Publish to experts'), findsOneWidget);
    });
  }

  testWidgets('expert entry pop-up is a centred dialog, Start opens the questions', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => appState.load());
    await appState.resetDemo();
    appState.signInAs(appState.expertById('p1')!);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GroundTruthApp());
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Not now')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Start')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Trigger 1 of'), findsOneWidget);
  });

  testWidgets('"Not now" hides the banner, says so, and can be undone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => appState.load());
    await appState.resetDemo();
    final p1 = appState.expertById('p1')!;
    appState.signInAs(p1);
    appState.autoOpened.add('p1|${appState.pendingNotification!.id}'); // skip the entry pop-up
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GroundTruthApp());
    await tester.pumpAndSettle();

    final r = appState.pendingNotification!;
    expect(find.text(r.title), findsOneWidget); // the banner names the risk
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(appState.pendingNotification, isNull);
    expect(appState.isSkipped(r), isTrue);
    expect(find.text('Skipped'), findsOneWidget); // tag on the risk card
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(appState.isSkipped(r), isFalse);
    expect(appState.pendingNotification?.id, r.id);

    // The message closes by itself after 5 seconds.
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('experts never see which moderator handled their comment', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => appState.load());
    await appState.resetDemo();
    appState.signInAs(appState.expertById('p1')!); // p1's comment s5 was marked useful and used by Sarah Okafor
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GroundTruthApp());
    await tester.pumpAndSettle();
    final popupNotNow = find.descendant(of: find.byType(AlertDialog), matching: find.text('Not now'));
    if (popupNotNow.evaluate().isNotEmpty) {
      await tester.tap(popupNotNow);
      await tester.pumpAndSettle();
    }
    // My forecasts tab: track record plus comment feedback, in one place.
    await tester.tap(find.text('My forecasts').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('vs ACAPS'), findsOneWidget); // accuracy compared with ACAPS, same risks
    expect(find.text('total points'), findsOneWidget);
    expect(find.text('marked useful'), findsOneWidget);
    expect(find.text('used in analysis'), findsOneWidget);
    expect(find.text('comments'), findsNothing); // no plain comment count
    // Scroll through the whole list, checking each screenful for moderator names.
    final flag = find.textContaining('Marked useful by ACAPS');
    var seen = false;
    for (var i = 0; i < 40; i++) {
      seen |= flag.evaluate().isNotEmpty;
      for (final m in moderators) {
        expect(find.textContaining(m.name), findsNothing);
        expect(find.textContaining(m.shortName), findsNothing);
      }
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(seen, isTrue);
  });

  test('risks from the earlier list are marked (longer time frames)', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load();
    expect(s.byId('R0233')!.fromEarlierList, isTrue);
    expect(s.byId('R1043')!.fromEarlierList, isFalse);
  });

  testWidgets('start screen: Register goes straight to the profile form; Log in to existing users', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => appState.load());
    await appState.resetDemo();
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GroundTruthApp());
    await tester.pumpAndSettle();

    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.byType(TextField), findsNothing); // no field to paste links or codes into

    // Log in: existing members only, no way to create a profile without a link.
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Harmattan-17'), findsOneWidget);
    expect(find.text('Join the group'), findsNothing);
    await tester.tap(find.text('Back to start'));
    await tester.pumpAndSettle();

    // Register: straight to the profile form, no in-between page, no user list.
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    expect(find.text('Your profile'), findsOneWidget);
    expect(find.text('1. HOW VISIBLE DO YOU WANT TO BE?'), findsOneWidget);
    expect(find.text('Harmattan-17'), findsNothing);
    expect(find.textContaining('Create my profile'), findsNothing);

    // Back returns to the start screen.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Register'), findsOneWidget);

    // Register for real (level 3 needs no name): the link is used up and the app opens.
    final open = appState.invites.where((i) => i.open).length;
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Level 3'));
    await tester.pumpAndSettle();
    final join = find.text('Join the group');
    await tester.scrollUntilVisible(join, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(join);
    await tester.pumpAndSettle();
    expect(appState.me, isNotNull);
    expect(appState.invites.where((i) => i.open).length, open - 1);
  });

  test('opening a new invite link signs out whoever is signed in on the device', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load();
    s.signInModerator('m1');
    final i = s.createInvite();
    expect(s.openInviteLink('https://example.org/?invite=${i.code}'), InviteStatus.ok);
    expect(s.signedIn, isFalse);
    expect(s.canRegister, isTrue); // straight to the profile form
  });

  test('referral links: one permanent link per expert, +100 per colleague who joins', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load();
    final codes = s.experts.map((e) => e.referralCode).toList();
    expect(codes.every((c) => RegExp(r'^REF-[A-Z2-9]{4}-[A-Z2-9]{4}$').hasMatch(c)), isTrue);
    expect(codes.toSet().length, codes.length); // unique

    final p2 = s.expertById('p2')!;
    final link = inviteLink(p2.referralCode);
    final before = s.statsOf(p2).points;

    // A colleague opens the link: straight to the profile form.
    expect(s.openInviteLink(link), InviteStatus.ok);
    expect(s.canRegister, isTrue);
    expect(s.pendingReferrer?.id, 'p2');
    final a = s.register(level: Anonymity.anonymous, realName: null, pseudonym: 'Joiner-1', homeCountry: 'Cameroon',
        interests: {'Chad', 'Sudan'}, notifications: true, onRating: true);
    expect(s.referralsBy(p2), 1);
    expect(s.statsOf(p2).points, before + Points.referral);
    // The new member gets their own referral link.
    expect(a.referralCode, startsWith('REF-'));
    // The inviter can follow the colleague's progress: stage only.
    expect(s.referralProgress(p2).single.stage, ReferralStage.joined);
    final open = s.risks.where((r) => r.isActive && s.relevantTo(a, r)).take(3).toList();
    expect(open.length, 3);
    for (final (i, r) in open.indexed) {
      s.submit(r, {for (final it in r.surveyItems) it.id: const ItemAnswer(agree: Agreement.yes, severity: 3)}, forecast: 3);
      expect(s.referralProgress(p2).single.answered, i + 1);
      expect(s.referralProgress(p2).single.stage, i == 0 ? ReferralStage.firstRisk : (i == 1 ? ReferralStage.firstRisk : ReferralStage.threeRisks));
    }

    // Permanent: the same link works again for another colleague.
    s.signOut();
    expect(s.openInviteLink(link), InviteStatus.ok);
    s.register(level: Anonymity.anonymous, realName: null, pseudonym: 'Joiner-2', homeCountry: 'Chad',
        interests: {}, notifications: true, onRating: true);
    expect(s.referralsBy(p2), 2);
    expect(s.statsOf(p2).points, before + 2 * Points.referral);

    // Same link after a restart; the referrals are kept.
    final again = AppState();
    await again.load();
    expect(again.expertById('p2')!.referralCode, p2.referralCode);
    expect(again.referralsBy(again.expertById('p2')!), 2);
  });

  testWidgets('profile shows the expert\'s own referral link', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => appState.load());
    await appState.resetDemo();
    appState.signInAs(appState.expertById('p1')!);
    appState.autoOpened.add('p1|${appState.pendingNotification!.id}');
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GroundTruthApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('INVITE A COLLEAGUE'), findsOneWidget);
    expect(find.textContaining('?invite=REF-'), findsOneWidget);
    expect(find.textContaining('2 colleagues joined through your link · +200 points'), findsOneWidget);
    // Progress per colleague: stage only, no names.
    expect(find.text('Colleague 1'), findsOneWidget);
    expect(find.text('Colleague 2'), findsOneWidget);
    expect(find.textContaining('fully active'), findsOneWidget);
    expect(find.text('Joined · no risks answered yet'), findsOneWidget);
    expect(find.textContaining('Cedar-66'), findsNothing);
    expect(find.textContaining('Rift-07'), findsNothing);
    // It comes after the anonymity level section.
    expect(tester.getTopLeft(find.text('INVITE A COLLEAGUE')).dy,
        greaterThan(tester.getTopLeft(find.text('ANONYMITY LEVEL')).dy));
    expect(find.textContaining('Demo: you get +100 points'), findsOneWidget);
  });

  test('invite links are single-use and never linked to the account', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load();
    s.signInModerator('m2');
    final i = s.createInvite(note: 'Researcher, Nairobi');
    expect(i.code, matches(RegExp(r'^GT-[A-Z2-9]{4}-[A-Z2-9]{4}$')));
    expect(i.createdBy, 'm2');
    s.signOut();

    expect(s.redeemInvite('nope'), InviteStatus.unknown);
    // No profile without a valid invite link.
    expect(() => s.register(level: Anonymity.anonymous, realName: null, pseudonym: 'X', homeCountry: 'Kenya',
        interests: {}, notifications: true, onRating: true), throwsStateError);
    // The whole link works (as opened or pasted), not only the token.
    expect(s.redeemInvite('https://example.org/app/?invite=${i.code}&utm=x'), InviteStatus.ok);
    expect(s.canRegister, isTrue); // straight to the profile form
    final e = s.register(level: Anonymity.anonymous, realName: null, pseudonym: 'Rift-01', homeCountry: 'Kenya',
        interests: {}, notifications: true, onRating: true);
    expect(i.used, isTrue);
    // Only WHEN it was used is stored, never by whom.
    expect(jsonEncode(i.toJson()).contains(e.id), isFalse);
    expect(jsonEncode(i.toJson()).contains('Rift-01'), isFalse);

    // A second person cannot use the same link.
    s.signOut();
    expect(s.redeemInvite(i.code), InviteStatus.used);

    // A cancelled link stops working.
    s.signInModerator('m1');
    final j = s.createInvite();
    s.revokeInvite(j);
    s.signOut();
    expect(s.redeemInvite(j.code), InviteStatus.revoked);

    // Kept after a restart.
    final again = AppState();
    await again.load();
    expect(again.inviteByCode(i.code)?.used, isTrue);
    expect(again.inviteByCode(j.code)?.revoked, isTrue);
  });

  test('closed risks are read-only and earn no points', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load();
    s.redeemInvite(s.demoInvite!.code); // joining needs an invite link
    s.register(level: Anonymity.pseudonymous, realName: 'Test Person', pseudonym: 'Tester', homeCountry: 'Chad',
        interests: {'Sudan'}, notifications: true, onRating: true);
    final closed = s.archiveForMe().first;
    final before = s.statsOf(s.me!).points;

    // The archive has every closed risk, not only my countries; mine first.
    expect(s.archiveForMe().length, s.risks.where((r) => r.isResolved).length);
    expect(s.archiveForMe().any((r) => !s.relevantTo(s.me!, r)), isTrue);
    expect(s.relevantTo(s.me!, closed), isTrue);

    // Answered closed risks stay in the archive too.
    s.signInAs(s.expertById('p2')!);
    expect(s.archiveForMe(), isNotEmpty);
    expect(s.archiveForMe().where((r) => s.responseOf(s.me!, r) != null), isNotEmpty);
    s.signInAs(s.experts.last);
    s.submit(closed, {for (final it in closed.surveyItems) it.id: const ItemAnswer(agree: Agreement.yes, severity: 3)}, forecast: 5);
    expect(s.responseOf(s.me!, closed), isNull);
    expect(s.statsOf(s.me!).points, before);
  });

  test('moderators have own accounts, signed actions and display settings', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load();
    s.signInModerator('m2');
    expect(s.moderator?.name, 'Tomás Lindqvist');
    s.setTheme(AppTheme.dark);
    s.setTextScale(1.3);
    final c = s.comments.firstWhere((c) => c.needsReview);
    final before = s.commentsToReview;
    s.toggleUseful(c);
    expect(c.usefulBy, 'm2');
    expect(c.reviewedBy, 'm2');
    expect(s.commentsToReview, before - 1);
    expect(s.activityOf(s.moderator!).useful, greaterThanOrEqualTo(1));

    s.signInModerator('m3');
    expect(s.theme, AppTheme.system);
    expect(s.textScale, 1.0);

    // Persisted: back to m2 after a restart.
    final again = AppState();
    await again.load();
    expect(again.moderator?.id, 'm3');
    again.signInModerator('m2');
    expect(again.theme, AppTheme.dark);
    expect(again.textScale, 1.3);
    expect(again.comments.firstWhere((x) => x.id == c.id).usefulBy, 'm2');
  });

  test('saved risks persist, have no simulated answers, and can be deleted', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load();
    final id = s.nextRiskId();
    s.saveRisk(Risk(
      custom: true, id: id, title: 'Test risk', type: 'New emerging risk', country: 'Chad', rationale: 'Because.',
      probabilityIdx: 3, impact: 4, level: 'High', trend: '', status: 'Active', exposure: '', needs: '',
      materialisation: '', triggers: const [Trigger(id: 'T1', title: 'Trigger one', description: '')],
    ));
    expect(s.respondents(s.byId(id)!), isEmpty);
    expect(s.panelForRisk(s.byId(id)!).length, greaterThanOrEqualTo(minPanel));

    final again = AppState();
    await again.load();
    expect(again.byId(id)?.title, 'Test risk');
    expect(again.byId(id)?.triggers.single.title, 'Trigger one');

    again.deleteRisk(again.byId(id)!);
    final third = AppState();
    await third.load();
    expect(third.byId(id), isNull);
  });

  testWidgets('survey: triggers first, then one scored forecast', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => appState.load());
    await appState.resetDemo();
    appState.signInAs(appState.expertById('p1')!);
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GroundTruthApp());
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Start')));
    await tester.pumpAndSettle();

    final r = appState.byId('R1043')!;
    for (var i = 0; i < r.surveyItems.length; i++) {
      expect(find.textContaining('Trigger ${i + 1} of'), findsWidgets);
      expect(find.textContaining('How likely'), findsNothing); // no forecast on trigger screens
      await tester.tap(find.text('Yes'));
      await tester.tap(find.text('Serious'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    // The forecast screen: ACAPS words with their ranges.
    expect(find.text('YOUR FORECAST · SCORED'), findsOneWidget);
    expect(find.text('High\n67–90%'), findsOneWidget);
    await tester.tap(find.text('High\n67–90%'));
    await tester.pumpAndSettle();
    expect(find.textContaining('You: High (67–90%)'), findsOneWidget);
    await tester.tap(find.text('Send answers'));
    await tester.pumpAndSettle();

    final resp = appState.responseOf(appState.me!, r)!;
    expect(resp.forecast, 4);
    expect(resp.items.length, r.surveyItems.length);
    expect(find.text('FORECAST: WILL IT MATERIALISE WITHIN 6 MONTHS?'), findsOneWidget);
  });

  test('group view is the median and the middle half (Delphi-style)', () {
    // 10 experts: Low 1, Medium 3, High 5, Very high 1.
    final g = GroupView.of([2, 3, 3, 3, 4, 4, 4, 4, 4, 5])!;
    expect(g.median, 4);
    expect(g.probability, 'High (67–90%)');
    expect([g.low, g.high], [3, 4]);
    expect(g.spread(levelLabels), 'Most experts between Medium and High');

    // One outlier cannot drag the group answer (an average would drop to 3.7).
    expect(GroupView.of([1, 4, 4, 4, 4, 4, 4, 4, 4, 4])!.probability, 'High (67–90%)');

    // Everyone the same, and a split panel.
    expect(GroupView.of([4, 4, 4])!.spread(levelLabels), 'Experts agree: nearly all said High');
    expect(GroupView.of([1, 2, 4, 5, 5])!.spread(levelLabels), startsWith('Opinions split'));

    // ACAPS's own example (feedback notes, section 2): same average, opposite messages.
    final a = GroupView.of([3, 3, 3, 3])!, b = GroupView.of([1, 1, 5, 5])!;
    expect(a.probabilityHeadline, 'Group: Medium (34–66%)');
    expect(a.split, isFalse);
    expect(b.split, isTrue);
    expect(b.probabilityHeadline, 'No clear group view: opinions split'); // never "Group: Medium"
    expect(b.spread(levelLabels), 'Opinions split: answers range from Very low to Very high');

    // "Experts agree" only when nearly all agree; 4 of 7 is "most".
    expect(GroupView.of([2, 2, 3, 3, 3, 3, 4])!.spread(levelLabels), 'Most experts said Medium');

    // Even panel exactly between two steps: said so, not rounded.
    expect(GroupView.of([3, 3, 4, 4])!.probability, 'between Medium and High');
    expect(GroupView.of([3, 4, 4, 4])!.severity, '4 of 5 (Severe)');
    expect(GroupView.of(const []), isNull);
  });

  test('one forecast per risk, scored on the ACAPS scale', () async {
    // ACAPS ranges (methodology PDF), scored at the middle of each range.
    expect(probabilityText(4), 'High (67–90%)');
    expect(accuracyPct(brier(4, true)), 96); // High (80%) and it happened
    expect(accuracyPct(brier(4, false)), 36); // High (80%) and it did not
    expect(accuracyPct(brier(3, true)), 75); // Medium (50%): 75% either way
    expect(accuracyPct(brier(3, false)), 75);
    expect(accuracyPct(brier(5, true)), 100); // Very high (95%), rounded

    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load();
    // Every simulated answer has exactly one forecast; trigger answers have none.
    final p1 = s.expertById('p1')!;
    final matured = s.responsesOf(p1).where((x) => s.byId(x.riskId)!.isResolved).first;
    expect(matured.forecast, isNotNull);
    final r = s.byId(matured.riskId)!;
    final score = s.scoreOf(matured)!;
    expect(score.mine, brier(matured.forecast!, r.materialised));
    expect(score.acaps, brier(r.acapsLikelihood!, r.materialised));

    // Answers saved in the old format (likelihood per trigger) become one forecast.
    final old = Response.fromJson({
      'expert': 'x', 'risk': 'R1043', 'at': '2026-10-01T00:00:00.000',
      'items': {
        'a': {'agree': 0, 'likelihood': 4, 'severity': 3},
        'b': {'agree': 1, 'likelihood': 5, 'severity': 3},
      },
    });
    expect(old.forecast, 5); // average 4.5, rounded
    expect(old.items['a']!.severity, 3);
  });

  test('public view JSON has aggregates only', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load();
    final m = jsonDecode(s.publicViewJson([s.byId('R1043')!])) as Map<String, dynamic>;
    final r = (m['risks'] as List).single as Map<String, dynamic>;

    // ACAPS fields use the Risk Radar export / API names (feedback notes, section 7).
    final header = (await File('assets/risk-radar-export.csv').readAsLines()).first.split(',');
    for (final k in ['Risk ID', 'Risk Title', 'Risk Type', 'ISO', 'Country', 'Probability', 'Impact', 'Risk Level', 'Risk trend', 'Status']) {
      expect(header, contains(k));
      expect(r.containsKey(k), isTrue, reason: k);
    }
    expect(r['Risk ID'], 'R1043');
    expect(r['ISO'], 'TCD');
    expect(r['Probability'], 'High');
    expect(m['probability_scale']['4'], {'label': 'High', 'range': '67–90%'});

    // Expert input: one forecast per risk; triggers carry ground truthing only.
    final x = r['expert_input'] as Map<String, dynamic>;
    expect(x['published'], isTrue);
    expect((x['forecast']['distribution_1_5'] as List).length, 5);
    expect(x['forecast']['median_label'], 'High (67–90%)'); // the R1043 demo story
    expect(x['forecast']['opinions_split'], isFalse);
    expect(x['forecast']['trend']['then_label'], 'Medium'); // the live picture
    expect(x['forecast']['trend']['now_label'], 'High');
    final q = (x['triggers'] as List).first as Map<String, dynamic>;
    expect(q['Trigger ID'], 'R1043 - T0618');
    expect(q.containsKey('likelihood'), isFalse);
    expect((q['severity']['distribution_1_5'] as List).length, 5);

    // A split panel is flagged, never given a misleading group answer.
    final split = jsonDecode(s.publicViewJson([s.byId('R1049')!]))['risks'][0]['expert_input']['forecast'];
    expect(split['opinions_split'], isTrue);
    final text = jsonEncode(m);
    for (final e in s.experts) {
      expect(text.contains(e.pseudonym), isFalse);
    }
    expect(text.contains('Smuggling routes'), isFalse); // no comments

    // With credits: by default each expert is credited as their profile
    // anonymity level says (1 real name, 2 pseudonym, 3 anonymous).
    final r1043 = s.byId('R1043')!;
    final withNames = (jsonDecode(s.publicViewJson([r1043], credits: true))['risks'] as List).single['expert_input'] as Map<String, dynamic>;
    final names = [for (final c in withNames['contributors'] as List) c['name']];
    expect(names, contains('Fatimé Abakar')); // level 1: real name
    expect(names, contains('Nomad-55')); // level 2: pseudonym
    expect(names, isNot(contains('Delta-30'))); // level 3: anonymous
    expect(withNames['anonymous_contributors'], s.respondents(r1043).length - names.length);

    // The default follows the profile, and the expert can change it per risk.
    s.signInAs(s.expertById('p1')!); // level 1, real name stored
    expect(defaultCredit(s.me!), Credit.realName);
    expect(defaultCredit(s.expertById('p2')!), Credit.pseudonym);
    expect(defaultCredit(s.expertById('p3')!), Credit.anonymous);
    s.submit(r1043, {for (final it in r1043.surveyItems) it.id: const ItemAnswer(agree: Agreement.yes, severity: 3)}, forecast: 3);
    expect(s.creditsFor(r1043).map((c) => c.name), contains('Amina Haroun'));
    s.submit(r1043, {for (final it in r1043.surveyItems) it.id: const ItemAnswer(agree: Agreement.yes, severity: 3)}, forecast: 3,
        credit: Credit.anonymous);
    expect(s.creditsFor(r1043).map((c) => c.name), isNot(contains('Amina Haroun')));
    s.submit(r1043, {for (final it in r1043.surveyItems) it.id: const ItemAnswer(agree: Agreement.yes, severity: 3)}, forecast: 3,
        credit: Credit.pseudonym);
    expect(s.creditsFor(r1043).map((c) => c.name), contains('Harmattan-17'));
  });

  testWidgets('experts can search risks by number, word or country', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => appState.load());
    await appState.resetDemo();
    appState.signInAs(appState.expertById('p1')!);
    appState.autoOpened.add('p1|${appState.pendingNotification!.id}'); // skip the entry pop-up
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GroundTruthApp());
    await tester.pumpAndSettle();

    final field = find.widgetWithText(TextField, 'Search ID, title or country');
    expect(field, findsOneWidget);

    // By number: only R1049 (an active risk) remains.
    await tester.enterText(field, '1049');
    await tester.pumpAndSettle();
    expect(find.textContaining('R1049'), findsWidgets);
    expect(find.textContaining('R1043'), findsNothing);

    // By word: closed risks match too (archive), e.g. R0073, protests in Sudan.
    await tester.enterText(field, 'protests');
    await tester.pumpAndSettle();
    expect(find.textContaining('R0073'), findsOneWidget);

    // Nothing found.
    await tester.enterText(field, 'zzzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('No risks match'), findsOneWidget);

    // Clear brings the full list back.
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.textContaining('R1043'), findsWidgets);
  });
}
