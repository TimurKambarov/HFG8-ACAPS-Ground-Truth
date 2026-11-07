import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth.dart';
import 'csv.dart';
import 'identity.dart';
import 'models.dart';

export 'identity.dart';

/// A new random invite code, e.g. "GT-7Q4X-K9MB" (no 0/O/1/I to misread).
/// Referral codes use the prefix "REF". Demo mode only: with real accounts
/// the server makes the codes (same format, see the referrals migration).
/// There is no installed app yet, so people share codes, not links: the
/// new member types the code on the start screen.
String newInviteCode([Random? rnd, String prefix = 'GT']) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = rnd ?? Random.secure();
  String part() => List.generate(4, (_) => alphabet[r.nextInt(alphabet.length)]).join();
  return '$prefix-${part()}-${part()}';
}

/// A real (Supabase) account id, as opposed to a local demo id like "p1".
bool isAccountId(String id) => id.length == 36 && id.split('-').length == 5;

/// Brier score of a forecast on the ACAPS scale (1..5): squared gap between
/// its probability (the middle of the ACAPS range) and what happened.
/// 0 = perfect, 1 = worst.
double brier(int forecast, bool happened) =>
    pow(probabilityScores[forecast - 1] - (happened ? 1 : 0), 2).toDouble();

class Points {
  static const usefulComment = 25;
  static const usedComment = 50;

  /// A colleague signed up with your referral code (counted at sign-up).
  /// [referralAnswersInPilot] is the goal of the progress stages.
  static const referral = 100;
  static const referralAnswersInPilot = 3;
  static int forecast(double brier) => (100 * (1 - brier)).round();
}

/// Accuracy shown to experts: 100% = perfect, 0% = worst. Same as points per forecast.
int accuracyPct(double brier) => (100 * (1 - brier)).round();

/// Regions used by the rating filter (ACAPS-style groupings).
const regions = {
  'West & Central Africa': ['Benin', 'Cameroon', 'Central African Republic', 'Chad', 'Congo',
      'Democratic Republic of the Congo', 'Ghana', 'Ivory Coast', 'Mali', 'Mauritania', 'Niger', 'Nigeria', 'Togo'],
  'East & Southern Africa': ['Burundi', 'Ethiopia', 'Kenya', 'Madagascar', 'Mozambique', 'Rwanda', 'Somalia',
      'South Sudan', 'Sudan', 'Tanzania', 'Uganda', 'Zimbabwe'],
  'Middle East & North Africa': ['Algeria', 'Egypt', 'Iran', 'Iraq', 'Lebanon', 'Libya', 'Morocco', 'Palestine',
      'Syria', 'Tunisia', 'Turkey', 'Yemen'],
  'Asia & Pacific': ['Afghanistan', 'Bangladesh', 'Indonesia', 'Mongolia', 'Myanmar', 'Nepal', 'Papua New Guinea',
      'Philippines', 'Sri Lanka', 'Timor Leste'],
  'Americas': ['Colombia', 'Cuba', 'El Salvador', 'Guatemala', 'Haiti', 'Honduras', 'Mexico', 'Panama', 'Peru', 'Venezuela'],
  'Europe': ['Ukraine'],
};

String regionOf(String country) =>
    regions.entries.where((e) => e.value.contains(country)).firstOrNull?.key ?? 'Other';

enum RatingScope { country, region, all }

/// An ACAPS moderator account. Each moderator signs in separately, so their
/// actions on comments are attributed and their display settings are their
/// own. All moderators have the same permissions; there are no roles.
class Moderator {
  final String id;
  final String name;
  const Moderator({required this.id, required this.name});

  /// "Sarah Okafor" -> "Sarah O."
  String get shortName {
    final parts = name.split(' ');
    return parts.length < 2 ? name : '${parts.first} ${parts.last[0]}.';
  }
}

/// Synthetic moderator accounts (no real ACAPS staff).
const moderators = [
  Moderator(id: 'm1', name: 'Sarah Okafor'),
  Moderator(id: 'm2', name: 'Tomás Lindqvist'),
  Moderator(id: 'm3', name: 'Mei Tanaka'),
];

/// Real moderator accounts seen on this device (Supabase user id -> name).
final Map<String, Moderator> accountModerators = {};

Moderator? moderatorById(String? id) =>
    moderators.where((m) => m.id == id).firstOrNull ?? (id == null ? null : accountModerators[id]);

enum AppTheme { system, light, dark, contrast }

extension AppThemeText on AppTheme {
  String get label => switch (this) {
        AppTheme.system => 'System',
        AppTheme.light => 'Light',
        AppTheme.dark => 'Dark',
        AppTheme.contrast => 'High contrast',
      };
}

/// Text size range, in 5% steps.
const minTextScale = 0.85, maxTextScale = 1.5, textScaleStep = 0.05;

double snapTextScale(double v) =>
    ((v.clamp(minTextScale, maxTextScale) / textScaleStep).round() * textScaleStep * 100).round() / 100;

/// Minimum panel size before the moderator is warned (same k as country display).
const minPanel = 3;
const minResolvedForBrier = 3;

enum Award { superEstimator, usefulInsight, cited, regular, referralMaster }

/// Colleagues who must have joined with your referral code for the
/// Referral Master badge.
const referralMasterMin = 3;

extension AwardText on Award {
  String get label => switch (this) {
        Award.superEstimator => 'Super estimator',
        Award.usefulInsight => 'Useful insight',
        Award.cited => 'Cited in analysis',
        Award.regular => 'Regular',
        Award.referralMaster => 'Referral Master',
      };

  String get why => switch (this) {
        Award.superEstimator => 'Top 3 by Brier score (at least $minResolvedForBrier matured forecasts)',
        Award.usefulInsight => 'A moderator marked your comment as useful',
        Award.cited => 'Your comment was used in the analysis of another risk',
        Award.regular => 'Answered 5 or more risk surveys',
        Award.referralMaster => 'Invited $referralMasterMin or more experts who joined the community with your referral code',
      };
}

/// The second trust signal, next to how an expert joined: what they do in
/// the app. Moderators only. In the demo it comes from the simulated history.
enum Activity { newcomer, active, established }

/// Risks answered to count as active, and accuracy (with at least
/// [minResolvedForBrier] matured forecasts) that counts as a quality record.
const activeMinAnswers = 3, establishedMinAccuracy = 70;

extension ActivityText on Activity {
  String get label => switch (this) {
        Activity.newcomer => 'New',
        Activity.active => 'Active',
        Activity.established => 'Established',
      };

  String get why => switch (this) {
        Activity.newcomer => 'Fewer than $activeMinAnswers risks answered so far',
        Activity.active => '$activeMinAnswers or more risks answered',
        Activity.established => '$activeMinAnswers+ risks answered, and a comment marked useful or used in analysis, '
            'or accuracy of $establishedMinAccuracy%+ over $minResolvedForBrier+ matured forecasts',
      };
}

class RatingRow {
  final Expert? expert; // null = ACAPS baseline
  final int points;
  final int resolved;
  final double? brier;
  final Set<Award> badges;

  const RatingRow({this.expert, required this.points, required this.resolved, this.brier, this.badges = const {}});
}

class RiskModStats {
  final int panel;
  final int answered;
  final int comments;
  final int toReview;
  final double? expertLikelihood;
  final int? acapsLikelihood;

  /// 0 = everyone agrees with ACAPS, 1 = everyone disagrees (partly counts half).
  final double disagreement;

  /// The experts' forecasts among themselves (median and spread); null if none.
  final GroupView? group;

  /// How the group view moved over the last update cycle (median steps; +
  /// = experts now see it as more likely), and how many experts changed.
  final double moved;
  final int changed;

  const RiskModStats({
    required this.panel,
    required this.answered,
    required this.comments,
    required this.toReview,
    required this.expertLikelihood,
    required this.acapsLikelihood,
    required this.disagreement,
    this.group,
    this.moved = 0,
    this.changed = 0,
  });

  /// Experts disagree among themselves: no trustworthy group answer, so this
  /// part of the analysis needs attention.
  bool get split => group?.split ?? false;

  /// How many steps the middle half of forecasts spans (0 = all the same).
  int get spreadWidth => group == null ? -1 : group!.high - group!.low;

  double get responseRate => panel == 0 ? 0 : answered / panel;

  /// Experts' median forecast minus ACAPS (positive = experts see it as more likely).
  double? get gap => expertLikelihood == null || acapsLikelihood == null ? null : expertLikelihood! - acapsLikelihood!;
}

class PanelStats {
  final String country;
  final String region;
  final List<Expert> experts;
  final int activeRisks;
  final double? responseRate;
  const PanelStats({required this.country, required this.region, required this.experts, required this.activeRisks, required this.responseRate});
}

class ForecastScore {
  final double mine;
  final double acaps;
  final int points;
  const ForecastScore(this.mine, this.acaps, this.points);
}

class AppState extends ChangeNotifier {
  List<Risk> risks = [];

  /// The risks as in the bundled Risk Radar export, before any sync or edits.
  List<Risk> _bundledRisks = const [];
  bool loaded = false;
  String? error;
  SharedPreferences? _prefs;

  // ---- database (persisted) ----
  List<Expert> experts = [];
  final Map<String, Response> _responses = {}; // "$expertId|$riskId"
  List<Comment> comments = [];
  final Map<String, Set<String>> _skipped = {}; // expertId -> riskIds

  // ---- display settings (persisted separately; Reset demo keeps them) ----
  // Each account (expert or moderator) keeps its own theme and text size.
  // Accounts that never changed them use the device default, which is also
  // what the sign-in screens use.
  final Map<String, ({AppTheme theme, double scale})> _display = {};
  static const _deviceKey = 'device';

  String get _displayKey => sessionModeratorId ?? sessionExpertId ?? _deviceKey;

  ({AppTheme theme, double scale}) get _currentDisplay =>
      _display[_displayKey] ?? _display[_deviceKey] ?? (theme: AppTheme.system, scale: 1.0);

  AppTheme get theme => _currentDisplay.theme;
  double get textScale => _currentDisplay.scale;

  /// Sets the theme for the current account without saving (tests, previews).
  set theme(AppTheme t) => _display[_displayKey] = (theme: t, scale: textScale);

  /// Risk to open straight away, e.g. from a tapped push notification (?risk=R1043).
  String? deepLinkRisk;

  /// Risks already auto-opened this launch ("expertId|riskId"), so the pop-up shows once.
  final Set<String> autoOpened = {};

  void setTheme(AppTheme t) {
    _display[_displayKey] = (theme: t, scale: textScale);
    _saveUi();
    notifyListeners();
  }

  void setTextScale(double v) {
    _display[_displayKey] = (theme: theme, scale: snapTextScale(v));
    _saveUi();
    notifyListeners();
  }

  static const _uiKey = 'ground_truth_ui_v1';

  void _saveUi() => _prefs?.setString(
        _uiKey,
        jsonEncode({
          'accounts': {
            for (final e in _display.entries) e.key: {'theme': e.value.theme.name, 'scale': e.value.scale},
          },
        }),
      );

  void _restoreUi() {
    ({AppTheme theme, double scale}) parse(Map m) => (
          theme: AppTheme.values.firstWhere((t) => t.name == m['theme'], orElse: () => AppTheme.system),
          scale: snapTextScale((m['scale'] as num?)?.toDouble() ?? 1.0),
        );
    try {
      final raw = _prefs?.getString(_uiKey);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _display.clear();
      if (m['accounts'] is Map) {
        for (final e in (m['accounts'] as Map).entries) {
          _display[e.key as String] = parse(e.value as Map);
        }
      } else {
        _display[_deviceKey] = parse(m); // older format: one setting for the whole device
      }
    } catch (_) {}
  }

  /// The risk to open when entering the app: a notification deep link first,
  /// otherwise a new or updated risk not yet shown this launch.
  Risk? takeAutoOpen() {
    final e = me;
    if (e == null) return null;
    if (deepLinkRisk != null) {
      final r = byId(deepLinkRisk!);
      deepLinkRisk = null;
      if (r != null) return r;
    }
    final r = pendingNotification;
    if (r == null || !autoOpened.add('${e.id}|${r.id}')) return null;
    return r;
  }

  // ---- session (persisted) ----
  /// Country suggested by the code that was entered (may be null).
  String? invitePanel;

  /// Demo mode: the local code this person entered; a single-use invite is
  /// used up when they register.
  String? pendingInviteCode;

  /// Real accounts: the code the server accepted, until the sign-up is done.
  CodeCheck? pendingCode;

  /// "Log in" pressed on the start screen (demo mode: the list of demo
  /// users). Not persisted.
  bool showLogin = false;

  /// A valid code was entered: go to the sign-up form.
  bool get canRegister {
    if (pendingCode != null) return true;
    final code = pendingInviteCode;
    if (code == null) return false;
    final i = inviteByCode(code);
    return (i != null && i.open) || referrerByCode(code) != null;
  }

  /// Demo mode: the expert whose referral code was entered, if it is one.
  Expert? get pendingReferrer => pendingInviteCode == null ? null : referrerByCode(pendingInviteCode!);

  /// The code entered is a colleague's referral code (not an ACAPS invite).
  bool get pendingIsReferral => pendingCode?.isReferral ?? pendingReferrer != null;

  /// The code entered makes an ACAPS moderator account.
  bool get pendingIsModerator => pendingCode?.isModerator ?? false;

  /// Demo mode: the list of demo users to log in as.
  bool get atSignIn => showLogin;

  void openLogin() {
    showLogin = true;
    notifyListeners();
  }

  /// Back to the start screen.
  void backToStart() {
    showLogin = false;
    invitePanel = null;
    pendingInviteCode = null;
    pendingCode = null;
    _changed();
  }

  String? sessionExpertId;
  String? sessionModeratorId;

  bool get sessionModerator => sessionModeratorId != null;

  /// The moderator signed in, if any.
  Moderator? get moderator => moderatorById(sessionModeratorId);

  Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/risk-radar-export.csv');
      final rows = parseCsv(raw);
      final header = rows.first.map((h) => h.trim()).toList();
      risks = rows.skip(1).where((r) => r.length > 1 && r[0].trim().isNotEmpty).map((r) {
        final m = <String, String>{};
        for (var i = 0; i < header.length; i++) {
          m[header[i]] = i < r.length ? r[i] : '';
        }
        return Risk.fromRow(m);
      }).toList();
      // Untouched copy of the export, so Reset demo can undo imports and
      // status syncs (see resetDemo).
      _bundledRisks = List.unmodifiable(risks);

      try {
        _prefs = await SharedPreferences.getInstance();
      } catch (_) {
        // Storage is optional: the app still works, it just won't remember.
      }
      _restoreUi();
      if (!_restore()) _seed();
      checkAccountSession();
    } catch (e) {
      error = '$e';
    }
    loaded = true;
    notifyListeners();
  }

  // =========================================================================
  // Session
  // =========================================================================

  Expert? get me => experts.where((e) => e.id == sessionExpertId).firstOrNull;

  Viewer get viewer => sessionModerator ? Viewer.moderator : (me == null ? Viewer.public : Viewer.expert(me!));

  bool get signedIn => sessionModerator || me != null;

  // ---- codes: one entry point for both modes ----

  /// "I have a code" on the start screen. With real accounts the server
  /// checks it; in demo mode the local codes. A valid code opens the sign-up
  /// form. Checking does not use a code up: only joining does.
  Future<InviteStatus> enterCode(String typed) async {
    if (!Auth.ready) return redeemInvite(typed);
    final r = await Auth.checkCode(typed);
    if (r.code != null) {
      pendingCode = r.code;
      invitePanel = r.code!.panel;
      pendingInviteCode = null;
      showLogin = false;
      _changed();
    }
    return r.status;
  }

  // ---- single-use invites (persisted; demo mode) ----
  List<Invite> invites = [];

  Invite? inviteByCode(String code) {
    final c = cleanCode(code);
    return invites.where((i) => i.code == c).firstOrNull;
  }

  /// Demo mode: checks a typed code against the local codes. A moderator's
  /// invite works once and is used up when the person registers; an expert's
  /// referral code works for any number of colleagues.
  InviteStatus redeemInvite(String typed) {
    final token = cleanCode(typed);
    if (referrerByCode(token) case final ref?) {
      invitePanel = null;
      pendingInviteCode = ref.referralCode;
      showLogin = false;
      _changed();
      return InviteStatus.ok;
    }
    final i = inviteByCode(token);
    final status = i == null
        ? InviteStatus.unknown
        : i.revoked
            ? InviteStatus.revoked
            : i.used
                ? InviteStatus.used
                : InviteStatus.ok;
    if (status == InviteStatus.ok) {
      invitePanel = i!.country;
      pendingInviteCode = i.code;
      showLogin = false;
      _changed();
    }
    return status;
  }

  // ---- referral codes ----
  /// Demo mode: who joined with whose referral code (persisted).
  List<Referral> referrals = [];

  /// Real accounts: when colleagues joined with my code (from the server).
  List<DateTime>? _accountReferrals;

  /// Real accounts, moderators: colleagues joined per expert account.
  Map<String, int> _remoteReferralCounts = {};

  Expert? referrerByCode(String code) {
    final c = cleanCode(code);
    if (c.isEmpty) return null;
    return experts.where((e) => e.referralCode == c).firstOrNull;
  }

  /// Colleagues who joined with [e]'s referral code.
  int referralsBy(Expert e) {
    if (e.id == sessionAccountId && _accountReferrals != null) return _accountReferrals!.length;
    return _remoteReferralCounts[e.id] ?? referrals.where((r) => r.referrerId == e.id).length;
  }

  /// Progress of each colleague who joined with [e]'s code, oldest first:
  /// only the number of risks answered and the stage, nothing else. For real
  /// accounts the server only says when they joined ([tracked] false):
  /// answers are not in the shared database yet.
  List<({int answered, ReferralStage stage, DateTime joinedAt, bool tracked})> referralProgress(Expert e) {
    if (e.id == sessionAccountId && _accountReferrals != null) {
      return [
        for (final d in _accountReferrals!) (answered: 0, stage: ReferralStage.joined, joinedAt: d, tracked: false),
      ];
    }
    final mine = referrals.where((r) => r.referrerId == e.id).toList()..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    return [
      for (final r in mine)
        () {
          final joined = r.referredId == null ? null : expertById(r.referredId!);
          final n = joined == null ? 0 : responsesOf(joined).length;
          return (
            answered: n,
            stage: n >= Points.referralAnswersInPilot
                ? ReferralStage.threeRisks
                : n >= 1
                    ? ReferralStage.firstRisk
                    : ReferralStage.joined,
            joinedAt: r.joinedAt,
            tracked: true,
          );
        }(),
    ];
  }

  /// Every demo expert gets a permanent referral code. Called when experts
  /// are created or loaded, never while a screen is being built. Real
  /// accounts get theirs from the server instead.
  /// Returns whether any code was new (then it must be saved: a referral
  /// code is permanent and must never change).
  bool _ensureReferralCodes([Random? rnd]) {
    final missing = experts.where((e) => e.referralCode.isEmpty && !isAccountId(e.id)).toList();
    for (final e in missing) {
      String code;
      do {
        code = newInviteCode(rnd, 'REF');
      } while (referrerByCode(code) != null);
      e.referralCode = code;
    }
    return missing.isNotEmpty;
  }

  /// Demo mode: a moderator creates a new single-use code for one person.
  /// No country: the new expert chooses theirs when creating their profile.
  Invite createInvite({String note = '', String? country}) {
    String code;
    do {
      code = newInviteCode();
    } while (inviteByCode(code) != null);
    final i = Invite(
      code: code,
      country: country,
      createdBy: sessionModeratorId ?? moderators.first.id,
      createdAt: DateTime.now(),
      note: note.trim(),
    );
    invites.add(i);
    _changed();
    return i;
  }

  /// "Who is it for", moderators only (demo mode).
  void setInviteNote(Invite i, String note) {
    i.note = note.trim();
    _changed();
  }

  void revokeInvite(Invite i) {
    i.revoked = true;
    _changed();
  }

  // ---- invite codes: one entry point for both modes (moderators) ----

  /// The signed-in moderator uses the server's codes (a real account).
  bool get _serverInvites => sessionModerator && sessionAccountId != null && Auth.ready;

  /// Real accounts: the server's invite codes, newest first (null until loaded).
  List<Invite>? remoteInvites;

  /// A new single-use code: on the server for a real moderator account,
  /// otherwise local. Throws when the server refuses; see [explain].
  Future<Invite> newInvite({String note = ''}) async {
    if (!_serverInvites) return createInvite(note: note);
    final code = await Auth.createInvite(note: note);
    await _reloadInvites();
    return remoteInvites?.where((i) => i.code == code).firstOrNull ??
        Invite(code: code, createdBy: sessionAccountId!, createdByName: moderator?.name, createdAt: DateTime.now(), note: note);
  }

  Future<void> saveInviteNote(Invite i, String note) async {
    if (!_serverInvites) return setInviteNote(i, note);
    i.note = note.trim();
    await Auth.setInviteNote(i.code, note);
  }

  Future<void> cancelInvite(Invite i) async {
    if (!_serverInvites) return revokeInvite(i);
    await Auth.revokeInvite(i.code);
    i.revoked = true;
    await _reloadInvites();
  }

  Future<void> _reloadInvites() async {
    remoteInvites = await Auth.listInvites();
    notifyListeners();
  }

  /// All invite codes, newest first.
  List<Invite> get invitesNewestFirst =>
      _serverInvites ? [...?remoteInvites] : ([...invites]..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  /// For the demo "Register" button: an open invite, Chad first.
  Invite? get demoInvite =>
      invites.where((i) => i.open && i.country == 'Chad').firstOrNull ?? invites.where((i) => i.open).firstOrNull;

  // ---- signing in ----

  void signInAs(Expert e) {
    sessionExpertId = e.id;
    sessionModeratorId = null;
    sessionAccountId = null;
    _changed();
  }

  void signInModerator([String id = 'm1']) {
    sessionExpertId = null;
    sessionModeratorId = moderatorById(id)?.id ?? moderators.first.id;
    sessionAccountId = null;
    _changed();
  }

  /// Supabase user id when signed in with a real account, null for demo users.
  String? sessionAccountId;

  /// Why the last refresh from the server failed (null when it worked).
  String? accountSyncError;

  /// After a real login or sign-up (see auth.dart). An expert gets a local
  /// record keyed by their Supabase user id, created from their profile row
  /// the first time; answers and points stay local. Then the referral code,
  /// referrals and (moderators) invite codes are loaded from the server.
  void signInAccount(AccountProfile p) {
    if (p.isModerator) {
      accountModerators[p.userId] = Moderator(id: p.userId, name: p.realName ?? 'ACAPS moderator');
      sessionExpertId = null;
      sessionModeratorId = p.userId;
    } else {
      if (expertById(p.userId) == null) {
        final home = p.homeCountry ?? invitePanel ?? 'Chad';
        experts.add(Expert(
          id: p.userId,
          joinedVia: p.joinedVia,
          realName: p.realName,
          pseudonym: p.pseudonym,
          level: p.level,
          homeCountry: home,
          interests: {...p.interests}..remove(home),
          onRating: p.onRating,
          notifications: p.notifications,
          hideFromOtherCountries: p.hideFromOtherCountries,
        ));
      }
      sessionExpertId = p.userId;
      sessionModeratorId = null;
    }
    sessionAccountId = p.userId;
    pendingCode = null;
    pendingInviteCode = null;
    invitePanel = null;
    showLogin = false;
    _accountReferrals = null;
    _remoteReferralCounts = {};
    remoteInvites = null;
    _changed();
    refreshAccount();
  }

  /// Loads what lives on the server for the signed-in account. Never throws:
  /// the reason is kept in [accountSyncError].
  Future<void> refreshAccount() async {
    final id = sessionAccountId;
    if (id == null || !Auth.ready) return;
    try {
      if (sessionModerator) {
        final invites = await Auth.listInvites();
        final counts = await Auth.referralCounts();
        if (sessionAccountId != id) return; // signed out meanwhile
        remoteInvites = invites;
        _remoteReferralCounts = counts;
      } else {
        final code = await Auth.myReferralCode();
        final joined = await Auth.myReferrals();
        if (sessionAccountId != id) return;
        final e = expertById(id);
        if (e != null && code != null) e.referralCode = code;
        _accountReferrals = joined;
      }
      accountSyncError = null;
    } catch (e) {
      if (sessionAccountId != id) return;
      accountSyncError = explain(e);
    }
    _changed();
  }

  /// At launch: drop a saved account session that Supabase no longer has
  /// (logged out, expired, or a build without the Supabase keys). With real
  /// accounts available, a leftover demo session is closed too: everyone
  /// logs in with a password then.
  void checkAccountSession() {
    if (sessionAccountId != null && sessionAccountId != Auth.currentUserId) {
      _clearSession();
    } else if (Auth.ready && sessionAccountId == null && signedIn) {
      _clearSession();
    }
  }

  void _clearSession() {
    sessionExpertId = null;
    sessionModeratorId = null;
    sessionAccountId = null;
    _accountReferrals = null;
    _remoteReferralCounts = {};
    remoteInvites = null;
    accountSyncError = null;
  }

  /// "Log out" / "Switch user". Demo mode: back to the list of demo users.
  /// Real accounts: ends the session and goes back to the start screen.
  void signOut() {
    final hadAccount = sessionAccountId != null;
    _clearSession();
    showLogin = !Auth.ready;
    _changed();
    if (hadAccount) Auth.signOut();
  }

  /// Demo mode: registers locally with the code entered on the start screen.
  Expert register({
    required Anonymity level,
    required String? realName,
    required String pseudonym,
    required String homeCountry,
    required Set<String> interests,
    required bool notifications,
    required bool onRating,
    bool hideFromOtherCountries = false,
  }) {
    // The code is the authorisation: no profile without a valid, unused
    // moderator invite or a colleague's referral code (with real accounts
    // the server checks this, see registerAccount).
    final invite = pendingInviteCode == null ? null : inviteByCode(pendingInviteCode!);
    final referrer = pendingReferrer;
    if ((invite == null || !invite.open) && referrer == null) {
      throw StateError('A new profile needs a valid invite or referral code.');
    }
    // A unique id, even for two registrations in the same instant.
    var id = 'u${DateTime.now().microsecondsSinceEpoch}';
    while (expertById(id) != null) {
      id = '${id}x';
    }
    final e = Expert(
      id: id,
      // The door check, for moderators: how this person got in.
      joinedVia: referrer != null && (invite == null || !invite.open) ? JoinedVia.expertReferral : JoinedVia.acapsInvite,
      realName: level.needsRealName ? realName?.trim() : null,
      pseudonym: pseudonym.trim(),
      level: level,
      homeCountry: homeCountry,
      interests: interests..remove(homeCountry),
      notifications: notifications,
      onRating: onRating,
      hideFromOtherCountries: hideFromOtherCountries,
    );
    experts.add(e);
    _ensureReferralCodes(); // the new member gets their own referral code
    if (invite != null && invite.open) {
      // A moderator's invite is now used up. It records only WHEN, never
      // which account, so a fully anonymous expert cannot be traced through it.
      invite.usedAt = DateTime.now();
    } else if (referrer != null) {
      // A colleague's referral code stays valid. The inviter earns
      // Points.referral on sign-up and can follow the new member's progress
      // (stage only; they were told when joining).
      referrals.add(Referral(referrer.id, DateTime.now(), e.id));
    }
    pendingInviteCode = null;
    signInAs(e);
    return e;
  }

  /// Real accounts: creates the expert account on the server with the code
  /// the server accepted, then signs in. Throws on failure; see [explain].
  Future<void> registerAccount({
    required String password,
    required Anonymity level,
    required String? realName,
    required String pseudonym,
    required String homeCountry,
    required Set<String> interests,
    required bool notifications,
    required bool onRating,
    bool hideFromOtherCountries = false,
  }) async {
    final code = pendingCode;
    if (code == null) throw StateError('Enter your invite or referral code first.');
    final p = await Auth.signUpExpert(
      code: code,
      pseudonym: pseudonym,
      password: password,
      level: level,
      realName: level.needsRealName ? realName : null,
      homeCountry: homeCountry,
      interests: interests,
      notifications: notifications,
      onRating: onRating,
      hideFromOtherCountries: hideFromOtherCountries,
    );
    signInAccount(p);
  }

  /// Real accounts: creates a moderator account with a moderator code.
  Future<void> registerModerator({required String realName, required String email, required String password}) async {
    final code = pendingCode;
    if (code == null || !code.isModerator) throw StateError('Enter a moderator code first.');
    signInAccount(await Auth.signUpModerator(code: code, realName: realName, email: email, password: password));
  }

  void updateMe(void Function(Expert e) f) {
    final e = me;
    if (e == null) return;
    f(e);
    e.interests.remove(e.homeCountry);
    _changed();
  }

  Future<void> resetDemo() async {
    await _prefs?.remove(_prefsKey);
    final hadAccount = sessionAccountId != null;
    invitePanel = null;
    pendingInviteCode = null;
    pendingCode = null;
    showLogin = false;
    _clearSession();
    if (hadAccount) Auth.signOut();
    _bannerDismissed.clear();
    autoOpened.clear(); // a reset demo shows the entry pop-up again
    // Back to the export exactly as shipped: drops imported / app-made risks
    // and every status synced from the ACAPS API.
    risks = [..._bundledRisks];
    _radarUpdates.clear();
    _seed();
    _statsCache.clear();
    notifyListeners();
  }

  // =========================================================================
  // Risks & panels
  // =========================================================================

  List<String> get countries {
    final s = <String>{};
    for (final r in risks) {
      s.addAll(riskCountries(r));
    }
    return s.toList()..sort();
  }

  static List<String> riskCountries(Risk r) =>
      r.country.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  Risk? byId(String id) => risks.where((r) => r.id == id).firstOrNull;

  Expert? expertById(String id) => experts.where((e) => e.id == id).firstOrNull;

  List<Expert> panelFor(String country) => experts.where((e) => e.inPanel(country)).toList();

  /// Everyone on a panel for any of the risk's countries.
  List<Expert> panelForRisk(Risk r) {
    final cs = riskCountries(r);
    return experts.where((e) => cs.any(e.inPanel)).toList();
  }

  bool relevantTo(Expert e, Risk r) => riskCountries(r).any(e.inPanel);

  /// Active risks in my countries, demo risk first, unanswered first.
  List<Risk> activeForMe() {
    final e = me;
    if (e == null) return [];
    int score(Risk r) =>
        (r.id == 'R1043' ? 1000 : 0) + (r.inCountry(e.homeCountry) ? 100 : 0) + (r.level == 'High' ? 10 : 0);
    return risks.where((r) => r.isActive && r.probabilityIdx != null && relevantTo(e, r)).toList()
      ..sort((a, b) => score(b).compareTo(score(a)));
  }

  /// Every closed risk, whenever it closed and whether or not I answered it:
  /// read-only, to see what happened. My countries come first. New answers
  /// are not accepted and earn no points; a forecast made while the risk was
  /// open is still shown with its score.
  List<Risk> archiveForMe() {
    final e = me;
    if (e == null) return [];
    final closed = risks.where((r) => r.isResolved).toList();
    return [...closed.where((r) => relevantTo(e, r)), ...closed.where((r) => !relevantTo(e, r))];
  }

  /// Experts who pressed "Not now" this launch: the banner stays hidden until
  /// the next launch (deliberately not persisted).
  final Set<String> _bannerDismissed = {};

  /// The "ACAPS updated a risk" banner: first unanswered, unskipped active risk.
  Risk? get pendingNotification {
    final e = me;
    if (e == null || !e.notifications || _bannerDismissed.contains(e.id)) return null;
    return activeForMe().where((r) => responseOf(e, r) == null && !isSkipped(r)).firstOrNull;
  }

  bool isSkipped(Risk r) {
    final e = me;
    return e != null && (_skipped[e.id]?.contains(r.id) ?? false);
  }

  /// "Not now": the risk stays in the list, marked skipped, and the banner is
  /// hidden for the rest of this session.
  void skip(Risk r) {
    final e = me;
    if (e == null) return;
    (_skipped[e.id] ??= {}).add(r.id);
    _bannerDismissed.add(e.id);
    _changed();
  }

  void undoSkip(Risk r) {
    final e = me;
    if (e == null) return;
    _skipped[e.id]?.remove(r.id);
    _bannerDismissed.remove(e.id);
    _changed();
  }

  // =========================================================================
  // Responses
  // =========================================================================

  Response? responseOf(Expert e, Risk r) => _responses['${e.id}|${r.id}'] ?? _simulated(e, r);

  List<Response> responsesOf(Expert e) {
    final out = <Response>[];
    for (final r in risks) {
      final resp = responseOf(e, r);
      if (resp != null) out.add(resp);
    }
    out.sort((a, b) => (b.editedAt ?? b.answeredAt).compareTo(a.editedAt ?? a.answeredAt));
    return out;
  }

  void submit(Risk r, Map<String, ItemAnswer> items, {required int forecast, Credit? credit}) {
    final e = me;
    // Closed risks are read-only: no new or changed forecasts.
    if (e == null || r.isResolved) return;
    final key = '${e.id}|${r.id}';
    final prev = _responses[key];
    final now = DateTime.now();
    final f = forecast.clamp(1, 5);
    _responses[key] = Response(
      expertId: e.id,
      riskId: r.id,
      items: Map.of(items),
      forecast: f,
      answeredAt: prev?.answeredAt ?? now,
      editedAt: prev == null ? null : now,
      credit: credit ?? prev?.credit,
      // A new check-in every time: earlier ones are kept, never overwritten.
      history: [...?prev?.history, CheckIn(f, now)],
    );
    // "What is ACAPS missing?" answers become comments for the group.
    for (final entry in items.entries) {
      final id = '${e.id}|${r.id}|${entry.key}';
      final text = entry.value.missing.trim();
      final existing = comments.where((c) => c.id == id).firstOrNull;
      if (text.isEmpty) {
        comments.removeWhere((c) => c.id == id);
      } else if (existing != null) {
        existing.text = text;
      } else {
        comments.add(Comment(id: id, riskId: r.id, itemId: entry.key, authorId: e.id, text: text));
      }
    }
    _skipped[e.id]?.remove(r.id);
    _changed();
  }

  /// Panel members (for this risk) who have answered.
  List<Expert> respondents(Risk r) => panelForRisk(r).where((e) => responseOf(e, r) != null).toList();

  List<ItemAnswer> answersFor(Risk r, String itemId) => [
        for (final e in panelForRisk(r))
          if (responseOf(e, r)?.items[itemId] case final a?) a,
      ];

  /// The panel's forecasts for the whole risk (1..5).
  List<int> forecastsFor(Risk r) => [
        for (final e in panelForRisk(r))
          if (responseOf(e, r)?.forecast case final f?) f,
      ];

  /// How far back the "then" of a trend looks: about one ACAPS update cycle.
  static const trendWindow = Duration(days: 30);

  /// The group view as it stood at [t]: each expert's latest check-in on or
  /// before that date.
  GroupView? groupAt(Risk r, DateTime t) => GroupView.of([
        for (final e in panelForRisk(r))
          if (responseOf(e, r)?.forecastAt(t) case final f?) f,
      ]);

  /// The panel's view now against [trendWindow] ago, and how many experts
  /// changed their forecast in between. Null when there is nothing to compare.
  ({GroupView then, GroupView now, DateTime since, int changed})? trendOf(Risk r) {
    if (!r.isActive) return null; // closed risks: no live picture to follow
    final since = DateTime.now().subtract(trendWindow);
    final then = groupAt(r, since), now = GroupView.of(forecastsFor(r));
    if (then == null || now == null) return null;
    var changed = 0;
    for (final e in panelForRisk(r)) {
      final resp = responseOf(e, r);
      final before = resp?.forecastAt(since);
      if (before != null && resp!.forecast != before) changed++;
    }
    return (then: then, now: now, since: since, changed: changed);
  }

  /// Simulated history for synthetic experts. Personas never have simulated
  /// answers on active risks, so whoever demos them can take the survey.
  Response? _simulated(Expert e, Risk r) {
    if (!e.simulated || !relevantTo(e, r)) return null;
    if (r.custom) return null; // a brand-new risk has no answers yet
    // 7 risks in the export have no status: neither open nor closed, so
    // nobody could answer them (and they would "wait" forever).
    if (!r.isActive && !r.isResolved) return null;
    if (e.persona && r.isActive) return null;
    if (r.id != 'R1043' && Random(stableHash('${e.id}|${r.id}')).nextDouble() > e.participation) return null;

    final base = r.acapsLikelihood ?? 3;

    // One forecast for the whole risk: close to ACAPS, and on closed risks
    // skilled experts lean towards what actually happened.
    final fr = Random(stableHash('${e.id}|${r.id}|forecast'));
    final story = _demoStories[r.id]?[e.id];
    var forecast = story?.now ?? base + const [-2, -1, -1, 0, 0, 0, 0, 1, 1, 2][fr.nextInt(10)];
    if (r.isResolved && fr.nextDouble() < e.skill * 0.8) forecast += r.materialised ? 1 : -1;
    forecast = forecast.clamp(1, 5);

    // Ground truthing per trigger: agreement follows how far the expert's
    // view of that trigger sits from ACAPS.
    final items = <String, ItemAnswer>{};
    for (final it in r.surveyItems) {
      final rnd = Random(stableHash('${e.id}|${r.id}|${it.id}'));
      var view = forecast + const [-1, 0, 0, 0, 1][rnd.nextInt(5)];
      if (it.completion != null && it.completion! <= 15) view -= 1;
      final d = (view - base).abs();
      final agree = d == 0 ? Agreement.yes : (d == 1 ? Agreement.partly : Agreement.no);
      final s = ((r.impact ?? 3) + const [-1, 0, 0, 0, 1][rnd.nextInt(5)]).clamp(1, 5);
      items[it.id] = ItemAnswer(agree: agree, severity: s);
    }
    final today = DateTime(2026, 11, 6);
    final days = r.isResolved ? 190 + stableHash(r.id) % 60 : 1 + stableHash('${e.id}${r.id}') % 3;
    final latest = today.subtract(Duration(days: days));

    // Active risks: an earlier check-in about a month before, at the previous
    // ACAPS update. Views mostly hold or move up a step as crises develop, so
    // the demo shows a live picture, not a single snapshot.
    var history = [CheckIn(forecast, latest)];
    if (r.isActive) {
      final hr = Random(stableHash('${e.id}|${r.id}|history'));
      final earlier = story?.then ?? (forecast + const [0, 0, 0, 0, -1, -1, -1, 1][hr.nextInt(8)]).clamp(1, 5);
      history = [CheckIn(earlier, today.subtract(Duration(days: 31 + hr.nextInt(6)))), ...history];
    }
    return Response(
      expertId: e.id,
      riskId: r.id,
      items: items,
      forecast: forecast,
      answeredAt: history.first.at,
      editedAt: history.length > 1 ? latest : null,
      simulated: true,
      history: history,
    );
  }

  /// Demo storylines (synthetic, fixed so the demo tells a clear story):
  /// each expert's forecast a month ago and now, on the 1-5 ACAPS scale.
  static const _demoStories = <String, Map<String, ({int then, int now})>>{
    // R1043: the panel moved from Medium to High after ACAPS's 30 Sep 2026
    // update ("from a snapshot to a live picture").
    'R1043': {
      'e4': (then: 3, now: 4),
      'e5': (then: 3, now: 4),
      'e6': (then: 4, now: 4),
      'e7': (then: 4, now: 5),
      'e8': (then: 3, now: 3),
    },
    // R1049: the panel is split: no clear group view, so ACAPS knows this
    // part of the analysis needs attention.
    'R1049': {
      'e4': (then: 2, now: 2),
      'e6': (then: 2, now: 1),
      'e7': (then: 4, now: 5),
      'e9': (then: 3, now: 4),
      'e11': (then: 2, now: 2),
    },
  };

  // =========================================================================
  // Scoring & rating
  // =========================================================================

  /// Only the one forecast per risk is scored (Brier), against whether the
  /// risk materialised. ACAPS's own rating is scored the same way.
  ForecastScore? scoreOf(Response resp) {
    final r = byId(resp.riskId);
    if (r == null || !r.isResolved || r.acapsLikelihood == null || resp.forecast == null) return null;
    final mine = brier(resp.forecast!, r.materialised);
    final acaps = brier(r.acapsLikelihood!, r.materialised);
    return ForecastScore(mine, acaps, Points.forecast(mine));
  }

  List<Comment> commentsBy(Expert e) => comments.where((c) => c.authorId == e.id).toList();

  final _statsCache = <String, ({int points, int resolved, double? brier})>{};

  ({int points, int resolved, double? brier}) statsOf(Expert e) => _statsCache[e.id] ??= _computeStats(e);

  ({int points, int resolved, double? brier}) _computeStats(Expert e) {
    var points = 0, n = 0;
    var sum = 0.0;
    for (final resp in responsesOf(e)) {
      final s = scoreOf(resp);
      if (s == null) continue;
      points += s.points;
      sum += s.mine;
      n++;
    }
    for (final c in commentsBy(e)) {
      if (c.useful) points += Points.usefulComment;
      if (c.usedInRiskId != null) points += Points.usedComment;
    }
    points += Points.referral * referralsBy(e);
    return (points: points, resolved: n, brier: n == 0 ? null : sum / n);
  }

  Set<Award> badgesOf(Expert e) {
    final st = statsOf(e);
    final cs = commentsBy(e);
    final top = _brierRanked().take(3).map((x) => x.id).toSet();
    return {
      if (top.contains(e.id) && st.resolved >= minResolvedForBrier) Award.superEstimator,
      if (cs.any((c) => c.useful)) Award.usefulInsight,
      if (cs.any((c) => c.usedInRiskId != null)) Award.cited,
      if (responsesOf(e).length >= 5) Award.regular,
      if (referralsBy(e) >= referralMasterMin) Award.referralMaster,
    };
  }

  /// Place by accuracy among experts in the rating with enough matured
  /// forecasts (the Super estimator ranking); null if not ranked yet.
  ({int rank, int of})? accuracyRank(Expert e) {
    final xs = _brierRanked();
    final i = xs.indexWhere((x) => x.id == e.id);
    return i < 0 ? null : (rank: i + 1, of: xs.length);
  }

  /// What an expert does in the app, as a trust signal for moderators.
  Activity expertActivity(Expert e) {
    if (responsesOf(e).length < activeMinAnswers) return Activity.newcomer;
    final st = statsOf(e);
    final usefulComment = commentsBy(e).any((c) => c.useful || c.usedInRiskId != null);
    final accurate = st.brier != null && st.resolved >= minResolvedForBrier && accuracyPct(st.brier!) >= establishedMinAccuracy;
    return usefulComment || accurate ? Activity.established : Activity.active;
  }

  List<Expert> _brierRanked() {
    final xs = experts.where((e) => e.onRating && statsOf(e).resolved >= minResolvedForBrier).toList();
    xs.sort((a, b) => statsOf(a).brier!.compareTo(statsOf(b).brier!));
    return xs;
  }

  /// Opt-in rating, ranked by points, with ACAPS's own Brier score as a baseline.
  /// [where] filters experts; [riskWhere] picks the resolved risks the ACAPS
  /// benchmark is scored on (e.g. only risks in the selected country).
  List<RatingRow> rating({bool Function(Expert e)? where, bool Function(Risk r)? riskWhere}) {
    final rows = [
      for (final e in experts.where((e) => e.onRating && (where?.call(e) ?? true)))
        if (statsOf(e) case final s when s.points > 0 || e.id == me?.id)
          RatingRow(expert: e, points: s.points, resolved: s.resolved, brier: s.brier, badges: badgesOf(e)),
    ]..sort((a, b) => b.points.compareTo(a.points));
    final resolved =
        risks.where((r) => r.isResolved && r.acapsLikelihood != null && (riskWhere?.call(r) ?? true)).toList();
    final acaps = resolved.isEmpty
        ? null
        : resolved.fold(0.0, (s, r) => s + brier(r.acapsLikelihood!, r.materialised)) / resolved.length;
    return [...rows, RatingRow(points: 0, resolved: resolved.length, brier: acaps)];
  }

  // =========================================================================
  // Comments
  // =========================================================================

  List<Comment> commentsOn(Risk r) => comments.where((c) => c.riskId == r.id).toList();

  void react(Comment c, bool agree) {
    final e = me;
    if (e == null || c.authorId == e.id) return;
    final on = agree ? c.agreeIds : c.disagreeIds;
    final off = agree ? c.disagreeIds : c.agreeIds;
    off.remove(e.id);
    if (!on.remove(e.id)) on.add(e.id);
    _changed();
  }

  List<Expert> expertsByIds(Iterable<String> ids) => ids.map(expertById).whereType<Expert>().toList();

  // ---- moderator ----

  void toggleUseful(Comment c) {
    c.useful = !c.useful;
    c.usefulBy = c.useful ? sessionModeratorId : null;
    _markReviewed(c);
    _changed();
  }

  void setUsedIn(Comment c, String? riskId) {
    c.usedInRiskId = riskId;
    c.usedBy = riskId == null ? null : sessionModeratorId;
    _markReviewed(c);
    _changed();
  }

  void setReviewed(Comment c, bool v) {
    c.reviewed = v;
    c.reviewedBy = v ? sessionModeratorId : null;
    _changed();
  }

  void _markReviewed(Comment c) {
    if (!c.reviewed) c.reviewedBy = sessionModeratorId;
    c.reviewed = true;
  }

  /// What one moderator has done, for their profile.
  ({int reviewed, int useful, int used}) activityOf(Moderator m) => (
        reviewed: comments.where((c) => c.reviewedBy == m.id).length,
        useful: comments.where((c) => c.usefulBy == m.id).length,
        used: comments.where((c) => c.usedBy == m.id).length,
      );

  /// New comments no moderator has handled yet. This is the only number on
  /// the moderator's Inbox badge.
  int get commentsToReview => comments.where((c) => c.needsReview).length;

  /// Moderator view of one risk: response rate, comments, and how far the
  /// experts' forecast sits from the ACAPS probability.
  RiskModStats modStats(Risk r) {
    final panel = panelForRisk(r);
    final answered = respondents(r);
    final all = [for (final it in r.surveyItems) ...answersFor(r, it.id)];
    final cs = commentsOn(r);
    // Group forecast = median (Delphi-style; one outlier cannot drag it).
    final group = GroupView.of(forecastsFor(r));
    final mean = group?.median;
    final trend = trendOf(r);
    final disagree = all.isEmpty
        ? 0.0
        : all.fold(0.0, (s, a) => s + (a.agree == Agreement.no ? 1 : (a.agree == Agreement.partly ? 0.5 : 0))) / all.length;
    return RiskModStats(
      panel: panel.length,
      answered: answered.length,
      comments: cs.length,
      toReview: cs.where((c) => c.needsReview).length,
      expertLikelihood: mean,
      acapsLikelihood: r.acapsLikelihood,
      disagreement: disagree,
      group: group,
      moved: trend == null ? 0 : trend.now.median - trend.then.median,
      changed: trend?.changed ?? 0,
    );
  }

  /// Panel health for one country.
  PanelStats panelStats(String country) {
    final experts = panelFor(country);
    final active = risks.where((r) => r.isActive && riskCountries(r).contains(country)).toList();
    // Share of this country's own panel that answered, averaged over its active risks.
    var rate = 0.0;
    for (final r in active) {
      rate += experts.where((e) => responseOf(e, r) != null).length / (experts.isEmpty ? 1 : experts.length);
    }
    return PanelStats(
      country: country,
      region: regionOf(country),
      experts: experts,
      activeRisks: active.length,
      responseRate: active.isEmpty || experts.isEmpty ? null : rate / active.length,
    );
  }

  /// Countries with active risks whose panel is too small to stay anonymous.
  List<({String country, int n, int active})> get thinPanels {
    final out = <({String country, int n, int active})>[];
    for (final c in countries) {
      final active = risks.where((r) => r.isActive && riskCountries(r).contains(c)).length;
      if (active == 0) continue;
      final n = panelFor(c).length;
      if (n < minPanel) out.add((country: c, n: n, active: active));
    }
    out.sort((a, b) => b.n != a.n ? b.n.compareTo(a.n) : b.active.compareTo(a.active));
    return out;
  }

  // =========================================================================
  // Risks created by the moderator
  // =========================================================================

  /// Next free id after the highest "R<number>" in use.
  String nextRiskId() {
    final n = risks.map((r) => int.tryParse(r.id.replaceAll(RegExp('[^0-9]'), '')) ?? 0).fold(0, max);
    return 'R${n + 1}';
  }

  /// Adds a new risk, or replaces the one with the same id.
  void saveRisk(Risk r) {
    final i = risks.indexWhere((x) => x.id == r.id);
    if (i >= 0) {
      risks[i] = r;
    } else {
      risks.add(r);
    }
    _changed();
  }

  // =========================================================================
  // Status sync with the ACAPS Risk Radar API
  // =========================================================================
  //
  // The app has two kinds of risks, and they are saved differently:
  //   * risks from the bundled CSV export: re-read from the CSV at every
  //     start, never saved as a whole (custom == false);
  //   * risks made in the app or imported from the API: saved in full on the
  //     device under 'custom_risks' (custom == true).
  // A status change on a custom risk is simply saved with it. For a CSV risk
  // we save only the change ("R1037 is now Materialised") in _radarUpdates and
  // replay it on top of the CSV at every start (see _restore). That keeps the
  // CSV the single source for everything else, and Reset demo can undo the
  // sync by forgetting the changes.
  //
  // Why status matters so much: it decides where a risk lives.
  //   Active                         -> experts can answer (survey, forecast)
  //   Materialised / Not materialised -> Archive: read-only, and the forecasts
  //                                     experts gave are scored (Brier score)
  //                                     against what really happened.

  /// Status updates from the API for risks of the bundled export, by id:
  /// {'status': ..., 'materialisation': ...}. Saved on the device and applied
  /// on top of the export at every start; Reset demo clears them.
  final Map<String, Map<String, String>> _radarUpdates = {};

  /// Risks in the app whose status differs from the Risk Radar. Risks the API
  /// does not list are left alone.
  ///
  /// Compared case- and space-insensitively ("Active " == "active"), because
  /// the export and the API are not always typed the same way. Pure function:
  /// changes nothing, so the screen can call it on every rebuild.
  List<StatusChange> statusChanges(Iterable<Risk> fromApi) => [
        for (final a in fromApi)
          // Only risks the app has (`case final r?` = "if not null, call it r").
          if (byId(a.id) case final r?)
            if (a.status.trim().toLowerCase() != r.status.trim().toLowerCase())
              StatusChange(r, a.status.trim(), a.materialisation),
      ];

  /// Applies the status changes. Answers given while a risk was active are
  /// kept: once it closes they are the forecasts that get scored.
  void applyStatusChanges(Iterable<StatusChange> changes) {
    for (final c in changes) {
      final i = risks.indexWhere((x) => x.id == c.risk.id);
      if (i < 0) continue; // risk deleted meanwhile: nothing to update
      // Keep our "what happened" text if the API has none.
      final mat = c.materialisation.isEmpty ? null : c.materialisation;
      risks[i] = risks[i].withStatus(c.to, materialisation: mat);
      // CSV risks: remember the change so it survives a restart (see above).
      if (!risks[i].custom) {
        _radarUpdates[c.risk.id] = {'status': c.to, if (mat != null) 'materialisation': mat};
      }
    }
    _changed(); // clears cached stats (scores change!), redraws, saves
  }

  /// Replays the saved status changes on top of the freshly loaded CSV.
  /// Called from _restore, after the experts' answers are loaded.
  void _applyRadarUpdates() {
    for (var i = 0; i < risks.length; i++) {
      final u = _radarUpdates[risks[i].id];
      if (u == null || risks[i].custom) continue;
      risks[i] = risks[i].withStatus(u['status']!, materialisation: u['materialisation']);
    }
  }

  /// Only risks created in the app can be deleted; Risk Radar risks stay.
  void deleteRisk(Risk r) {
    if (!r.custom) return;
    risks.removeWhere((x) => x.id == r.id);
    comments.removeWhere((c) => c.riskId == r.id);
    _responses.removeWhere((_, v) => v.riskId == r.id);
    for (final s in _skipped.values) {
      s.remove(r.id);
    }
    _changed();
  }

  // =========================================================================
  // Public view: aggregates only, safe to publish
  // =========================================================================

  /// Contributors who agreed to be named for this risk (their choice in the
  /// survey, or their profile default), sorted by name.
  List<({String name, Credit as})> creditsFor(Risk r) => [
        for (final e in respondents(r))
          if (publicCredit(e, responseOf(e, r)?.credit) case final c?) c,
      ]..sort((a, b) => a.name.compareTo(b.name));

  /// Probability as spelled in the Risk Radar export / API.
  static const _radarProbability = ['Very Low', 'Low', 'Medium', 'High', 'Very High'];

  /// Expert input for one risk, ready for ACAPS's own systems: the risk's
  /// fields with the same names as the Risk Radar export / API (so ACAPS can
  /// join it to its own data), plus an `expert_input` block. Aggregates only:
  /// no comments, no respondent countries, no names next to answers; no
  /// results at all below [minPanel] respondents. With [credits], experts
  /// who chose to be named are listed as contributors.
  Map<String, dynamic> publicView(Risk r, {bool credits = false}) {
    final n = respondents(r).length;
    List<int> dist(Iterable<int> xs) {
      final c = List.filled(5, 0);
      for (final x in xs) {
        c[x - 1]++;
      }
      return c;
    }

    // Delphi-style group view: median and the middle half of answers.
    Map<String, dynamic> group(List<int> xs, String Function(GroupView g) label) {
      final g = GroupView.of(xs);
      return {
        'distribution_1_5': dist(xs),
        'median_1_5': g?.median,
        'median_label': g == null ? null : label(g),
        'middle_half_1_5': g == null ? null : [g.low, g.high],
      };
    }

    final published = n >= minPanel;
    return {
      // ACAPS's own fields, named exactly as in the Risk Radar export / API.
      'Risk ID': r.id,
      'Risk Title': r.title,
      'Risk Type': r.type,
      'ISO': r.iso,
      'Country': r.country,
      'Probability': r.probabilityIdx == null ? null : _radarProbability[r.probabilityIdx!],
      'Impact': r.impact,
      'Risk Level': r.level.isEmpty ? null : r.level,
      'Risk trend': r.trend.isEmpty ? null : r.trend,
      'Expected exposure': r.exposure.isEmpty ? null : r.exposure,
      'Expected priority needs': r.needs.isEmpty ? null : r.needs,
      'Status': r.status,
      // What this tool adds.
      'expert_input': {
        'panel_size': panelForRisk(r).length,
        'respondents': n,
        'published': published,
        if (published) ...() {
          final f = forecastsFor(r);
          final g = GroupView.of(f);
          final tr = trendOf(r);
          return {
            // The one scored question, on the ACAPS probability scale.
            'forecast': {
              'question': 'Will this risk materialise within 6 months?',
              'answers': f.length,
              ...group(f, (g) => g.probability),
              // Experts disagree among themselves: no trustworthy group answer.
              'opinions_split': g?.split ?? false,
              // The live picture: the group view now against one update cycle ago.
              if (tr != null)
                'trend': {
                  'since': tr.since.toIso8601String().substring(0, 10),
                  'then_median_1_5': tr.then.median,
                  'now_median_1_5': tr.now.median,
                  'then_label': tr.then.short,
                  'now_label': tr.now.short,
                  'experts_changed': tr.changed,
                },
            },
            // Ground truthing per trigger (not scored). Trigger fields use the
            // names of the export's structured Triggers field.
            'triggers': [
              for (final it in r.surveyItems)
                () {
                  final a = answersFor(r, it.id);
                  final s = [for (final x in a) x.severity];
                  return {
                    'Trigger ID': r.triggers.isEmpty ? null : it.id,
                    'Title': it.title,
                    'answers': a.length,
                    'agreement_with_acaps': {for (final g in Agreement.values) g.name: a.where((x) => x.agree == g).length},
                    'severity': group(s, (g) => g.severity),
                  };
                }(),
            ],
          };
        }(),
        if (published && credits) ...() {
          final cs = creditsFor(r);
          return {
            'contributors': [
              for (final c in cs) {'name': c.name, 'credited_as': c.as == Credit.realName ? 'real_name' : 'pseudonym'},
            ],
            'anonymous_contributors': n - cs.length,
          };
        }(),
      },
    };
  }

  /// Expert input for ACAPS's systems: one risk, or every risk with enough
  /// respondents. Risk fields use the Risk Radar / API names, so ACAPS can
  /// join it to its own data instead of copying files around.
  String publicViewJson(Iterable<Risk> rs, {bool credits = false}) => const JsonEncoder.withIndent('  ').convert({
        'schema': 'acaps-ground-truth/expert-input/v3',
        'generated_at': DateTime.now().toUtc().toIso8601String(),
        'field_names': 'Risk fields as in the ACAPS Risk Radar export / API (data/risk-radar-export.csv); '
            'expert_input is added by Ground Truth.',
        'min_respondents': minPanel,
        'probability_scale': {
          for (var i = 0; i < 5; i++) '${i + 1}': {'label': _radarProbability[i], 'range': probabilityRanges[i]},
        },
        'risks': [for (final r in rs) publicView(r, credits: credits)],
      });

  /// Risks with enough respondents for their expert input to be shared.
  List<Risk> get publishableRisks =>
      risks.where((r) => (r.isActive || r.isResolved) && respondents(r).length >= minPanel).toList();

  /// Raw stored expert records, exactly as persisted (for the demo).
  String get rawExpertTable =>
      const JsonEncoder.withIndent('  ').convert([for (final e in experts) e.toJson()]);

  // =========================================================================
  // Seed data (synthetic: no real experts)
  // =========================================================================

  /// Demo single-use invites (synthetic). Open ones work once each with the
  /// demo "Register" button; the used one shows what happens after.
  void _seedInvites() {
    final r = Random(42);
    Invite make(String country, int daysAgo, String note, {bool used = false}) => Invite(
          code: newInviteCode(r),
          country: country,
          createdBy: 'm1',
          createdAt: DateTime(2026, 11, 6).subtract(Duration(days: daysAgo)),
          note: note,
          usedAt: used ? DateTime(2026, 11, 6).subtract(Duration(days: daysAgo - 2)) : null,
        );
    invites = [
      make('Chad', 2, 'Protection officer, Abéché'),
      make('Chad', 2, "Researcher, N'Djamena"),
      make('Chad', 9, 'Local NGO lead, Adré', used: true),
      make('Sudan', 4, 'Early warning analyst, El Fasher'),
    ];
  }

  void _seed() {
    experts = [
      // Personas you can log in as.
      Expert(id: 'p1', realName: 'Amina Haroun', pseudonym: 'Harmattan-17', level: Anonymity.knownToAcaps,
          homeCountry: 'Chad', interests: {'Sudan', 'Cameroon'}, simulated: true, persona: true,
          participation: 0.85, skill: 0.8),
      Expert(id: 'p2', realName: 'Jean-Paul Ndoumbé', pseudonym: 'Kestrel-42', level: Anonymity.pseudonymous,
          homeCountry: 'Cameroon', interests: {'Chad', 'Central African Republic'}, simulated: true, persona: true,
          participation: 0.9, skill: 0.5),
      Expert(id: 'p3', realName: null, pseudonym: 'Sirocco-08', level: Anonymity.anonymous,
          homeCountry: 'Chad', interests: {'Sudan', 'Mali'}, simulated: true, persona: true,
          onRating: false, participation: 0.8, skill: 0.35),
      // Chad panel.
      Expert(id: 'e4', realName: 'Fatimé Abakar', pseudonym: 'Baobab-23', level: Anonymity.knownToAcaps,
          homeCountry: 'Chad', interests: {'Sudan'}, simulated: true, participation: 0.9, skill: 0.9),
      Expert(id: 'e5', realName: 'Moussa Idriss', pseudonym: 'Lantern-61', level: Anonymity.pseudonymous,
          homeCountry: 'Chad', simulated: true, participation: 0.8, skill: 0.4),
      Expert(id: 'e6', realName: null, pseudonym: 'Delta-30', level: Anonymity.anonymous,
          homeCountry: 'Sudan', interests: {'Chad'}, simulated: true, participation: 0.75, skill: 0.6),
      Expert(id: 'e7', realName: 'Halima Osman', pseudonym: 'Nomad-55', level: Anonymity.pseudonymous,
          homeCountry: 'Sudan', interests: {'Chad', 'South Sudan'}, simulated: true, participation: 0.85, skill: 0.7),
      Expert(id: 'e8', realName: 'Mahamat Saleh', pseudonym: 'Meridian-12', level: Anonymity.knownToAcaps,
          homeCountry: 'Chad', interests: {'Niger'}, simulated: true, onRating: false, participation: 0.7, skill: 0.2),
      // Other panels.
      Expert(id: 'e9', realName: 'Omar Bashir', pseudonym: 'Atlas-77', level: Anonymity.pseudonymous,
          homeCountry: 'Sudan', interests: {'South Sudan'}, simulated: true, participation: 0.8, skill: 0.55),
      Expert(id: 'e10', realName: null, pseudonym: 'Monsoon-04', level: Anonymity.anonymous,
          homeCountry: 'South Sudan', simulated: true, participation: 0.7, skill: 0.45,
          joinedVia: JoinedVia.expertReferral),
      Expert(id: 'e11', realName: 'Wanjiru Kamau', pseudonym: 'Compass-19', level: Anonymity.knownToAcaps,
          homeCountry: 'Kenya', interests: {'Sudan', 'Ethiopia'}, simulated: true, participation: 0.9, skill: 0.75),
      Expert(id: 'e12', realName: 'Aïssata Traoré', pseudonym: 'Cedar-66', level: Anonymity.pseudonymous,
          homeCountry: 'Mali', interests: {'Niger'}, simulated: true, participation: 0.8, skill: 0.6,
          joinedVia: JoinedVia.expertReferral),
      // Joined on 4 Nov through Harmattan-17's referral link; no answers yet.
      Expert(id: 'e13', realName: null, pseudonym: 'Rift-07', level: Anonymity.anonymous,
          homeCountry: 'Kenya', simulated: true, participation: 0, skill: 0.5,
          joinedVia: JoinedVia.expertReferral),
    ];
    _responses.clear();
    _skipped.clear();
    _seedInvites();
    _ensureReferralCodes(Random(7));
    // Demo: three colleagues joined through Amina's (Harmattan-17) link, so
    // she is a Referral Master: two have answered many risks, one has only
    // just joined.
    referrals = [
      Referral('p1', DateTime(2026, 10, 20), 'e12'),
      Referral('p1', DateTime(2026, 10, 28), 'e10'),
      Referral('p1', DateTime(2026, 11, 4), 'e13'),
    ];
    final t1 = 'R1043 - T0618', t2 = 'R1043 - T0619', t3 = 'R1043 - T0620';
    comments = [
      Comment(id: 's1', riskId: 'R1043', itemId: t1, authorId: 'e6',
          text: 'Smuggling routes are shifting north. Watch Bahaï and Tiné, not only Adré.',
          agreeIds: {'e4', 'e5', 'e8'}),
      Comment(id: 's2', riskId: 'R1043', itemId: t1, authorId: 'e4',
          text: 'The rainy season (Jul-Sep) usually slows cross-border movement. Expect a dip before escalation picks up again.',
          agreeIds: {'e6', 'e7'}, disagreeIds: {'e5', 'e8'}),
      Comment(id: 's3', riskId: 'R1043', itemId: t2, authorId: 'e7',
          text: 'Threats against Amdjarass are mostly rhetoric so far. Attacks on fuel convoys on the Abéché road are the more likely strike.',
          agreeIds: {'e4', 'e5', 'e6', 'e8'}, useful: true, usefulBy: 'm2', reviewed: true, reviewedBy: 'm2'),
      Comment(id: 's4', riskId: 'R1043', itemId: t3, authorId: 'e5',
          text: 'Recruitment in the Ouaddaï camps is an earlier signal of proxy mobilisation than armed incursions.',
          agreeIds: {'e4', 'e6', 'e7'}, disagreeIds: {'e8'}, usedInRiskId: 'R1048', usedBy: 'm1', reviewed: true, reviewedBy: 'm1'),
      // A few more, so the moderator filters have something to show.
      Comment(id: 's6', riskId: 'R1048', itemId: byId('R1048')?.surveyItems.first.id ?? 'risk', authorId: 'e9',
          text: 'RSF supply lines into Blue Nile run through Ethiopian border markets. Watch Kurmuk.',
          agreeIds: {'e7', 'e11'}, disagreeIds: {'e4'}),
      Comment(id: 's7', riskId: 'R1048', itemId: byId('R1048')?.surveyItems.last.id ?? 'risk', authorId: 'e11',
          text: 'Displacement figures here are probably undercounted: many people move to Ethiopia and are not registered.',
          agreeIds: {'e9', 'e6', 'e7', 'p1'}),
      Comment(id: 's8', riskId: 'R1037', itemId: byId('R1037')?.surveyItems.first.id ?? 'risk', authorId: 'e10',
          text: 'Flooding in Jonglei will cut road access before the fighting does.',
          agreeIds: {'e9'}, disagreeIds: {'e7'}),
      Comment(id: 's9', riskId: 'R1043', itemId: 'R1043 - T0620', authorId: 'e8',
          text: 'I see little sign of proxy mobilisation yet; this trigger looks overrated.',
          agreeIds: {}, disagreeIds: {'e4', 'e5', 'e6'}, reviewed: true, reviewedBy: 'm3'),
      // Persona history: shows moderator feedback under the My forecasts tab.
      Comment(id: 's5', riskId: 'R0002', itemId: byId('R0002')?.surveyItems.first.id ?? 'risk', authorId: 'p1',
          text: 'Fighting is pushing traders off the El Geneina - Adre route; watch fuel prices in Adre market.',
          agreeIds: {'e4', 'e6', 'e7', 'e9'}, disagreeIds: {'e11'}, useful: true, usefulBy: 'm1', usedInRiskId: 'R1043', usedBy: 'm1',
          reviewed: true, reviewedBy: 'm1'),
    ];
  }

  // =========================================================================
  // Persistence
  // =========================================================================

  static const _prefsKey = 'ground_truth_db_v4';

  void _changed() {
    _statsCache.clear();
    notifyListeners();
    _save();
  }

  void _save() {
    _prefs?.setString(
      _prefsKey,
      jsonEncode({
        'experts': [for (final e in experts) e.toJson()],
        'responses': [for (final r in _responses.values) r.toJson()],
        'comments': [for (final c in comments) c.toJson()],
        'custom_risks': [for (final r in risks.where((r) => r.custom)) r.toJson()],
        'radar_updates': _radarUpdates, // statuses synced from the ACAPS API (CSV risks only)
        'skipped': {for (final e in _skipped.entries) e.key: e.value.toList()},
        'invite': invitePanel,
        'invite_code': pendingInviteCode,
        'invites': [for (final i in invites) i.toJson()],
        'referrals': [for (final r in referrals) r.toJson()],
        'session': sessionExpertId,
        'moderator': sessionModeratorId,
        'account': sessionAccountId,
        if (accountModerators[sessionModeratorId] case final m?) 'account_moderator_name': m.name,
      }),
    );
  }

  bool _restore() {
    try {
      final raw = _prefs?.getString(_prefsKey);
      if (raw == null) return false;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      experts = [for (final e in m['experts'] as List) Expert.fromJson((e as Map).cast<String, dynamic>())];
      _responses.clear();
      for (final r in m['responses'] as List) {
        final resp = Response.fromJson((r as Map).cast<String, dynamic>());
        // Old "practice" answers on closed risks: no longer allowed, never scored.
        if (byId(resp.riskId)?.isResolved ?? false) continue;
        _responses['${resp.expertId}|${resp.riskId}'] = resp;
      }
      comments = [for (final c in m['comments'] as List) Comment.fromJson((c as Map).cast<String, dynamic>())];
      _skipped
        ..clear()
        ..addAll({
          for (final e in ((m['skipped'] as Map?) ?? const {}).entries)
            e.key as String: {...(e.value as List).cast<String>()},
        });
      invitePanel = m['invite'] as String?;
      pendingInviteCode = m['invite_code'] as String?;
      if (m['invites'] is List) {
        invites = [for (final i in m['invites'] as List) Invite.fromJson((i as Map).cast<String, dynamic>())];
      } else {
        _seedInvites(); // saved before single-use invites existed
      }
      referrals = [for (final r in (m['referrals'] as List? ?? const [])) Referral.fromJson((r as Map).cast<String, dynamic>())];
      if (_ensureReferralCodes()) _save(); // saved before referral codes existed: fix them now
      sessionExpertId = m['session'] as String?;
      sessionAccountId = m['account'] as String?;
      final mod = m['moderator'];
      // A real moderator account: its name, so the session can be restored.
      if (sessionAccountId != null && mod == sessionAccountId && m['account_moderator_name'] is String) {
        accountModerators[sessionAccountId!] = Moderator(id: sessionAccountId!, name: m['account_moderator_name'] as String);
      }
      sessionModeratorId = mod == true ? moderators.first.id : moderatorById(mod is String ? mod : null)?.id;
      risks
        ..removeWhere((r) => r.custom)
        ..addAll([for (final r in (m['custom_risks'] as List? ?? const [])) Risk.fromJson((r as Map).cast<String, dynamic>())]);
      // After the responses: answers given while a risk was still active stay.
      // (The loop above drops answers on risks that are closed *in the CSV*;
      // a risk closed later by a sync must keep its answers, because those are
      // exactly the forecasts we now score. So the sync is replayed only now.)
      _radarUpdates
        ..clear()
        ..addAll({
          for (final e in ((m['radar_updates'] as Map?) ?? const {}).entries)
            e.key as String: (e.value as Map).cast<String, String>(),
        });
      _applyRadarUpdates();
      return true;
    } catch (_) {
      return false; // corrupt or old state: start fresh
    }
  }
}

final appState = AppState();
