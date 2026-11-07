# Supabase backend

## One-time setup

1. **Create the schema.** In the Supabase dashboard open **SQL Editor → New query**, paste
   [`migrations/20261106000000_init.sql`](migrations/20261106000000_init.sql) and click **Run**.
   Then do the same with [`migrations/20261107000000_invite_auth.sql`](migrations/20261107000000_invite_auth.sql).
   Both are safe to run again.
2. **Turn off "Confirm email".** Authentication → Sign In / Providers → Email. Expert logins use made-up
   addresses that cannot receive mail (see *Auth and credentials*).
3. **Load the Risk Radar data.** From the repo root:
   ```bash
   pip install -r requirements.txt
   python scripts/load_risks_to_supabase.py
   ```
   It reads `SUPABASE_URL` and `SUPABASE_SECRET_KEY` from the environment or from the
   git-ignored `API.key` file. It is safe to re-run after the CSV changes.
4. **Make a moderator.** Sign up with the moderator invite code `GT-ACAPS-MOD1` (for example in
   [`auth-lab/`](../auth-lab/README.md)). **Authentication → Users → Add user** no longer works, because
   sign-up requires an invite code.

## Tables

| Table | Contents | Who can read / write (RLS) |
|---|---|---|
| `risks` | One row per Risk Radar risk. `probability_p` (0.1–0.9) and `outcome` (true/false/null) are derived for forecasting | Everyone reads. Only the secret key writes |
| `risk_countries` | Risk ↔ country (ISO + name), split from the comma lists | Same |
| `risk_triggers` | Parsed triggers (`R1043 - T0618`), with completion rate | Same |
| `profiles` | App profile per Auth user: pseudonym (= login name, fixed), anonymity level, panels, role. Moderators are always `known_to_acaps` with a real name | Own row. Moderators read all |
| `expert_contacts` | Optional real email of an expert, for notifications | Own row only |
| `invite_codes` | Invite codes with a role (`expert` + panel country, or `moderator`). Checked with `rpc('check_invite', {invite})`; a use is counted only on sign-up | No direct access |
| `responses` | Survey answers per expert × risk × item × Delphi round: agree, likelihood 1–5, severity 1–5 | Own rows. Moderators read all |
| `comments`, `comment_votes` | "What is ACAPS missing?" input and agree/disagree votes | Signed-in users read. Authors and moderators write |
| `risk_skips` | Risks an expert skipped | Own rows |
| `activity_log` | Sign-ups and sign-ins (automatic) and any app events you insert | Own rows. Moderators read all |

Views for the forecasting model:
- `forecast_scores`: every expert forecast on a resolved risk, with its Brier score next to the ACAPS Brier score.
- `acaps_baseline_scores`: ACAPS' own Brier score per resolved risk.

## Auth and credentials

Passwords, sessions and tokens are stored by **Supabase Auth** (`auth.users`, `auth.sessions`).
Never copy them into `public` tables. Sign-up needs a valid invite code and creates the `profiles`
row automatically. The invite decides the role and the expert's home panel.

**Experts** log in with pseudonym + password. Their Auth email is made up from the pseudonym, using the
domain from `rpc('expert_login_domain')`:

```dart
final domain = await supabase.rpc('expert_login_domain');
await supabase.auth.signUp(
  email: '${pseudonym.toLowerCase()}@$domain',
  password: password,
  data: {'invite': 'GT-CHAD-7Q4X', 'pseudonym': pseudonym, 'anonymity': 'pseudonymous',
         'real_name': 'Amina Haroun', 'contact_email': 'optional@mail.org'},
);
```

**Moderators** log in with their real email + password:

```dart
await supabase.auth.signUp(email: email, password: password,
    data: {'invite': 'GT-ACAPS-MOD1', 'real_name': 'Jane Doe'});
```

`anonymity` is one of `known_to_acaps`, `pseudonymous` or `anonymous`. With `anonymous`, `real_name`
is always stored as null. `real_name`, `contact_email` and `invite` are removed from the Auth metadata
after sign-up. A contact email given by a fully anonymous expert is visible to project admins, so the
app warns about it.

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
