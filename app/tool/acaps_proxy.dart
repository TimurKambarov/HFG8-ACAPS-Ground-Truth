// =============================================================================
// Local CORS proxy for the ACAPS API
// =============================================================================
//
// Needed only for the web build: the browser blocks direct calls because
// api.acaps.org sends no CORS headers.
//
// Why: a web page may only read answers from another site if that site says
// "this origin is allowed" (the Access-Control-Allow-Origin header). The ACAPS
// API does not say it, so Edge/Chrome hide every answer from our web app.
// This little server runs on the same computer, forwards each request to
// ACAPS unchanged and adds the missing headers to the answer:
//
//   Flutter web app  --->  localhost:8787 (this proxy)  --->  api.acaps.org
//                    <---   + CORS headers              <---
//
// Usage:
//   dart run tool/acaps_proxy.dart            # listens on http://localhost:8787
//   dart run tool/acaps_proxy.dart 9000       # another port (then build with
//                                             # --dart-define=ACAPS_API_BASE=http://localhost:9000)
// In VS Code, the "app (Edge)" launch configuration starts it automatically
// (.vscode/tasks.json).
//
// It forwards /api/v1/* to https://api.acaps.org unchanged (method, body,
// Authorization header) and adds CORS headers. It listens on localhost only,
// so nobody else on the network can use it.
// =============================================================================

import 'dart:io';

const _upstream = 'https://api.acaps.org';

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args.first) : 8787;

  // Open the port. loopbackIPv4 = 127.0.0.1 = this computer only.
  final HttpServer server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  } on SocketException {
    // Most likely a proxy is already running (started by hand or by VS Code).
    // Exit quietly with success, so a VS Code launch does not show an error.
    stdout.writeln('ACAPS API proxy on http://localhost:$port is already running (port in use). Nothing to do.');
    return;
  }
  final client = HttpClient(); // used to call the real API
  // VS Code's task waits for this exact line before it starts the app.
  stdout.writeln('ACAPS API proxy on http://localhost:$port -> $_upstream (Ctrl+C to stop)');

  // Handle requests one after another, forever (until Ctrl+C).
  await for (final req in server) {
    final res = req.response;

    // CORS headers on every answer: allow the page that asked (its "origin",
    // e.g. http://localhost:51234 for `flutter run -d edge`).
    final origin = req.headers.value('origin') ?? '*';
    res.headers
      ..set('Access-Control-Allow-Origin', origin)
      ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      ..set('Access-Control-Allow-Headers', 'Authorization, Content-Type')
      ..set('Vary', 'Origin');

    // "Preflight": before a request with an Authorization header the browser
    // first sends OPTIONS to ask whether it is allowed. We just say yes.
    if (req.method == 'OPTIONS') {
      res.statusCode = HttpStatus.noContent;
      await res.close();
      continue;
    }

    // Only forward API calls, nothing else.
    if (!req.uri.path.startsWith('/api/v1/')) {
      res.statusCode = HttpStatus.notFound;
      res.write('Only /api/v1/* is proxied.');
      await res.close();
      continue;
    }

    try {
      // Same method and path (+ query, e.g. ?page=2) on the real API.
      final up = await client.openUrl(req.method, Uri.parse(_upstream).resolve(req.uri.toString()));
      // Copy only the headers the API needs (the token, the body type).
      for (final h in ['authorization', 'content-type', 'accept']) {
        final v = req.headers.value(h);
        if (v != null) up.headers.set(h, v);
      }
      await up.addStream(req); // copy the body (the login JSON for POST)
      final upRes = await up.close(); // send, wait for ACAPS's answer

      // Pass the answer back unchanged: status code, content type, body.
      res.statusCode = upRes.statusCode;
      final type = upRes.headers.contentType;
      if (type != null) res.headers.contentType = type;
      await res.addStream(upRes);
      stdout.writeln('${req.method} ${req.uri} -> ${upRes.statusCode}'); // small log line
    } catch (e) {
      // ACAPS unreachable (no internet, DNS...): 502 Bad Gateway.
      res.statusCode = HttpStatus.badGateway;
      res.write('Proxy error: $e');
      stderr.writeln('${req.method} ${req.uri} failed: $e');
    }
    await res.close();
  }
}
