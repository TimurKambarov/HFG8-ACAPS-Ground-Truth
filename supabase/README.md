# Supabase backend

## One-time setup

1. **Create the schema.** In the Supabase dashboard open **SQL Editor → New query**, paste
   [`migrations/20261106000000_init.sql`](migrations/20261106000000_init.sql) and click **Run**.
   It is safe to run again.
2. **Load the Risk Radar data.** From the repo root:
   ```bash
   pip install -r requirements.txt
   python scripts/load_risks_to_supabase.py
   ```
   It reads `SUPABASE_URL` and `SUPABASE_SECRET_KEY` from the environment or from the
   git-ignored `API.key` file. It is safe to re-run after the CSV changes.
3. **Make a moderator.** Sign up a user in the app (or via **Authentication → Users → Add user**),
   then run in the SQL Editor:
   ```sql
   update public.profiles set role = 'moderator' where id = '<user uuid>';
   ```

## Tables

| Table | Contents | Who can read / write (RLS) |
|---|---|---|
| `risks` | One row per Risk Radar risk. `probability_p` (0.1–0.9) and `outcome` (true/false/null) are derived for forecasting | Everyone reads. Only the secret key writes |
| `risk_countries` | Risk ↔ country (ISO + name), split from the comma lists | Same |
| `risk_triggers` | Parsed triggers (`R1043 - T0618`), with completion rate | Same |
| `profiles` | App profile per Auth user: pseudonym, anonymity level, panels, role | Own row. Moderators read all |
| `invite_codes` | Panel invite codes, used through `rpc('redeem_invite', {invite})` | No direct access |
| `responses` | Survey answers per expert × risk × item × Delphi round: agree, likelihood 1–5, severity 1–5 | Own rows. Moderators read all |
| `comments`, `comment_votes` | "What is ACAPS missing?" input and agree/disagree votes | Signed-in users read. Authors and moderators write |
| `risk_skips` | Risks an expert skipped | Own rows |
| `activity_log` | Sign-ups and sign-ins (automatic) and any app events you insert | Own rows. Moderators read all |

Views for the forecasting model:
- `forecast_scores`: every expert forecast on a resolved risk, with its Brier score next to the ACAPS Brier score.
- `acaps_baseline_scores`: ACAPS' own Brier score per resolved risk.

## Auth and credentials

Passwords, sessions and tokens are stored by **Supabase Auth** (`auth.users`, `auth.sessions`).
Never copy them into `public` tables. Signing up creates the `profiles` row automatically.
Pass the profile fields as metadata:

```dart
await supabase.auth.signUp(
  email: email,
  password: password,
  data: {'pseudonym': 'Sahel-Owl', 'anonymity': 'pseudonymous', 'home_country': 'Chad', 'interests': ['Sudan']},
);
```

`anonymity` is one of `known_to_acaps`, `pseudonymous` or `anonymous`. With `anonymous`, `real_name`
is always stored as null. The email in `auth.users` stays visible to project admins, so fully
anonymous experts should sign up with a throwaway address or with Supabase anonymous sign-in.

## Keys

- **Publishable key** (`sb_publishable_…`): safe to ship in the Flutter app. RLS applies.
- **Secret key** (`sb_secret_…`): bypasses RLS. Use it only in scripts and servers. Never put it in the app or in git.

## Reading the data for modelling (Python)

```python
import requests
from scripts.load_risks_to_supabase import credentials
url, key = credentials()
h = {"apikey": key, "Authorization": f"Bearer {key}"}
risks = requests.get(f"{url}/rest/v1/risks", params={"select": "*"}, headers=h).json()
scores = requests.get(f"{url}/rest/v1/forecast_scores", params={"select": "*"}, headers=h).json()
```
