import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lab.dart';
import 'screens.dart';
import 'whoami.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? setupError;
  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    setupError = 'SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY not set. Start the app with run.ps1 (see README).';
  } else {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
    try {
      await Lab.loadDomain();
    } catch (e) {
      setupError = 'Could not read expert_login_domain(). Run supabase/migrations/20261107000000_invite_auth.sql '
          'in the Supabase SQL Editor first.\n\n${explain(e)}';
    }
  }
  runApp(AuthLab(setupError: setupError));
}

class AuthLab extends StatelessWidget {
  final String? setupError;
  const AuthLab({super.key, this.setupError});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1F5A7A);
    ThemeData theme(Brightness b) => ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: b),
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
          useMaterial3: true,
        );
    return MaterialApp(
      title: 'Auth Lab · Ground Truth',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: setupError != null ? SetupError(setupError!) : const Gate(),
    );
  }
}

/// Signed in → "Who am I". Signed out → start screen.
class Gate extends StatelessWidget {
  const Gate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: sb.auth.onAuthStateChange,
        builder: (context, _) => sb.auth.currentSession == null ? const StartScreen() : const WhoAmIScreen(),
      );
}

class SetupError extends StatelessWidget {
  final String message;
  const SetupError(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Setup needed', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                SelectableText(message),
              ]),
            ),
          ),
        ),
      );
}
