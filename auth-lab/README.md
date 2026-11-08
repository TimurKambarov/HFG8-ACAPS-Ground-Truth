# Auth Lab

A small Flutter app (Android and web) for testing invite codes, sign-up and login against the real Supabase project.
It is separate from `app/`. Use synthetic names only.

## What it tests

| Who | Signs up with | Logs in with |
|---|---|---|
| Expert | Invite code → anonymity level → real name (levels 1–2) → pseudonym + password → optional email | Pseudonym + password |
| Moderator | Moderator invite code → real name + work email + password | Email + password |

Behind the scenes, an expert's Supabase login is a made-up address `lower(pseudonym)@<login domain>`.
It never receives mail. A real email, if given, goes to `expert_contacts`, which only the expert can read.

## One-time setup (Supabase dashboard)

1. **SQL Editor:** paste and run [`../supabase/migrations/20261107000000_invite_auth.sql`](../supabase/migrations/20261107000000_invite_auth.sql).
2. **Authentication → Sign In / Providers → Email:** turn **Confirm email** off.
3. Optional, same page: set the minimum password length to 8 (the app asks for 8).

## Run

```powershell
./auth-lab/run.ps1 -Device <device>
```

The script reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` from `API.key`. The secret key is never passed to the app.

| Where | `-Device` |
|---|---|
| Android phone, wireless debugging | the phone's `IP:port`, see below |
| Web, without Chrome | `edge` |
| Let Flutter ask | leave it out |

### Android phone over wireless debugging (Android 11+)

One-time pairing:

1. Phone and PC on the same Wi-Fi.
2. Phone: **Settings → About phone →** tap **Build number** 7 times to unlock Developer options.
3. Phone: **Developer options → Wireless debugging → On**, then **Pair device with pairing code**.
   It shows an `IP:port` and a 6-digit code.
4. PC:
   ```powershell
   adb pair 192.168.1.23:37000 123456        # IP:port and code from the pairing popup
   ```
   If `adb` is "not recognized", add `%LOCALAPPDATA%\Android\sdk\platform-tools` to your user PATH
   and open a new terminal (restart VS Code for its built-in terminal).

Every session (the port changes after a restart or Wi-Fi change):

5. Phone: on the **Wireless debugging** screen, read **IP address & Port**. This port is different from the pairing port.
6. PC:
   ```powershell
   adb connect 192.168.1.23:41234
   flutter devices                             # the phone should be listed
   ./auth-lab/run.ps1 -Device 192.168.1.23:41234
   ```

The first build takes a few minutes. After that, press `r` in the terminal to hot reload and `q` to quit.
The app installs as **Auth Lab** on the phone.

## Test codes

| Code | Gives |
|---|---|
| `GT-CHAD-7Q4X` | Expert, Chad panel |
| `GT-SDN-3K9M` | Expert, Sudan panel |
| `GT-ACAPS-MOD1` | Moderator (10 uses) |

## Test list

Do step 1 first: it shows whether Supabase accepts the made-up login domain.

1. Sign up an expert, e.g. `Sahel-Owl`, level 2, no email. You should land on **Who am I**.
   If you see `email_address_invalid`, change the domain in `public.expert_login_domain()` in the
   migration, re-run it, and try again. The app reads the domain from the database.
2. Sign out, then log in with `Sahel-Owl` and the password. Try `sahel-owl` too (it works: logins ignore case).
3. Sign up another expert with pseudonym `SAHEL-OWL` → "already taken".
4. Wrong invite code → refused before the form.
5. Level 3 expert with **Add an email** on → the warning shows. Who am I: `real_name` is null and the contact email is set.
6. Moderator with `GT-ACAPS-MOD1` → logs in with email. **Profiles I can see** lists everyone.
7. On **Who am I**, press **Run all checks**. Every line should be green ("Refused, as expected").
8. Also on Who am I: Auth metadata should not contain `real_name`, `contact_email` or `invite`.

## Clean up

Authentication → Users → delete the test users. Their profiles, contacts and answers are deleted with them.
Invite use counts are not reset. To reset them:

```sql
update public.invite_codes set used_count = 0;
```
