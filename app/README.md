# Ground Truth: Flutter prototype

A mobile-first prototype of an expert loop for ACAPS risk analysis: a sub-tool that brings quick, structured and repeated expert input to ACAPS analysts. ACAPS still makes the forecast.

Principle: individual contributions are never shown to the public.

## Flow: experts

1. **Entry with a code:** the groups are closed. There is no installed app yet, so people share **codes, not links**. A moderator creates a **personal, single-use invite code** (`GT-XXXX-XXXX`), or an expert shares their permanent **referral code** (`REF-XXXX-XXXX`). The new member types it on the start screen (**I have a code** → *Continue*; case and spaces do not matter) and goes **straight to the sign-up form** (anonymity level, name, pseudonym, password, countries, settings). An invite code is used up on sign-up; used and cancelled codes are refused with the reason. An invite records only *when* it was used, never by which account, so a fully anonymous expert cannot be traced through it. With **real accounts** (started with `run.ps1`) codes are checked by Supabase and work on any device; experts log in with pseudonym + password, moderators with email + password, and a moderator code (e.g. `GT-ACAPS-MOD1`) opens a moderator sign-up form. In **demo mode** (plain `flutter run`) codes are kept on the device, *Register with a demo code* fills one in, and *Log in* lists the synthetic demo users and the three moderators, without passwords.
2. **Anonymity levels:** 1 = known to ACAPS, 2 = known to colleagues by pseudonym, 3 = fully anonymous. A real name is only asked at levels 1 and 2; moving to level 3 deletes it (`real_name: null`). Every name in the app comes from `displayName(expert, viewer)` in `lib/identity.dart`. Levels 1 and 2 can also stay anonymous to colleagues from other countries.
3. **Survey (demo risk R1043), about 2 minutes:** a notification or pop-up (*Not now* skips it, with Undo). Then one screen per trigger (max 3) for ground truthing, not scored: agree with ACAPS (yes / partly / no), how bad it would be (1-5), what ACAPS is missing (optional). Then **one scored forecast for the whole risk**: "Will this risk materialise before [date + 6 months]?" on ACAPS's own scale with its ranges: Very low <10%, Low 10-33%, Medium 34-66%, High 67-90%, Very high >90% (from the ACAPS methodology). The last screen also asks how to be credited if ACAPS publishes the risk: real name, pseudonym or anonymous. **The default matches the anonymity level chosen in the profile** (level 1: real name, 2: pseudonym, 3: anonymous), and the expert can change it for each risk. A real name deleted at level 3 is never used.
4. **Group summary (Delphi-style):** how many answered, and for the forecast the **median** as the group answer plus the spread: "Most experts between Medium and High", "Experts agree" only when nearly all agree, and **"No clear group view: opinions split"** when the middle half of answers spans two or more steps (ACAPS's example: 1, 1, 5, 5 has a "medium" average but nobody agrees). A trend line shows how the view moved since the last update cycle ("Since 8 Oct: Medium → High · 3 of 5 experts changed their forecast"). Per trigger: agreement, how bad, and colleagues' comments with agree/disagree.
5. **Check-ins, not a snapshot:** every answer is kept as a dated check-in; changing an answer adds one instead of overwriting it.
6. **My forecasts tab:** track record (forecasts, matured, accuracy with "+7% vs ACAPS" on the same risks, total points, progress to Super estimator), open forecasts with your check-ins, *Group view* and *Change answer*, matured forecasts with what happened and the score, and what ACAPS did with your comments ("Marked useful by ACAPS", "Used in the analysis of R1048"; never which moderator).
7. **Risks tab:** the same search and **filter-and-sort** as the moderators' Risks tab (shared component in `lib/screens/risk_filter.dart`): a search box (number e.g. 1043, a word from the title, a country or a category), a filter button with a count that opens the sheet (sort: recommended for you, highest risk level, largest expected exposure, risk ID; region, country, risk type, expected priority needs, expected exposure), and "N risks · sort" with *Clear*. Moderator-only options are hidden for experts. **Categories** are ACAPS's own values from the Risk Radar export, as on the ACAPS website: risk type (New emerging risk, Marked deterioration in an existing crisis, Future impact of a hazard which has already taken place), expected priority needs (Food security, Protection, Livelihoods, Health, WASH, Displacement, Humanitarian access, Shelter, Education, Nutrition) and expected exposure (<20,000 to >500,000 people). They show as chips on risk cards and pages; risks where ACAPS did not record them show none. The search and lists cover across active risks and the **Archive · see what happened**: every closed risk, read-only (no new answers, no points). The 7 risks with no recorded status in the export are not shown.
8. **Invite a colleague (Profile):** every expert has one **permanent referral code** (`REF-XXXX-XXXX`, from the server for real accounts) that any number of trusted colleagues can join with: *Copy code* or *Copy invitation message* ("Join Ground Truth with my code: REF-…"). The inviter gets **+100 points** per colleague who **signs up** with it, sees how many joined, and follows each colleague's **progress** in three stages: joined → answered a first risk → answered 3 risks. Only the stage is shown ("Colleague 1: answered 1 of 3 risks"), never a name, pseudonym, answers or comments, and new members are told this on the profile form. For real accounts the server only knows *when* each colleague joined (answers are still local), so those rows show "Joined <date>". The new member does not see who invited them. Moderators see the count on each expert's sheet. **Referral Master** badge: 3 or more experts joined with your code. Demo: Harmattan-17 has three referrals (one fully active, one part way, one just joined) and the badge.
9. **Rating (opt-in):** accuracy = 100 × (1 − Brier) per matured forecast, scored at the middle of the chosen ACAPS range (5 / 20 / 50 / 80 / 95%). +25 for a comment marked useful, +50 for a comment used in another risk's analysis, +100 for each colleague who signs up with your referral code. "Bar to beat": ACAPS's own ratings scored the same way. Risks from ACAPS's earlier risk list (IDs below R1000) resolved over longer than 6 months; they are labelled and their scores are indicative.

## Flow: moderators

Separate named accounts with equal rights (Sarah Okafor, Tomás Lindqvist, Mei Tanaka). Actions on comments are signed; only moderators see who did what. `?tab=inbox|risks|comments|experts|profile` opens a tab.

- **Inbox:** countries that need experts (none yet, or fewer than 3); then new comments to review. The badge counts new comments only.
- **Invites:** the key button in the top bar creates a new single-use code straight away (no country: the expert chooses theirs when creating their profile). *Copy code*, *Copy invitation message*, *Another code*, and an optional "who is it for" note visible to moderators only. The list shows open, used and cancelled codes; open ones can be cancelled. With a real moderator account the codes are created, listed, annotated and cancelled on the server (`create_invite`, `list_invites`, `set_invite_note`, `revoke_invite`).
- **Risks:** search (ID, title, country or category), Active / Archive / All, and a filter sheet (region, country, **risk type, expected priority needs, expected exposure**, comments to review, **experts split**, disagreement with ACAPS; sorts include **biggest change in expert view**, **experts most split** and **largest expected exposure**). Risk cards and pages show the categories as chips; the New risk form picks them from ACAPS's lists. A risk page shows ACAPS's assessment, the experts' forecast (group answer, spread, trend), every trigger in full, and the analysis texts. *New risk* opens a form.
- **Expert input:** exports aggregated expert input for ACAPS's own systems as JSON (schema `acaps-ground-truth/expert-input/v3`). Risk fields use the Risk Radar export / API names (`Risk ID`, `Risk Title`, `Risk Type`, `ISO`, `Country`, `Probability`, `Impact`, `Risk Level`, `Risk trend`, `Status`), plus an `expert_input` block: forecast distribution, median, middle half, `opinions_split`, trend, per-trigger agreement and severity, and optionally contributors who opted in. No comments, no respondent countries, no names next to answers; nothing below 3 respondents.
- **Comments:** review what experts say ACAPS is missing, trigger by trigger: *Useful*, *Used in another risk*, *Mark reviewed*.
- **Experts:** everyone, by country, sorted by points, accuracy, answers or name, with the raw database record. **Trust signals** (moderators only, never shown to colleagues or the expert): how they got in, **Invited by ACAPS** (moderator's single-use code) or **Referred by an expert** (a member's referral code, without naming who), and what they do, **New** (fewer than 3 risks answered), **Active** (3+), **Established** (3+ and a comment marked useful or used, or 70%+ accuracy over 3+ matured forecasts). Filter by how experts joined; the same pills show next to each comment's author in the Comments tab. Neither signal says who someone is, so anonymity is kept.
- **Profile:** activity and display settings per account.

## Demo data

Risks, ACAPS ratings and outcomes are real (the Risk Radar export in `assets/`). All experts and their answers are synthetic and simulated deterministically from the ACAPS rating plus a per-expert "skill". Two storylines are fixed so the demo tells a clear story: **R1043** moves from Medium to High after ACAPS's 30 Sep 2026 update, and **R1049** has a split panel. Everything is saved on the device (`shared_preferences`); **Profile → Reset demo** wipes it. A shared database replaces this for a pilot.

Accounts, invite codes and referrals are in Supabase when started with `run.ps1`; answers, comments and points are still local. Not done yet: a shared backend for answers and comments (so referral progress and pilot rules can be checked on the server), a vetting step for referred experts (suggested by ACAPS), real push notifications, the live ACAPS API, translations, AI support for moderators.

## Run

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.22 or newer).

```bash
cd app
flutter pub get
flutter run -d edge        # demo mode: synthetic users, codes on this device
flutter test
dart run tool/identity_check.dart   # anonymity rules, runs without the Flutter test device
```

### Real accounts (Supabase)

Set up the database once (see [`../supabase/README.md`](../supabase/README.md): run the three migrations in order, turn off
"Confirm email"). Then start the app with the keys from the git-ignored `../API.key`:

```powershell
./app/run.ps1 -Device edge          # or a phone id from `flutter devices`
```

`run.ps1` passes only `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`; the secret key never goes into the app.

- **First moderator:** *I have a code* → `GT-ACAPS-MOD1` → name, work email, password.
- **Invite an expert:** as moderator, the key button → *Copy invitation message* → send it. The expert types the code, fills in
  the form with a password, and is in. Their own referral code is on their Profile.
- **Log in later:** *Log in* → pseudonym (experts) or email (moderators) + password.
- Without the keys the app runs in demo mode, as before.

On an Android phone (USB or wireless debugging), use `flutter devices` to find its id and run `flutter run -d <device-id>`. The phone version in `../app-mobile` uses a different application ID, so both can be installed at the same time. In VS Code, the *Run and Debug* panel has a launch configuration for each app (`.vscode/launch.json`).

On Windows, building for the Windows desktop target needs Developer Mode, because of plugin symlinks. The web target doesn't.

`flutter create .` only generates the missing platform folders. It does not overwrite `lib/`.
