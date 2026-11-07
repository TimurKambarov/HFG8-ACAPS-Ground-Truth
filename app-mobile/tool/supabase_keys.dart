// Writes .dart_tool/supabase_keys.json for `flutter run --dart-define-from-file`,
// with ONLY the two values the app may contain: SUPABASE_URL and
// SUPABASE_PUBLISHABLE_KEY, read from the git-ignored ../API.key.
// The secret key in that file is never copied.
//
// VS Code runs this before the app-mobile launch configurations
// (.vscode/tasks.json). By hand:
//   cd app-mobile
//   dart run tool/supabase_keys.dart
//   flutter run --dart-define-from-file=.dart_tool/supabase_keys.json
//
// Without API.key it writes {} and the app starts without Supabase (it then
// shows the risks saved on the device, if any, and demo users only).

import 'dart:convert';
import 'dart:io';

void main() {
  const wanted = ['SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY'];
  final keys = <String, String>{};
  final file = File.fromUri(Platform.script.resolve('../../API.key'));
  if (file.existsSync()) {
    for (final line in file.readAsLinesSync()) {
      final i = line.indexOf('=');
      if (i <= 0 || line.trimLeft().startsWith('#')) continue;
      final k = line.substring(0, i).trim();
      if (wanted.contains(k)) keys[k] = line.substring(i + 1).trim();
    }
  }
  final out = File.fromUri(Platform.script.resolve('../.dart_tool/supabase_keys.json'));
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(jsonEncode(keys));
  stdout.writeln(keys.length == wanted.length
      ? 'Supabase keys ready: ${out.path}'
      : 'API.key not found or incomplete: app-mobile starts without Supabase (${out.path}).');
}
