# CLAUDE.md — auth-lab

Context for AI assistants and developers continuing work on **auth-lab**: a small Flutter app
(Android + web) that tests invite codes, sign-up and login against the real Supabase project.
It is deliberately separate from `../app/` and `../app-mobile/` (those are local demo apps with
no Supabase connection yet). Human-facing setup and test steps are in [README.md](README.md).

Status as of 2026-11-07: working on a real phone over wireless debugging. Nothing is committed to git yet.

## Files

| File | What it holds |
|---|---|
| `lib/lab.dart` | All Supabase calls and rules: login-email mapping, `checkInvite`, `signUpExpert`, `signUpModerator`, `logIn`, the no-invite probe, and `explain()` (error → sentence + raw code) |
| `lib/screens.dart` | Start, Invite code, Expert sign-up, Moderator sign-up, Log in |
| `lib/whoami.dart` | Signed-in view: Auth user + metadata, own profile row, own contact row, profiles visible under RLS, activity log, and the **Rule checks** (each must be refused by the database) |
| `lib/main.dart` | Init, theme (`#1F5A7A`, same as the main app), auth gate, "Setup needed" screen |
| `run.ps1` | Launcher. Reads only `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` from `../API.key` and passes them as `--dart-define`. Optional `-Device <id>` |
| `../supabase/migrations/20261107000000_invite_auth.sql` | The server-side half of everything below |

## How auth works (decided with the user, do not change without asking)

| Who | Signs up with | Logs in with |
|---|---|---|
| Expert | Invite code → anonymity level 1/2/3 → real name (levels 1–2 only) → pseudonym + password → optional contact email | Pseudonym + password |
| Moderator | Moderator invite code → real name + work email + password | Email + password |

- **Made-up login email for experts.** Supabase Auth only does email/phone + password, so an expert's
  Auth email is `lower(pseudonym)@<domain>`, with the domain from `rpc('expert_login_domain')` (currently
  `gt-experts.invalid`, which Supabase accepted). The app never hard-codes the domain. Login field
  "Pseudonym or email": contains `@` → email, else pseudonym → made-up address.
- **Optional real email** goes to `public.expert_contacts` (owner-only RLS), not `profiles`, because
  moderators can read all profiles and an email would identify pseudonymous experts.
- **Level 3 (fully anonymous) + email:** allowed, but the app shows a warning (user's choice). Email stays optional.
- **Moderators** come only from moderator invite codes (`role = 'moderator'` on `invite_codes`).
  They are always `known_to_acaps` with a real name (DB constraint `moderator_is_named`).
- **Pseudonym = login name, so it is fixed after sign-up.** Format `^[A-Za-z0-9][A-Za-z0-9_-]{2,29}$`,
  unique case-insensitively. This rule is mirrored in `../app/` and `../app-mobile/`
  (`identity.dart` → `pseudonymPattern`, profile pseudonym field read-only).
- **No forgot-password flow** yet (out of scope for now).

## Server-side rules (in the migration)

- `handle_new_user()` trigger on `auth.users` is the only gate: it validates and counts the invite,
  sets role and home panel from the invite, checks the expert email matches the pseudonym, writes
  `profiles` / `expert_contacts` / `activity_log ('sign_up')`, then strips `real_name`,
  `contact_email`, `invite` from Auth metadata. Any `raise` aborts the sign-up.
- `check_invite(invite)` is read-only (role + panel) and does not count a use. The old
  `redeem_invite()` was dropped.
- `revoke update (pseudonym)` for `authenticated`. Users also cannot change `role` / `simulated`.
- Consequence: **Authentication → Add user** in the dashboard no longer works (no invite metadata).
  Create test users through auth-lab or the Auth API with an `invite` in the metadata.

## Supabase project state (checked 2026-11-07)

- Both migrations applied. **Confirm email is OFF** (required). Sign-ups enabled.
- `risks` holds 139 rows (Risk Radar loaded).
- Invite codes: `GT-CHAD-7Q4X` (Chad, 3 uses), `GT-SDN-3K9M` (Sudan, 0), `GT-ACAPS-MOD1` (moderator, 1 of 10).
- Test users: 3 Chad experts (one per anonymity level) + 1 moderator. All synthetic.
- `expert_contacts` is empty: **the "expert adds an email" path has not been tested yet.**

## Test results so far

- Expert sign-up and login by pseudonym: works.
- Moderator sign-up and login by email: works.
- Rule checks on Who am I: all green after the probe fix below.
- Sign-up without an invite, sent directly to the Auth API, returns
  `500 {"code":"P0001","message":"invite_invalid: ..."}`. Note that the trigger's message comes
  through, not only "Database error saving new user"; `explain()` handles both.

Still to test: expert with contact email (incl. the level-3 warning), `SAHEL-OWL` vs `Sahel-Owl`
clash, Sudan code, expired / used-up codes (`update invite_codes set max_uses = …`).

## Gotchas already hit (don't repeat)

- **Throwaway `SupabaseClient` + PKCE:** a bare `SupabaseClient` defaults to the PKCE flow and asserts
  "You need to provide asyncStorage to perform pkce flow". The no-invite probe uses
  `AuthFlowType.implicit` for this reason.
- **`$args` in PowerShell is reserved.** `run.ps1` uses `$flutterArgs`. Calling `flutter @args`
  silently passes nothing and Flutter prints its help text.
- **`run.ps1` paths:** `./auth-lab/run.ps1` only works from the repo root. The script itself uses
  `Push-Location $PSScriptRoot`, so it works from anywhere when called by full path.
- **adb:** it lives in `%LOCALAPPDATA%\Android\sdk\platform-tools`. That folder was added to the user
  PATH; terminals (and VS Code) must be restarted to see it.
- **No Chrome on the dev machine.** Use the Android phone (`-Device <IP:port>` from `flutter devices`)
  or `-Device edge` for web. The wireless port changes after a phone restart or Wi-Fi change.
- **Flutter text fields have no `id` parameter** (an HTML habit, caused analyzer errors once).
- `Supabase.initialize` takes `publishableKey:` (`anonKey:` is deprecated in supabase_flutter 2.18).

## Conventions

- Only the **publishable** key in the app. The secret key (in git-ignored `../API.key`) is for
  Python scripts only, e.g. `scripts/load_risks_to_supabase.py` → `credentials()`.
- Synthetic users only (repo rule, see `../CLAUDE.md`).
- Schema changes go in a **new** migration file in `../supabase/migrations/`, written to be safe to re-run.
  Update `../supabase/README.md` when tables or auth behaviour change.
- Run `flutter analyze` in `auth-lab/`, `app/` and `app-mobile/` after changes. All three are clean now.

## Likely next steps

- Finish the untested cases above.
- **Login** is wired into `../app-mobile/` (`lib/auth.dart`, `LoginScreen` in `lib/screens/entry.dart`,
  started with `app-mobile/run.ps1`). Invite / sign-up for experts and moderators is not wired in yet
  (the user asked for login only; ask before adding it).
- Forgot-password: needs the contact email (experts) or real email (moderators) and an email
  provider; not designed yet.
- Clean-up of test users: Authentication → Users → delete (cascades), then
  `update public.invite_codes set used_count = 0;`.
