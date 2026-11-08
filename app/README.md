# Ground Truth: the app

The Ground Truth app for humanitarian experts and ACAPS moderators, built for **Android phones** (distributed as an
APK) and also available as a web app. One Flutter code base, portrait phone layouts only.

**Experts:** sign up with an invite or referral code, choose an anonymity level, answer the short survey per risk
(triggers + one forecast), see the anonymised group view, track their accuracy and points, invite colleagues.
**Moderators:** review comments, manage panels and invite codes, sort risks by disagreement, see the expert panel
with trust signals, and export the aggregated expert input for ACAPS.

| Part | Where |
|---|---|
| Screens | [`lib/screens/`](lib/screens/): start and sign-up (`entry`), expert home, survey and group view, moderator, profile |
| State, scoring, points | [`lib/store.dart`](lib/store.dart), [`lib/models.dart`](lib/models.dart) |
| Anonymity rules | [`lib/identity.dart`](lib/identity.dart): every name shown comes from `displayName(expert, viewer)` |
| Accounts and codes (Supabase) | [`lib/auth.dart`](lib/auth.dart) |
| Risks (Supabase, read only) | [`lib/risk_source.dart`](lib/risk_source.dart) |
| acaps.org look | [`lib/theme.dart`](lib/theme.dart), [`lib/brand.dart`](lib/brand.dart), [`lib/widgets.dart`](lib/widgets.dart), fonts in [`assets/fonts/`](assets/fonts/) |

Phone details: portrait only; a **Who?** chip (experts) and *tap for countries* (moderators) open a sheet with where
agreeing / disagreeing experts come from, since phones have no hover; a light vibration when picking 1–5; the rating
scope is a row of chips that scrolls sideways; the country search stays above the keyboard. Demo risk: **R1055**
(mass returns from eastern Chad to West Darfur).

## Risks

```
ACAPS Risk Radar API --(scripts/sync_risks.dart, secret key)--> Supabase `risks` --(read only)--> app
```

- The app **never calls the ACAPS API and never writes risks.** It reads `risks` with the publishable key at every
  launch (and on *Refresh*), and keeps a copy on the device.
- **Offline:** the app uses that copy and says so ("Offline copy of the ACAPS Risk Radar …"). On a first launch with
  no connection and no copy, it shows *Could not load the risks* with *Retry*.
- **Updating the database:** automatic every Monday through the
  [Weekly risk sync](../.github/workflows/weekly-risk-sync.yml) GitHub Action, or by hand from the repo root with
  `dart run scripts/sync_risks.dart` (`--dry-run` to only compare). It writes **only what changed**: if Supabase already matches the API it prints
  *already up to date* and writes nothing. Risks the API no longer lists are deleted (unless `--keep-removed`, and
  never when the API returns less than half of what Supabase has). It needs `SUPABASE_URL`, `SUPABASE_SECRET_KEY`,
  `ACAPS_EMAIL` and `ACAPS_PASSWORD` (environment variables or `../API.key`).
- Answers, comments and points are still kept on the device; a risk that closes in the Risk Radar moves to the
  Archive and the forecasts already given on it get scored.

## Run

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.22 or newer) and the git-ignored
`../API.key` with `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`.

```powershell
./app/run.ps1 -Device <device-id>    # passes only the URL and the publishable key, never the secret key
```

In VS Code, *Run and Debug* → **app (phone)** or **app (Edge, dev only)** does the same: a pre-launch task
writes `.dart_tool/supabase_keys.json` with only those two values (`tool/supabase_keys.dart`).

- **First moderator:** *I have a code* → `GT-ACAPS-MOD1` → name, work email, password.
- **Invite an expert:** as moderator, the key button → *Copy invitation message* → send it. The expert types the
  code, fills in the form with a password, and is in. Their own `REF-…` referral code is on their Profile.
- **Log in later:** *Log in* → pseudonym (experts) or email (moderators) + password.

Plain `flutter run` (no keys) starts without Supabase: only the demo users and local codes, and risks only if this
device saved a copy before.

### On an Android phone while developing (wireless debugging)

Needs the Android SDK. Pair the phone once via *Developer options → Wireless debugging*, then
`flutter devices` shows it (e.g. "SM A366B (wireless)") and `./app/run.ps1 -Device <device-id>` runs on it.
The first Android build downloads Gradle and takes a few minutes.

Without the Android SDK: `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --dart-define-from-file=.dart_tool/supabase_keys.json`,
then open `http://<this computer's IP>:8080` on a phone on the same Wi-Fi.

## Build the APK

The APK must contain the Supabase URL and publishable key (never the secret key), so build it with the key file:

```powershell
cd app
dart run tool/supabase_keys.dart      # writes .dart_tool/supabase_keys.json from ../API.key
flutter build apk --release --dart-define-from-file=.dart_tool/supabase_keys.json
```

The file to share is `build/app/outputs/flutter-apk/app-release.apk`. People install it by opening it on their
phone and allowing *Install unknown apps* for the browser or file manager they opened it with.

**Sign it with your own key before sharing.** Android only installs an update over an existing app if both are
signed with the same key, so all APKs you share must use one permanent upload key:

1. Create the keystore once (Java's `keytool` comes with Android Studio) and **back it up**: if it is lost,
   people have to uninstall the app (and lose its local data) to install a new version.
   ```powershell
   keytool -genkey -v -keystore $env:USERPROFILE\ground-truth-upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `app/android/key.properties` (git-ignored, never commit it):
   ```properties
   storePassword=<the keystore password>
   keyPassword=<the key password>
   keyAlias=upload
   storeFile=C:/Users/<you>/ground-truth-upload.jks
   ```
3. Build as above. Without `key.properties` the release APK is signed with the debug key: fine for a quick test,
   not for sharing.

For every APK you share, raise the build number after the `+` in `pubspec.yaml` (`version: 0.1.0+1` → `0.1.0+2`).
The app ID is `io.github.timurkambarov.groundtruth`; never change it, or phones treat the new APK as another app.

## Web and the live demo

The web build is the same phone app. [`web/index.html`](web/index.html) decides at load time how to show it: on a
phone or narrow window it fills the page; on a wide screen (at least 720 × 700) it runs **inside a phone frame**,
390 points wide, so it lays itself out exactly as on a phone. In the frame, Flutter draws into an element of the
page instead of the whole page (`hostElement` in [`web/flutter_bootstrap.js`](web/flutter_bootstrap.js)).
`?frame=off` in the address turns the frame off. *app (Edge, dev only)* shows the frame too.

The live demo on GitHub Pages is built by [`../.github/workflows/deploy-demo.yml`](../.github/workflows/deploy-demo.yml)
on every push to `main` that changes `app/`, with the same two Supabase values as `run.ps1` (repository secrets
`SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`; setup steps at the top of that file).

## Tests

```bash
cd app
flutter test                          # uses test/fixtures/risks.json, a snapshot of the synced risks table
dart run tool/identity_check.dart     # anonymity rules, without the Flutter test device
```

Tests never call Supabase. Refresh the snapshot after a sync with the command in `test/fixture_risks.dart`.

All experts and their answers are synthetic. **Profile → Reset demo** wipes the local demo data (the risks stay).
