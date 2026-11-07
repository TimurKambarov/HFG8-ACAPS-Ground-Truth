/// Real accounts against the project's Supabase: sign-up with a code, login,
/// moderator invite codes and expert referral codes.
///
/// Server-side rules: supabase/migrations/20261107000000_invite_auth.sql and
/// 20261107120000_referrals.sql.
/// * Experts log in with pseudonym + password. Their Auth email is made up:
///   lower(pseudonym)@<rpc('expert_login_domain')>.
/// * Moderators log in with their real email + password.
/// * Sign-up needs a code: a moderator's single-use GT-… invite or an
///   expert's permanent REF-… referral code. There is no installed app yet,
///   so people share codes, not links.
///
/// Answers, comments and points still run on local demo data. A real account
/// decides who "me" is, and codes and referrals live in Supabase.
///
/// Without the keys (plain `flutter run`) [Auth.ready] is false and the app
/// falls back to the synthetic demo users and local codes.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'identity.dart';
import 'models.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

/// Shortest password Supabase accepts by default.
const minPassword = 6;

/// The user's row in public.profiles, as far as the app needs it.
class AccountProfile {
  final String userId;
  final bool isModerator;
  final String pseudonym;
  final String? realName;
  final String anonymity; // known_to_acaps | pseudonymous | anonymous
  final String? homeCountry;
  final List<String> interests;
  final bool onRating;
  final bool notifications;
  final bool hideFromOtherCountries;
  final JoinedVia joinedVia;

  const AccountProfile({
    required this.userId,
    required this.isModerator,
    required this.pseudonym,
    required this.realName,
    required this.anonymity,
    required this.homeCountry,
    required this.interests,
    required this.onRating,
    required this.notifications,
    required this.hideFromOtherCountries,
    this.joinedVia = JoinedVia.acapsInvite,
  });

  factory AccountProfile.fromRow(Map<String, dynamic> m) => AccountProfile(
        userId: m['id'] as String,
        isModerator: m['role'] == 'moderator',
        pseudonym: m['pseudonym'] as String,
        realName: m['real_name'] as String?,
        anonymity: m['anonymity'] as String? ?? 'pseudonymous',
        homeCountry: m['home_country'] as String?,
        interests: ((m['interests'] as List?) ?? const []).cast<String>(),
        onRating: m['on_rating'] != false,
        notifications: m['notifications'] != false,
        hideFromOtherCountries: m['hide_from_other_countries'] == true,
        joinedVia: m['joined_via'] == 'expert_referral' ? JoinedVia.expertReferral : JoinedVia.acapsInvite,
      );

  Anonymity get level => switch (anonymity) {
        'known_to_acaps' => Anonymity.knownToAcaps,
        'anonymous' => Anonymity.anonymous,
        _ => Anonymity.pseudonymous,
      };
}

/// A code that works, as checked by the server before the sign-up form.
class CodeCheck {
  final String code;

  /// A colleague's REF-… code (permanent), or a moderator's invite.
  final bool isReferral;

  /// The code makes an ACAPS moderator account (real email and name).
  final bool isModerator;

  /// Panel the code puts the expert in; null = they choose.
  final String? panel;

  const CodeCheck({required this.code, required this.isReferral, required this.isModerator, this.panel});
}

/// The text people type: upper case, no spaces.
String cleanCode(String s) => s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

class Auth {
  /// False when the app was started without the Supabase keys (plain
  /// `flutter run`). Only the demo users and local codes work then.
  static bool get configured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Supabase is initialised: real accounts and codes. Set by [init].
  static bool ready = false;

  /// Why real accounts are unavailable, shown on the login screen.
  static String? problem;

  static String? _loginDomain;

  static SupabaseClient get _sb => Supabase.instance.client;

  static String? get currentUserId => ready ? _sb.auth.currentUser?.id : null;

  /// Starts Supabase and restores a saved session. Never throws: the demo
  /// must keep working offline. [onSignedOut] runs when Supabase ends the
  /// session by itself (e.g. the refresh token was revoked).
  static Future<void> init({void Function()? onSignedOut}) async {
    if (!configured) return;
    try {
      await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
      ready = true;
    } catch (e) {
      problem = 'Could not start Supabase: $e';
      return;
    }
    _sb.auth.onAuthStateChange.listen(
      (s) {
        if (s.event == AuthChangeEvent.signedOut) onSignedOut?.call();
      },
      onError: (_) {},
    );
    // Not awaited, so an offline launch is not delayed. Retried when needed.
    _loadDomain().catchError((_) {});
  }

  static Future<void> _loadDomain() async {
    _loginDomain ??= await _sb.rpc('expert_login_domain') as String;
  }

  static void _needReady() {
    if (!ready) throw StateError(problem ?? 'Accounts are not available in this build.');
  }

  static String _expertEmail(String pseudonym) => '${pseudonym.trim().toLowerCase()}@$_loginDomain';

  /// "Pseudonym or email": anything with an @ is an email (moderators).
  static String _loginEmail(String who) => who.contains('@') ? who.trim().toLowerCase() : _expertEmail(who);

  // ---------------------------------------------------------------------------
  // Codes
  // ---------------------------------------------------------------------------

  /// Checks a typed code. Does not use it up: only a successful sign-up does.
  static Future<({CodeCheck? code, InviteStatus status})> checkCode(String typed) async {
    _needReady();
    final code = cleanCode(typed);
    if (code.isEmpty) return (code: null, status: InviteStatus.unknown);
    final rows = await _sb.rpc('check_invite', params: {'invite': code}) as List;
    if (rows.isNotEmpty) {
      final r = rows.first as Map;
      return (
        code: CodeCheck(
          code: code,
          isReferral: r['kind'] == 'referral',
          isModerator: r['role'] == 'moderator',
          panel: r['panel_country'] as String?,
        ),
        status: InviteStatus.ok,
      );
    }
    final why = await _sb.rpc('invite_status', params: {'invite': code}) as String?;
    return (
      code: null,
      status: switch (why) {
        'used' => InviteStatus.used,
        'revoked' => InviteStatus.revoked,
        'expired' => InviteStatus.expired,
        _ => InviteStatus.unknown,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Sign-up and login
  // ---------------------------------------------------------------------------

  /// Creates an expert account with [code] and returns its profile.
  static Future<AccountProfile> signUpExpert({
    required CodeCheck code,
    required String pseudonym,
    required String password,
    required Anonymity level,
    required String? realName,
    required String homeCountry,
    required Set<String> interests,
    required bool notifications,
    required bool onRating,
    required bool hideFromOtherCountries,
  }) async {
    _needReady();
    await _loadDomain();
    final r = await _sb.auth.signUp(
      email: _expertEmail(pseudonym),
      password: password,
      data: {
        'invite': code.code,
        'pseudonym': pseudonym.trim(),
        'anonymity': switch (level) {
          Anonymity.knownToAcaps => 'known_to_acaps',
          Anonymity.pseudonymous => 'pseudonymous',
          Anonymity.anonymous => 'anonymous',
        },
        if (level.needsRealName && realName != null) 'real_name': realName.trim(),
        'home_country': homeCountry,
        'interests': (interests.toSet()..remove(homeCountry)).toList(),
        'notifications': notifications,
        'on_rating': onRating,
        'hide_from_other_countries': hideFromOtherCountries,
      },
    );
    return _afterSignUp(r);
  }

  /// Creates a moderator account with a moderator code and returns its profile.
  static Future<AccountProfile> signUpModerator({
    required CodeCheck code,
    required String realName,
    required String email,
    required String password,
  }) async {
    _needReady();
    final r = await _sb.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {'invite': code.code, 'real_name': realName.trim()},
    );
    return _afterSignUp(r);
  }

  static Future<AccountProfile> _afterSignUp(AuthResponse r) async {
    if (r.session == null) {
      throw StateError('The account was created, but Supabase wants the email confirmed first. '
          'Turn off "Confirm email" in Supabase (see supabase/README.md), then log in.');
    }
    return _profileOrSignOut();
  }

  /// Logs in and returns the user's profile. Throws on failure; see [explain].
  static Future<AccountProfile> logIn(String who, String password) async {
    _needReady();
    if (!who.contains('@')) await _loadDomain();
    await _sb.auth.signInWithPassword(email: _loginEmail(who), password: password);
    return _profileOrSignOut();
  }

  static Future<AccountProfile> _profileOrSignOut() async {
    try {
      final p = await fetchProfile();
      if (p == null) throw StateError('No profile found for this account. Ask your ACAPS contact.');
      return p;
    } catch (_) {
      await _sb.auth.signOut();
      rethrow;
    }
  }

  /// The signed-in user's profile row, or null if there is none.
  static Future<AccountProfile?> fetchProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    final row = await _sb.from('profiles').select().eq('id', uid).maybeSingle();
    return row == null ? null : AccountProfile.fromRow(row);
  }

  /// Ends the Supabase session. Safe to call when accounts are not set up.
  static Future<void> signOut() async {
    if (!ready || _sb.auth.currentSession == null) return;
    try {
      await _sb.auth.signOut();
    } catch (_) {
      // Offline: the local session is cleared anyway.
    }
  }

  // ---------------------------------------------------------------------------
  // Referrals (experts)
  // ---------------------------------------------------------------------------

  /// The signed-in expert's permanent REF-… code (made on first use).
  static Future<String?> myReferralCode() async {
    _needReady();
    return await _sb.rpc('my_referral_code') as String?;
  }

  /// When each colleague joined with my referral code. Never who.
  static Future<List<DateTime>> myReferrals() async {
    _needReady();
    final rows = await _sb.rpc('my_referrals') as List;
    return [for (final r in rows) DateTime.parse((r as Map)['joined_at'] as String).toLocal()];
  }

  // ---------------------------------------------------------------------------
  // Invite codes (moderators)
  // ---------------------------------------------------------------------------

  /// A new single-use GT-… code for one person.
  static Future<String> createInvite({String note = ''}) async {
    _needReady();
    return await _sb.rpc('create_invite', params: {'note': note.trim()}) as String;
  }

  /// Every moderator invite code, newest first.
  static Future<List<Invite>> listInvites() async {
    _needReady();
    final rows = await _sb.rpc('list_invites') as List;
    return [
      for (final raw in rows)
        () {
          final r = (raw as Map).cast<String, dynamic>();
          final maxUses = r['max_uses'] as int?;
          final usedUp = maxUses != null && (r['used_count'] as int? ?? 0) >= maxUses;
          return Invite(
            code: r['code'] as String,
            country: r['panel_country'] as String?,
            createdBy: (r['created_by'] as String?) ?? '',
            createdByName: r['created_by_name'] as String?,
            createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
            note: (r['note'] as String?) ?? '',
            usedAt: usedUp && r['used_at'] != null ? DateTime.parse(r['used_at'] as String).toLocal() : null,
            revoked: r['revoked_at'] != null,
          );
        }(),
    ];
  }

  static Future<void> setInviteNote(String code, String note) async {
    _needReady();
    await _sb.rpc('set_invite_note', params: {'invite': code, 'note': note.trim()});
  }

  static Future<void> revokeInvite(String code) async {
    _needReady();
    await _sb.rpc('revoke_invite', params: {'invite': code});
  }

  /// Moderators: colleagues joined per expert (account id -> count).
  static Future<Map<String, int>> referralCounts() async {
    _needReady();
    final rows = await _sb.rpc('referral_counts') as List;
    return {for (final r in rows) (r as Map)['referrer_id'] as String: (r['n'] as num).toInt()};
  }
}

/// Turns account errors into a sentence for the user.
String explain(Object e) {
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (e.code == 'invalid_credentials' || m.contains('invalid login credentials')) {
      return 'Wrong pseudonym, email or password.';
    }
    if (e.code == 'user_already_exists' || m.contains('already registered')) {
      return 'That pseudonym or email is already taken. Choose another one.';
    }
    if (e.code == 'email_not_confirmed' || m.contains('not confirmed')) {
      return 'This account is not confirmed yet. Ask your ACAPS contact.';
    }
    if (m.contains('database error saving new user')) {
      return 'The server refused the sign-up: the code may have just been used or cancelled, '
          'or a required field is missing.';
    }
    if (e.code == 'weak_password') return 'Password too weak: ${e.message}';
    if (e.code == 'email_address_invalid') return 'This email address is not accepted.';
    if (e.code == 'over_request_rate_limit') return 'Too many attempts. Wait a minute and try again.';
    if (e is AuthRetryableFetchException) return 'No connection to the server. Check your internet and try again.';
    return e.message;
  }
  if (e is PostgrestException) {
    if (e.message.contains('moderator_only')) return 'Only ACAPS moderators can do this.';
    if (e.code == 'PGRST202') {
      return 'The server is missing a function. Run supabase/migrations/20261107120000_referrals.sql (see supabase/README.md).';
    }
    return 'Server error: ${e.message}';
  }
  if (e is StateError) return e.message;
  final s = e.toString();
  if (s.contains('SocketException') || s.contains('ClientException') || s.contains('Failed host lookup')) {
    return 'No connection to the server. Check your internet and try again.';
  }
  return s;
}
