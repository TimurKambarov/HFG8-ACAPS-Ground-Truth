# Ground Truth: phone version

The phone version of [`../app`](../app/README.md). It has the same features: sign-up with an invite or referral
code, log in, referral codes and progress, moderator invites, search and filters, the survey, group view, rating and
the expert-input export. The full flow is described in `../app/README.md`.

What is different from `../app`:

- **Risks come from the ACAPS Risk Radar API, not from the CSV in this repo.** The app reads the Supabase `risks`
  table, which [`../scripts/sync_risks.dart`](../scripts/sync_risks.dart) keeps equal to the live API (see *Risks*
  below). There is no bundled CSV.
- **No Import, Sync statuses or New risk for moderators.** Risks are ACAPS's own and arrive through the sync.
  The Risks tab shows where they come from (`ACAPS Risk Radar · 137 risks · updated 7 Nov 2026`) and a
  *Refresh* button. Experts see the same line on their Risks tab.
- **Demo risk R1055** (mass returns from eastern Chad to West Darfur) instead of R1043: R1043 is no longer in the
  Risk Radar API. R1055 has the same storyline (the panel moved from Medium to High over the last month), and
  the seeded comments are about its triggers.
- Phone tweaks: portrait only; a **Who?** chip (experts) and *tap for countries* (moderators) open a sheet with
  where agreeing / disagreeing experts come from, since phones have no hover; a light vibration when picking 1–5;
  the rating scope is a row of chips that scrolls sideways; the country search stays above the keyboard.
- Android app name "Ground Truth", application ID `com.example.ground_truth.mobile`, so it installs next to `../app`.

## Risks

```
ACAPS Risk Radar API --(scripts/sync_risks.dart, secret key)--> Supabase `risks` --(read only)--> app-mobile
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
./app-mobile/run.ps1 -Device <device-id>    # passes only the URL and the publishable key, never the secret key
```

In VS Code, *Run and Debug* → **app-mobile (phone)** or **app-mobile (Edge)** does the same: a pre-launch task
writes `.dart_tool/supabase_keys.json` with only those two values (`tool/supabase_keys.dart`).

- **First moderator:** *I have a code* → `GT-ACAPS-MOD1` → name, work email, password.
- **Invite an expert:** as moderator, the key button → *Copy invitation message* → send it. The expert types the
  code, fills in the form with a password, and is in. Their own `REF-…` referral code is on their Profile.
- **Log in later:** *Log in* → pseudonym (experts) or email (moderators) + password.

Plain `flutter run` (no keys) starts without Supabase: only the demo users and local codes, and risks only if this
device saved a copy before.

### Android phone (wireless debugging)

Needs the Android SDK. Pair the phone once via *Developer options → Wireless debugging*, then
`flutter devices` shows it (e.g. "SM A366B (wireless)") and `./app-mobile/run.ps1 -Device <device-id>` runs on it.
The first Android build downloads Gradle and takes a few minutes.

Without the Android SDK: `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --dart-define-from-file=.dart_tool/supabase_keys.json`,
then open `http://<this computer's IP>:8080` on a phone on the same Wi-Fi.

## Tests

```bash
cd app-mobile
flutter test                          # uses test/fixtures/risks.json, a snapshot of the synced risks table
dart run tool/identity_check.dart     # anonymity rules, without the Flutter test device
```

Tests never call Supabase. Refresh the snapshot after a sync with the command in `test/fixture_risks.dart`.

All experts and their answers are synthetic. **Profile → Reset demo** wipes the local demo data (the risks stay).
