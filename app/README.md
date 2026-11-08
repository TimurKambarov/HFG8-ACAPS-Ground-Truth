# Ground Truth: phone app

The Ground Truth app for experts and ACAPS moderators, built for **Android and iOS phones**. Features: sign-up
with an invite or referral code, log in, referral codes and progress, moderator invites, search and filters, the
survey, group view, rating and the expert-input export. The full expert and moderator flow is described in the
README of the earlier browser build (`git show effd385:app/README.md`).

This folder combines two branches:

- **Functionality from `app-auth-api`** (the former `app-mobile/` folder): Supabase accounts, invite and referral
  codes, and ACAPS risks read from the Supabase `risks` table.
- **Design from `test-design-last-hope-DONT-MERGE`**: the acaps.org look (`lib/brand.dart`, `lib/theme.dart`,
  `lib/widgets.dart`, bundled fonts in `assets/fonts/`), with navy page headers, contour lines and key figures.

How it differs from the earlier browser build:

- **Risks come from the ACAPS Risk Radar API, not from a CSV.** The app reads the Supabase `risks` table, which
  [`../scripts/sync_risks.dart`](../scripts/sync_risks.dart) keeps equal to the live API (see *Risks* below).
  The Risks tab shows where they come from (`ACAPS Risk Radar · 137 risks · updated 7 Nov 2026`) and a
  *Refresh* button.
- **No Import, Sync statuses or New risk for moderators.** Risks are ACAPS's own and arrive through the sync.
- **Demo risk R1055** (mass returns from eastern Chad to West Darfur) instead of R1043, which is no longer in the
  Risk Radar API. R1055 has the same storyline (the panel moved from Medium to High over the last month).
- Phone details: portrait only; a **Who?** chip (experts) and *tap for countries* (moderators) open a sheet with
  where agreeing / disagreeing experts come from, since phones have no hover; a light vibration when picking 1–5;
  the rating scope is a row of chips that scrolls sideways; the country search stays above the keyboard.
- Android app name "Ground Truth", application ID `com.example.ground_truth.mobile`.

## Risks

```
ACAPS Risk Radar API --(scripts/sync_risks.dart, secret key)--> Supabase `risks` --(read only)--> app
```

- The app **never calls the ACAPS API and never writes risks.** It reads `risks` with the publishable key at every
  launch (and on *Refresh*), and keeps a copy on the device.
- **Offline:** the app uses that copy and says so ("Offline copy of the ACAPS Risk Radar …"). On a first launch with
  no connection and no copy, it shows *Could not load the risks* with *Retry*.
- **Updating the database:** from the repo root, `dart run scripts/sync_risks.dart`
  (`--dry-run` to only compare). It writes **only what changed**: if Supabase already matches the API it prints
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

### Android phone (wireless debugging)

Needs the Android SDK. Pair the phone once via *Developer options → Wireless debugging*, then
`flutter devices` shows it (e.g. "SM A366B (wireless)") and `./app/run.ps1 -Device <device-id>` runs on it.
The first Android build downloads Gradle and takes a few minutes.

Without the Android SDK: `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --dart-define-from-file=.dart_tool/supabase_keys.json`,
then open `http://<this computer's IP>:8080` on a phone on the same Wi-Fi.

### Web and the live demo

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
