# CLAUDE.md — Context for AI Coding Assistants

This repository is team **Clankers**' **solution** to the **ACAPS Ground Truth** challenge at **Hackathon for Good #8** (6-8 November 2026, The Hague). It started as the challenge repository (docs, data, references) and now contains a working Flutter app and a Supabase backend built on top of it.

## What We Built

**Ground Truth**: a mobile-first app that gives ACAPS a small, trusted, moderated network of humanitarian experts per country. In about 2 minutes per risk an expert ground-truths an ACAPS risk trigger by trigger (agree / how bad / what is missing), gives one scored 6-month forecast on ACAPS's probability scale, and sees an anonymised Delphi-style group view. Forecasts are scored with the Brier score against real outcomes and against ACAPS's own ratings ("super estimators"). Experts choose their anonymity level; individual contributions are never public. ACAPS moderators review comments, manage invite-only panels, import risks from the live ACAPS API and export aggregated expert input.

The root [README.md](README.md) maps every evaluation criterion to the code.

## Repo Structure

```
app/            → MAIN APP (Flutter, web + Android). Demo entry point
  lib/          → screens/, models.dart, store.dart (state), identity.dart (anonymity rules), acaps_api.dart
  test/         → anonymity rules, parser, ACAPS import, moderator smoke test
  tool/         → local CORS proxy for the ACAPS API, anonymity check
app-mobile/     → Phone version of the app with real login against Supabase
auth-lab/       → Test app for invite codes, sign-up and login (Supabase)
supabase/       → Backend: SQL migrations (schema, row-level security, Brier views), setup guide
scripts/        → Loads the Risk Radar export into Supabase
docs/           → Challenge brief, methodology, data dictionary, evaluation criteria (from ACAPS)
data/           → Risk Radar export (CSV + XLSX)
references/     → ACAPS methodology PDF and infographic
notebooks/      → Starter data exploration notebook
```

## Run

```bash
cd app
flutter pub get
flutter run -d edge        # or -d chrome, or an Android device
flutter test
```

Details per part: [app/README.md](app/README.md), [app-mobile/README.md](app-mobile/README.md), [supabase/README.md](supabase/README.md).

## Key Rules in the Code

- Every name shown anywhere comes from `displayName(expert, viewer)` in `app/lib/identity.dart`. Level 3 (fully anonymous) deletes the real name.
- No group results below `minPanel` (3) respondents (`app/lib/store.dart`). The export for ACAPS contains aggregates only.
- The demo app stores everything on the device (`shared_preferences`); the Supabase schema is the backend for a pilot.
- All experts and their answers are synthetic. Risks, ACAPS ratings and outcomes are real (Risk Radar export).

## Data

- `data/risk-radar-export.csv` — 139 risks, 57 countries, 25 columns; a copy is bundled in `app/assets/`
- Key fields: Risk ID, Risk Title, Country, Probability, Impact, Risk Level, Status
- Demo risk: **R1043** (Chad/Sudan cross-border insecurity)
- Triggers field has a structured `Trigger ID: / Title: / Description:` format

## Important Notes

- Do not use personal data of real experts — synthetic users only
- Secrets (`API.key`, `*.key`, `.env`) are git-ignored; never commit keys
- The data is a working export with some quality issues (see `docs/data-dictionary.md`)
- ACAPS data is used under ACAPS' terms of use
