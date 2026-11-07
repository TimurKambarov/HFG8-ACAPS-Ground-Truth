/// Supabase calls and rules for the invite / login test bench.
/// Server-side rules live in supabase/migrations/20261107000000_invite_auth.sql.
library;

import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

SupabaseClient get sb => Supabase.instance.client;

/// Same rule as the database check `pseudonym_format`.
final pseudonymPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{2,29}$');
const pseudonymRule = '3-30 letters, digits, - or _. This is your login name and cannot be changed later.';
const minPassword = 8;

enum Level { knownToAcaps, pseudonymous, anonymous }

extension LevelText on Level {
  String get label => switch (this) {
        Level.knownToAcaps => '1 · Known to ACAPS',
        Level.pseudonymous => '2 · Known to colleagues by pseudonym',
        Level.anonymous => '3 · Fully anonymous',
      };
  String get description => switch (this) {
        Level.knownToAcaps => 'ACAPS moderators see your real name. Colleagues see your pseudonym.',
        Level.pseudonymous => 'Everyone, including ACAPS, sees only your pseudonym.',
        Level.anonymous => 'Nobody sees who wrote your input. No real name is stored.',
      };
  bool get needsName => this != Level.anonymous;

  /// Value of the database enum public.anonymity_level.
  String get dbName => switch (this) {
        Level.knownToAcaps => 'known_to_acaps',
        Level.pseudonymous => 'pseudonymous',
        Level.anonymous => 'anonymous',
      };
}

class Invite {
  final String code;
  final String role; // 'expert' | 'moderator'
  final String? panel;
  const Invite(this.code, this.role, this.panel);
  bool get isModerator => role == 'moderator';
  String get summary => isModerator ? 'ACAPS moderator' : '$panel panel · expert';
}

class Lab {
  /// Read from the database, so the app and the sign-up check always agree.
  static String? loginDomain;

  static Future<void> loadDomain() async {
    loginDomain = await sb.rpc('expert_login_domain') as String;
  }

  static String expertLoginEmail(String pseudonym) => '${pseudonym.trim().toLowerCase()}@$loginDomain';

  /// "Pseudonym or email": anything with an @ is an email (moderators).
  static String loginEmail(String input) => input.contains('@') ? input.trim().toLowerCase() : expertLoginEmail(input);

  static Future<Invite?> checkInvite(String code) async {
    final clean = code.trim().toUpperCase();
    final rows = await sb.rpc('check_invite', params: {'invite': clean}) as List;
    if (rows.isEmpty) return null;
    final r = rows.first as Map;
    return Invite(clean, r['role'] as String, r['panel_country'] as String?);
  }

  static Future<AuthResponse> signUpExpert({
    required Invite invite,
    required String pseudonym,
    required Level level,
    required String? realName,
    required String password,
    required String? contactEmail,
  }) =>
      sb.auth.signUp(
        email: expertLoginEmail(pseudonym),
        password: password,
        data: {
          'invite': invite.code,
          'pseudonym': pseudonym.trim(),
          'anonymity': level.dbName,
          if (level.needsName && realName != null) 'real_name': realName.trim(),
          if (contactEmail != null && contactEmail.trim().isNotEmpty) 'contact_email': contactEmail.trim(),
        },
      );

  static Future<AuthResponse> signUpModerator({
    required Invite invite,
    required String realName,
    required String email,
    required String password,
  }) =>
      sb.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {'invite': invite.code, 'real_name': realName.trim()},
      );

  static Future<AuthResponse> logIn(String who, String password) =>
      sb.auth.signInWithPassword(email: loginEmail(who), password: password);

  /// Tries to sign up with no invite code on a throwaway client (the current
  /// session is untouched). Returns null when the database refused, as it should.
  static Future<String?> probeSignUpWithoutInvite() async {
    // A bare SupabaseClient defaults to the PKCE flow, which needs a storage for its
    // code verifier. The probe stores nothing, so it uses the implicit flow (plain
    // email + password sign-up does not need PKCE anyway).
    final probe = SupabaseClient(
      supabaseUrl,
      supabaseKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false, authFlowType: AuthFlowType.implicit),
    );
    final name = 'probe-${Random().nextInt(1 << 30).toRadixString(36)}';
    try {
      final r = await probe.auth.signUp(
        email: expertLoginEmail(name),
        password: 'probe-password-123',
        data: {'pseudonym': name, 'anonymity': 'anonymous'},
      );
      return 'Sign-up WITHOUT invite was accepted (user ${r.user?.id}). Delete it in Authentication → Users.';
    } on AuthException {
      return null;
    } finally {
      await probe.dispose();
    }
  }
}

/// Turns Supabase errors into a sentence, keeping the raw code for debugging.
String explain(Object e) {
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    final code = e.code ?? e.statusCode ?? '';
    final text = switch (true) {
      _ when e.code == 'user_already_exists' || m.contains('already registered') =>
        'That pseudonym or email is already taken.',
      _ when e.code == 'email_address_invalid' =>
        'Supabase refused the login address. Change expert_login_domain() in the migration (see README).',
      _ when e.code == 'invalid_credentials' || m.contains('invalid login credentials') =>
        'Wrong login name or password.',
      _ when e.code == 'email_not_confirmed' || m.contains('not confirmed') =>
        '"Confirm email" is still on in Supabase. Turn it off (see README).',
      _ when m.contains('database error saving new user') =>
        'The database refused the sign-up: the invite is invalid or used up, or a required field is missing.',
      _ when e.code == 'weak_password' => 'Password too weak: ${e.message}',
      _ when e.code == 'over_request_rate_limit' || e.code == 'over_email_send_rate_limit' =>
        'Supabase rate limit hit. Wait a minute and try again.',
      _ => e.message,
    };
    return code.isEmpty ? text : '$text  [$code]';
  }
  if (e is PostgrestException) return '${e.message}  [${e.code}]';
  return e.toString();
}
