/// Log in against the real Supabase project (no sign-up here yet).
///
/// Same rules as ../auth-lab (see auth-lab/CLAUDE.md and
/// supabase/migrations/20261107000000_invite_auth.sql):
/// * Experts log in with pseudonym + password. Their Auth email is made up:
///   lower(pseudonym)@<rpc('expert_login_domain')>.
/// * Moderators log in with their real email + password.
///
/// The app still runs on local demo data. A successful login only decides
/// who "me" is, using the user's row in public.profiles.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

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
      );
}

class Auth {
  /// False when the app was started without the Supabase keys (plain
  /// `flutter run`). Login is then hidden and only the demo users work.
  static bool get configured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Supabase is initialised. Set by [init].
  static bool ready = false;

  /// Why login is unavailable, shown on the login screen. Null when all is well.
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
    // Not awaited, so an offline launch is not delayed. Retried on the first login.
    _loadDomain().catchError((_) => '');
  }

  static Future<void> _loadDomain() async {
    _loginDomain ??= await _sb.rpc('expert_login_domain') as String;
  }

  /// "Pseudonym or email": anything with an @ is an email (moderators).
  static String _loginEmail(String who) =>
      who.contains('@') ? who.trim().toLowerCase() : '${who.trim().toLowerCase()}@$_loginDomain';

  /// Logs in and returns the user's profile. Throws on failure; see [explain].
  static Future<AccountProfile> logIn(String who, String password) async {
    if (!ready) throw StateError(problem ?? 'Login is not available in this build.');
    if (!who.contains('@')) await _loadDomain();
    await _sb.auth.signInWithPassword(email: _loginEmail(who), password: password);
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

  /// Ends the Supabase session. Safe to call when login is not set up.
  static Future<void> signOut() async {
    if (!ready || _sb.auth.currentSession == null) return;
    try {
      await _sb.auth.signOut();
    } catch (_) {
      // Offline: the local session is cleared anyway.
    }
  }
}

/// Turns login errors into a sentence for the user.
String explain(Object e) {
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (e.code == 'invalid_credentials' || m.contains('invalid login credentials')) {
      return 'Wrong pseudonym, email or password.';
    }
    if (e.code == 'email_not_confirmed' || m.contains('not confirmed')) {
      return 'This account is not confirmed yet. Ask your ACAPS contact.';
    }
    if (e.code == 'over_request_rate_limit') return 'Too many attempts. Wait a minute and try again.';
    if (e is AuthRetryableFetchException) return 'No connection to the server. Check your internet and try again.';
    return e.message;
  }
  if (e is PostgrestException) return 'Could not read your profile: ${e.message}';
  if (e is StateError) return e.message;
  final s = e.toString();
  if (s.contains('SocketException') || s.contains('ClientException') || s.contains('Failed host lookup')) {
    return 'No connection to the server. Check your internet and try again.';
  }
  return s;
}
