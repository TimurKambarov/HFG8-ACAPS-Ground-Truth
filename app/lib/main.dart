import 'package:flutter/material.dart';

import 'auth.dart';
import 'screens/entry.dart';
import 'screens/home.dart';
import 'screens/moderator.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A tapped push notification opens the app with ?risk=<id> (web) or the
  // same value from the notification payload (mobile).
  appState.deepLinkRisk = Uri.base.queryParameters['risk'];
  // Real accounts (only when started with the Supabase keys, see run.ps1).
  // Must finish before load(), which checks the saved account session.
  // New members join by typing the code they were sent on the start screen:
  // there is no installed app yet, so there are no invite links.
  await Auth.init(onSignedOut: () {
    if (appState.sessionAccountId != null) appState.signOut();
  });
  appState.load().then((_) => appState.refreshAccount());
  runApp(const GroundTruthApp());
}

class GroundTruthApp extends StatelessWidget {
  const GroundTruthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final contrast = appState.theme == AppTheme.contrast;
        return MaterialApp(
          title: 'Ground Truth',
          debugShowCheckedModeBanner: false,
          theme: contrast ? buildContrastTheme() : buildTheme(Brightness.light),
          darkTheme: contrast ? buildContrastTheme() : buildTheme(Brightness.dark),
          themeMode: switch (appState.theme) {
            AppTheme.light => ThemeMode.light,
            AppTheme.dark => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * appState.textScale)),
              child: child!,
            );
          },
          home: _root(),
        );
      },
    );
  }

  Widget _root() {
    if (!appState.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (appState.error != null) {
      return Scaffold(body: Center(child: Text('Could not load data:\n${appState.error}')));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: appState.sessionModerator
          ? ModeratorShell(key: ValueKey('moderator-${appState.sessionModeratorId}'))
          : appState.me != null
              ? HomeShell(key: ValueKey('home-${appState.me!.id}'))
              // A valid code was entered: the sign-up form.
              : appState.canRegister
                  ? const RegisterScreen(key: ValueKey('register'))
                  : appState.atSignIn
                      ? const SignInScreen(key: ValueKey('signin'))
                      : const InviteScreen(key: ValueKey('start')),
    );
  }
}
