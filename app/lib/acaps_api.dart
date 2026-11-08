// =============================================================================
// ACAPS API client
// =============================================================================
//
// Talks to the official ACAPS REST API (https://api.acaps.org/api/v1/), used
// by the moderator's "Import" and "Sync statuses" screens
// (screens/import_risk.dart).
//
// How the ACAPS API works (from their docs and our tests):
//   1. Log in:  POST /api/v1/token-auth/  {"username": email, "password": ...}
//               -> {"token": "c92b..."}
//   2. Call:    GET  /api/v1/risk-radar/risk-radar/
//               with header  Authorization: Token c92b...
//   3. Paging:  the answer is {"count": 137, "next": "<url of page 2>",
//               "results": [ ...100 risks... ]}; follow "next" until null.
//   4. Limits:  ACAPS asks for at most one request per second.
//
// One snag: the browser cannot call api.acaps.org directly, because the API
// sends no CORS headers (Access-Control-Allow-Origin), so Chrome/Edge block
// the response. Android and desktop apps are not browsers and have no such
// rule. So:
//   * web build    -> talks to a tiny local proxy (tool/acaps_proxy.dart) on
//                     http://localhost:8787, which forwards to api.acaps.org
//                     and adds the CORS headers;
//   * Android / PC -> talk to https://api.acaps.org directly.
// In VS Code the "app (Edge)" launch configuration starts the proxy itself.
// =============================================================================

library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'models.dart';

// --- Configuration -----------------------------------------------------------
//
// `String.fromEnvironment` reads compile-time values passed with
//   flutter run --dart-define=ACAPS_EMAIL=... --dart-define=ACAPS_PASSWORD=...
// If none are given, the defaults below are used.

// Shared hackathon account for the Risk Radar API. Override per build with
// --dart-define=ACAPS_EMAIL=... --dart-define=ACAPS_PASSWORD=...
// NOTE: a value compiled into the app can be read by anyone who has the app.
// Fine for a hackathon demo; a real deployment would keep the login on a
// server (e.g. in the proxy or a Supabase function) and never ship it.
const _email = String.fromEnvironment('ACAPS_EMAIL', defaultValue: 'timurkambarov250@gmail.com');
const _password = String.fromEnvironment('ACAPS_PASSWORD', defaultValue: 'eowjnfjop2341');

/// Override with --dart-define=ACAPS_API_BASE=http://host:port
const _baseOverride = String.fromEnvironment('ACAPS_API_BASE');

/// Port of the local CORS proxy (must match tool/acaps_proxy.dart).
const proxyPort = 8787;

/// Where requests go: an explicit override, else the proxy on the web, else
/// the real API.
String get acapsApiBase =>
    _baseOverride.isNotEmpty ? _baseOverride : (kIsWeb ? 'http://localhost:$proxyPort' : 'https://api.acaps.org');

/// An error with a message meant for the moderator (shown as-is on screen).
class AcapsApiException implements Exception {
  final String message;
  const AcapsApiException(this.message);
  @override
  String toString() => message;
}

/// A Risk Radar risk plus when ACAPS last updated it.
///
/// The date is not part of our [Risk] model (the app does not need it
/// elsewhere), so it travels next to it for the import list and the form.
class ApiRisk {
  final Risk risk;
  final String lastUpdate;
  const ApiRisk(this.risk, this.lastUpdate);
}

class AcapsApi {
  /// [client] can be replaced in tests by a fake (package:http/testing
  /// MockClient), so the tests never hit the real API.
  AcapsApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Login token, fetched once per [AcapsApi] object and then reused.
  String? _token;

  /// Last download, kept for the session so reopening the screen is instant.
  /// `static` = shared by every screen; it lives only in memory (lost when the
  /// app restarts), which is what we want for live data.
  static List<ApiRisk>? cache;
  static DateTime? cachedAt;

  /// Builds a full URL from a path, on top of [acapsApiBase].
  Uri _url(String path) => Uri.parse(acapsApiBase).resolve(path);

  /// Turns a network failure into a message that tells the moderator what to
  /// do. On the web the usual cause is that the proxy is not running.
  /// (`Never` = this function always throws, so Dart knows code after a call
  /// to it is unreachable.)
  Never _unreachable(Object e) => throw AcapsApiException(kIsWeb
      ? 'Cannot reach the ACAPS API proxy at $acapsApiBase. Start it with: dart run tool/acaps_proxy.dart'
      : 'Cannot reach the ACAPS API ($e). Check the internet connection.');

  /// Step 1: log in and get the token (cached after the first call).
  Future<String> _auth() async {
    if (_token != null) return _token!;
    final http.Response res;
    try {
      res = await _client.post(
        _url('/api/v1/token-auth/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': _email, 'password': _password}),
      );
    } catch (e) {
      _unreachable(e); // no connection at all (or blocked by the browser)
    }
    if (res.statusCode != 200) {
      // We reached the API, but it said no: wrong email or password.
      throw AcapsApiException('ACAPS API login failed (${res.statusCode}). Check the API email and password.');
    }
    return _token = (jsonDecode(res.body) as Map)['token'] as String;
  }

  /// Every risk on the Risk Radar, following the API's pages. The API asks
  /// for at most one request per second.
  ///
  /// Returns the risks newest-update first and stores them in [cache].
  Future<List<ApiRisk>> riskRadar() async {
    final token = await _auth();
    final out = <ApiRisk>[];
    Uri? url = _url('/api/v1/risk-radar/risk-radar/');
    var first = true;

    // Step 3: keep fetching pages until the API says there is no "next" one.
    while (url != null) {
      // Respect the 1 request/second limit between pages.
      if (!first) await Future<void>.delayed(const Duration(seconds: 1));
      first = false;
      final http.Response res;
      try {
        res = await _client.get(url, headers: {'Authorization': 'Token $token'});
      } catch (e) {
        _unreachable(e);
      }
      if (res.statusCode != 200) {
        throw AcapsApiException('ACAPS API error ${res.statusCode} on ${url.path}.');
      }
      // Decode the raw bytes as UTF-8 ourselves: titles contain characters
      // like "La Niña" that would be garbled otherwise.
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      for (final m in (data['results'] as List? ?? const [])) {
        final map = (m as Map).cast<String, dynamic>();
        // Field mapping (API names -> our model) lives in Risk.fromApi.
        final r = Risk.fromApi(map);
        if (r.id.isNotEmpty) out.add(ApiRisk(r, '${map['last_risk_update'] ?? map['date_entered'] ?? ''}'));
      }
      // "next" is an absolute api.acaps.org link: keep our base (the proxy on the web).
      // Otherwise page 2 would go straight to api.acaps.org and be blocked by CORS.
      final next = data['next'] as String?;
      url = next == null ? null : _url('${Uri.parse(next).path}?${Uri.parse(next).query}');
    }

    // Newest first: dates are "YYYY-MM-DD", so text order = date order.
    out.sort((a, b) => b.lastUpdate.compareTo(a.lastUpdate));
    cache = out;
    cachedAt = DateTime.now();
    return out;
  }
}
