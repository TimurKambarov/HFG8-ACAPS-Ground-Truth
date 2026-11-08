# CLAUDE.md — Context for AI Coding Assistants

This repository is team **Clankers**' **solution** to the **ACAPS Ground Truth** challenge at **Hackathon for Good #8** (6-8 November 2026, The Hague). It started as the challenge repository (docs, data, references) and now contains a working Flutter phone app and a Supabase backend built on top of it.

## What We Built

**Ground Truth**: a phone app that gives ACAPS a small, trusted, moderated network of humanitarian experts per country. In about 2 minutes per risk an expert ground-truths an ACAPS risk trigger by trigger (agree / how bad / what is missing), gives one scored 6-month forecast on ACAPS's probability scale, and sees an anonymised Delphi-style group view. Forecasts are scored with the Brier score against real outcomes and against ACAPS's own ratings ("super estimators"). Experts choose their anonymity level; individual contributions are never public. ACAPS moderators review comments, manage invite-only panels (invite and referral codes) and export aggregated expert input.

The root [README.md](README.md) maps every evaluation criterion to the code.

## Repo Structure

```
app/            → THE APP (Flutter: Android APK + web). Portrait, phone layouts only
  lib/          → screens/, models.dart, store.dart (state), identity.dart (anonymity rules),
                  auth.dart (Supabase accounts, invite/referral codes), risk_source.dart (reads the risks table)
  test/         → anonymity rules, parser, moderator smoke test; fixtures/risks.json = snapshot of the risks table
  tool/         → supabase_keys.dart (keys for flutter run), identity_check.dart
  android/      → app ID io.github.timurkambarov.groundtruth, launcher icon, release signing (key.properties)
  web/          → index.html + flutter_bootstrap.js: loading screen; phone frame on wide screens
supabase/       → Backend: SQL migrations (schema, row-level security, Brier views), setup guide
scripts/        → sync_risks.dart: ACAPS Risk Radar API → Supabase (secret key)
.github/        → deploy-demo.yml (web build → GitHub Pages), weekly-risk-sync.yml (runs sync_risks.dart)
docs/           → Challenge brief, methodology, data dictionary, evaluation criteria (from ACAPS); screenshots/
data/           → Risk Radar export (CSV + XLSX)
references/     → ACAPS methodology PDF and infographic
```

## Run

```powershell
./app/run.ps1 -Device <device-id>   # passes SUPABASE_URL + SUPABASE_PUBLISHABLE_KEY from API.key
cd app; flutter test                # never calls Supabase
# APK: see "Build the APK" in app/README.md (needs --dart-define-from-file with the Supabase keys)
```

In VS Code: *Run and Debug* → **app (phone)** or **app (Edge, dev only)**. Details: [app/README.md](app/README.md), [supabase/README.md](supabase/README.md).

## Key Rules in the Code

- The app is mobile-only: design every screen for a phone in portrait. On the web, wide screens get a phone frame (`app/web/index.html`), so the layout never needs a desktop version.
- The app only **reads** risks from Supabase and never calls the ACAPS API; `scripts/sync_risks.dart` writes them. The app holds only the publishable key, never the secret key.
- Every name shown anywhere comes from `displayName(expert, viewer)` in `app/lib/identity.dart`. Level 3 (fully anonymous) deletes the real name.
- No group results below `minPanel` (3) respondents (`app/lib/store.dart`). The export for ACAPS contains aggregates only.
- Accounts, codes, referrals and risks are in Supabase; answers, comments and points still run on synthetic demo data on the device (`shared_preferences`).
- All experts and their answers are synthetic. Risks, ACAPS ratings and outcomes are real (ACAPS Risk Radar).

## Data

- The app uses the live Risk Radar (Supabase `risks` table, synced from the ACAPS API). Demo risk: **R1055** (returns from eastern Chad to West Darfur); R1043 is no longer in the API
- `data/risk-radar-export.csv` — the original export: 139 risks, 57 countries, 25 columns
- Key fields: Risk ID, Risk Title, Country, Probability, Impact, Risk Level, Status
- Triggers field has a structured `Trigger ID: / Title: / Description:` format

## Important Notes

- Do not use personal data of real experts — synthetic users only
- Secrets (`API.key`, `*.key`, `.env`) are git-ignored; never commit keys
- The data is a working export with some quality issues (see `docs/data-dictionary.md`)
- ACAPS data is used under ACAPS' terms of use
