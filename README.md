# Ground Truth: a trusted expert loop for ACAPS risk analysis

**Team Clankers** | **Hackathon for Good #8** | 6-8 November 2026 | The Hague | Challenge by [ACAPS](https://www.acaps.org/)

Ground Truth is a mobile-first app that gives ACAPS a small, trusted, moderated network of humanitarian experts per country. In about **2 minutes per risk**, an expert:

1. **ground-truths** an ACAPS risk, trigger by trigger: agree or not, how bad it would be, and what ACAPS is missing;
2. gives **one scored forecast**: will this risk materialise within 6 months, on ACAPS's own probability scale;
3. sees an **anonymised, Delphi-style group view** and can change their answer in the next round.

Every forecast is scored against what really happened, so a track record builds up and **super estimators** emerge. Each expert chooses their own **anonymity level**, and individual contributions are never shown to the public. ACAPS moderators get the aggregated expert input next to their own assessment, review comments, and manage the panels. ACAPS still makes the forecast.

> **Demo:** the main app is in [`app/`](app/). Run it with `cd app && flutter pub get && flutter run -d edge` (or `-d chrome`, or an Android device). Open risk **R1043** (Chad/Sudan cross-border insecurity). Full walkthrough: [`app/README.md`](app/README.md).

---

## How it meets ACAPS's criteria

Mapped to the MoSCoW list in [`docs/evaluation-criteria.md`](docs/evaluation-criteria.md).

| Priority | Criterion | How Ground Truth does it | Where |
|---|---|---|---|
| **Must** | Easy to use, a community experts come back to | Personal invite link goes straight to the profile form. A survey takes about 2 minutes (max 3 trigger screens + 1 forecast), with *Not now* and Undo. Experts see what ACAPS did with their input ("Marked useful", "Used in the analysis of R1048"), points, badges and colleagues they invited | [`app/lib/screens/survey.dart`](app/lib/screens/survey.dart), [`app/lib/screens/home.dart`](app/lib/screens/home.dart) |
| **Must** | Each expert controls their anonymity | Three levels: known to ACAPS, pseudonym to colleagues, fully anonymous. Level 3 deletes the real name. Levels 1-2 can also stay anonymous to colleagues from other countries. Every name in the app comes from one function, `displayName(expert, viewer)`, which is tested | [`app/lib/identity.dart`](app/lib/identity.dart), [`app/test/identity_test.dart`](app/test/identity_test.dart), [`app/tool/identity_check.dart`](app/tool/identity_check.dart) |
| **Must** | Contributions always anonymous to the public | Group results only from **3+ respondents**. Export for ACAPS has aggregates only: no comments, no names next to answers, no respondent countries. Experts choose per risk how to be credited if ACAPS publishes it (real name, pseudonym, anonymous). Invite links record *that* they were used, never by whom | `minPanel` and `publicView` in [`app/lib/store.dart`](app/lib/store.dart) |
| **Should** | Sustained engagement over time | Every answer is a dated check-in, not an overwrite. Trend since the last ACAPS update ("Since 8 Oct: Medium → High · 3 of 5 experts changed their forecast"). Track record, matured forecasts with what happened, referral links with progress | [`app/lib/store.dart`](app/lib/store.dart) (`trendOf`, `CheckIn`) |
| **Should** | Short, focused contributions | One forecast per risk instead of one per trigger; trigger questions are not scored and the comment is optional | [`app/lib/screens/survey.dart`](app/lib/screens/survey.dart) |
| **Should** | Small trusted groups (5-10 per country) | Closed panels per country. Entry only by a moderator's single-use invite link or a member's referral link. Moderator inbox flags countries with fewer than 3 experts. Trust signals for moderators only: *Invited by ACAPS* / *Referred by an expert*, *New* / *Active* / *Established* | [`app/lib/screens/moderator.dart`](app/lib/screens/moderator.dart) |
| **Should not** | Engagement metrics as the goal; AI chatbot feel | Points reward accuracy (Brier score) and comments ACAPS found useful, not time in the app. No chatbot: experts answer structured questions and read colleagues' comments | [`app/lib/store.dart`](app/lib/store.dart) (`Points`, `Award`) |
| **Could** | Super estimator scoreboard | Accuracy = 100 × (1 − Brier) per matured forecast. "Bar to beat": ACAPS's own ratings scored the same way. Top 3 by Brier become *Super estimator* | [`app/lib/screens/home.dart`](app/lib/screens/home.dart) |
| **Could** | Where experts agree and disagree, incl. geography | Group view with the median and spread, and **"No clear group view: opinions split"** when the middle half spans 2+ steps (ACAPS's 1, 1, 5, 5 example). Respondents split into experts from the risk country and from elsewhere; agree/disagree on comments shows where those experts are from. Moderators sort by *experts most split* and *disagreement with ACAPS*. Ranking by country or region | `GroupView` in [`app/lib/models.dart`](app/lib/models.dart), [`app/lib/screens/survey.dart`](app/lib/screens/survey.dart) |
| **Could** | Mobile and low bandwidth | Mobile-first, works as web or Android app. No images and no web fonts: ACAPS graphics are drawn in code and the two ACAPS typefaces are bundled (~120 KB). Phone-optimised version in `app-mobile/` | [`app/lib/theme.dart`](app/lib/theme.dart), [`app/lib/brand.dart`](app/lib/brand.dart), [`app-mobile/`](app-mobile/) |
| **Could** | French and other languages | Not yet. Planned for the pilot | — |
| **Can** | AI behind the scenes for moderators | Not built on purpose for the hackathon: with 5-10 experts and a few short comments per risk, a moderator reads them in a minute, and expert comments should not leave Europe without a clear data agreement. Next step once panels grow: theme grouping of comments with links back to the source comments, minority views shown separately, moderator approves the draft | — |

### Use of the Risk Radar data

- The full **Risk Radar export** (139 risks, 57 countries) is the app's data: real titles, triggers, ACAPS probability, impact, risk level, categories (risk type, priority needs, expected exposure) and outcomes.
- Expert forecasts on **resolved risks are scored against what really happened**, and so are ACAPS's own ratings, so experts are compared with ACAPS on the same risks.
- Moderators can **import new risks from the live ACAPS API** and **sync statuses** (e.g. Active → Materialised), which moves risks to the archive and scores the forecasts already given. See [`app/lib/acaps_api.dart`](app/lib/acaps_api.dart).
- Expert input goes back to ACAPS as JSON with the Risk Radar field names, so it can be joined to ACAPS's own data.

### Feasibility: a backend for the pilot

The demo app runs on device storage, so it works offline and without accounts. For a pilot, the backend is already designed and running on **Supabase** ([`supabase/`](supabase/README.md)):

- Postgres schema for risks, triggers, profiles, invite codes, responses per Delphi round, comments and votes, with **row-level security** on every table. Experts read only their own profile and answers; moderators read all.
- Sign-up only with a valid invite code. Experts log in with pseudonym + password, so no real email is needed. A fully anonymous profile never stores a real name.
- Views that compute each expert's Brier score next to ACAPS's on resolved risks.
- Real login is already working in [`app-mobile/`](app-mobile/README.md) and the test app [`auth-lab/`](auth-lab/README.md). All experts in the demo are synthetic.

---

## Repository structure

```
HFG8-ACAPS-Ground-Truth/
├── README.md                ← You are here: what we built and how it meets the criteria
├── app/                     ← MAIN APP (Flutter, web + Android). Start here
│   ├── lib/                 ← screens/, models, store (state), identity (anonymity rules), ACAPS API client
│   ├── test/                ← anonymity rules, CSV/trigger parser, ACAPS import, moderator smoke test
│   ├── tool/                ← local CORS proxy for the ACAPS API (web build), anonymity check
│   └── assets/              ← Risk Radar export, ACAPS fonts
├── app-mobile/              ← Phone version of the app with real login against Supabase
├── auth-lab/                ← Small test app for invite codes, sign-up and login (Supabase)
├── supabase/                ← Backend: SQL migrations (schema + RLS) and setup guide
├── scripts/                 ← Loads the Risk Radar export into Supabase
│
├── docs/                    ← Challenge brief, methodology, data dictionary, evaluation criteria (from ACAPS)
├── data/                    ← Risk Radar export, CSV + XLSX (from ACAPS)
├── references/              ← ACAPS methodology PDF and infographic
└── notebooks/               ← Starter data exploration notebook
```

## Run it

| What | How |
|---|---|
| Main app | `cd app && flutter pub get && flutter run -d edge` (Flutter 3.22+). Tests: `flutter test` |
| Log in as | *Register* opens a demo invite link; *Log in* lists demo experts and the three ACAPS moderators (no passwords in the demo) |
| Live ACAPS API in the browser | `dart run tool/acaps_proxy.dart` in a second terminal (api.acaps.org sends no CORS headers) |
| Phone version with real login | See [`app-mobile/README.md`](app-mobile/README.md) |
| Backend | See [`supabase/README.md`](supabase/README.md) |
| Data notebook | `pip install -r requirements.txt && jupyter notebook notebooks/data-exploration.ipynb` |

## What's next

- One shared backend for the main app (the Supabase schema above), with server-side checks of invite links and anonymity.
- French and other working languages of field experts.
- Real push notifications and a vetting step for referred experts.
- AI support for moderators, as described in the criteria table.

---

# About the challenge

ACAPS analysts build the [Risk List](https://www.acaps.org/en/thematics/all-topics/risk-list): an overview of risks that could trigger a new humanitarian crisis or sharply worsen an existing one. But today, the knowledge of the experts closest to these crises — the people who sense a shift before it shows up in a report — stays locked in informal conversations and disappears.

**The challenge:** build a system that lets a trusted, moderated network of humanitarian experts challenge, enrich and forecast ACAPS risk analyses, while controlling their own anonymity and contributing in just a few minutes.

**Challenge owners:** Lars Peters and Alexander Harper, [ACAPS](https://www.acaps.org/), an independent humanitarian analysis organisation monitoring 100+ crises worldwide.

| Direction | What it means |
|-----------|---------------|
| **Ground Truthing** | Experts react to ACAPS risk analyses: do they agree? What is missing? Delphi-style: independent responses, anonymised group summary, iterative refinement. |
| **Forecasting** | Experts estimate how likely specific events are within six months. Track records emerge over time, surfacing "super estimators". |

Ground Truth covers both directions.

### The data

The ACAPS Risk Radar export contains **139 humanitarian risks** across **57 countries**, with the full lifecycle of each risk: the risk (title, type, country, triggers), the ACAPS rating (probability, impact, risk level, rationale) and what happened (status, materialisation description). Among resolved risks, about **84% of "High" risks materialised**. See the [data dictionary](docs/data-dictionary.md) and the [starter notebook](notebooks/data-exploration.ipynb).

### Key constraints

- **Anonymity is non-negotiable.** Each expert controls their level: known to ACAPS, pseudonymous to peers, or fully anonymous. Contributions are always anonymous to the public.
- **Respect experts' time.** A contribution should take minutes, not hours.
- **Small trusted groups.** 5-10 experts per country/context, moderated by ACAPS.
- **No real personal data.** Synthetic users during the hackathon.

<p align="center">
  <img src="references/acaps-risk-methodology-infographic.png" alt="ACAPS Risk Methodology" width="700">
</p>

### Resources

- [Full challenge brief](docs/challenge-brief.md) · [Risk methodology](docs/risk-methodology.md) · [Data dictionary](docs/data-dictionary.md) · [Evaluation criteria](docs/evaluation-criteria.md) · [Resources and inspiration](docs/resources.md)
- [ACAPS Risk List](https://www.acaps.org/en/thematics/all-topics/risk-list) (live data) · [ACAPS API](https://api.acaps.org)

## License

MIT, see [LICENSE](LICENSE). ACAPS data is used under [ACAPS' terms of use](https://www.acaps.org/en/about/terms-of-use).
