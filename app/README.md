# Ground Truth: Flutter prototype

A mobile-first prototype of an expert loop for ACAPS risk analysis: a sub-tool that brings quick, structured and repeated expert input to ACAPS analysts. ACAPS still makes the forecast.

Principle: individual contributions are never shown to the public.

## Flow: experts

1. **Entry by invite link:** the groups are closed. A moderator creates a **personal, single-use invite link**; opening it (the app starts with `?invite=<token>`) is the only way for a new member to get in, and the link is used up when the person creates their profile. There is deliberately no field to paste links or codes into. Opening a new link signs out whoever was signed in on that device. Used and cancelled links are refused. An invite records only *when* it was used, never by which account, so a fully anonymous expert cannot be traced through it. A valid link goes **straight to the profile form** (anonymity level, name, pseudonym, countries, settings). The start screen has *Register* (in the demo: opens one of the seeded invite links, then the profile form) and *Log in* for existing members: the demo users and the three moderators, without a password in the MVP.
2. **Anonymity levels:** 1 = known to ACAPS, 2 = known to colleagues by pseudonym, 3 = fully anonymous. A real name is only asked at levels 1 and 2; moving to level 3 deletes it (`real_name: null`). Every name in the app comes from `displayName(expert, viewer)` in `lib/identity.dart`. Levels 1 and 2 can also stay anonymous to colleagues from other countries.
3. **Survey (demo risk R1043), about 2 minutes:** a notification or pop-up (*Not now* skips it, with Undo). Then one screen per trigger (max 3) for ground truthing, not scored: agree with ACAPS (yes / partly / no), how bad it would be (1-5), what ACAPS is missing (optional). Then **one scored forecast for the whole risk**: "Will this risk materialise before [date + 6 months]?" on ACAPS's own scale with its ranges: Very low <10%, Low 10-33%, Medium 34-66%, High 67-90%, Very high >90% (from the ACAPS methodology). The last screen also asks how to be credited if ACAPS publishes the risk: real name, pseudonym or anonymous. **The default matches the anonymity level chosen in the profile** (level 1: real name, 2: pseudonym, 3: anonymous), and the expert can change it for each risk. A real name deleted at level 3 is never used.
4. **Group summary (Delphi-style):** how many answered, and for the forecast the **median** as the group answer plus the spread: "Most experts between Medium and High", "Experts agree" only when nearly all agree, and **"No clear group view: opinions split"** when the middle half of answers spans two or more steps (ACAPS's example: 1, 1, 5, 5 has a "medium" average but nobody agrees). A trend line shows how the view moved since the last update cycle ("Since 8 Oct: Medium → High · 3 of 5 experts changed their forecast"). Per trigger: agreement, how bad, and colleagues' comments with agree/disagree.
5. **Check-ins, not a snapshot:** every answer is kept as a dated check-in; changing an answer adds one instead of overwriting it.
6. **My forecasts tab:** track record (forecasts, matured, accuracy with "+7% vs ACAPS" on the same risks, total points, progress to Super estimator), open forecasts with your check-ins, *Group view* and *Change answer*, matured forecasts with what happened and the score, and what ACAPS did with your comments ("Marked useful by ACAPS", "Used in the analysis of R1048"; never which moderator).
7. **Risks tab:** a search box finds risks by number (e.g. 1043), a word from the title, or a country, like the moderators' search, across active risks and the **Archive · see what happened**: every closed risk, read-only (no new answers, no points). The 7 risks with no recorded status in the export are not shown.
8. **Invite a colleague (Profile):** every expert has one **permanent referral link** (`?invite=REF-…`) that any number of trusted colleagues can join with; it goes straight to the profile form. The inviter gets **+100 points** per colleague who joins (demo: on registration; pilot: once they have answered at least 3 risks, as noted in the app), sees how many joined, and follows each colleague's **progress** in three stages: joined → answered a first risk → answered 3 risks. Only the stage is shown ("Colleague 1: answered 1 of 3 risks"), never a name, pseudonym, answers or comments, and new members are told this on the profile form. The new member does not see who invited them. Moderators see the count on each expert's sheet. **Referral Master** badge: 3 or more experts joined with your link. Demo: Harmattan-17 has three referrals (one fully active, one part way, one just joined) and the badge.
9. **Rating (opt-in):** accuracy = 100 × (1 − Brier) per matured forecast, scored at the middle of the chosen ACAPS range (5 / 20 / 50 / 80 / 95%). +25 for a comment marked useful, +50 for a comment used in another risk's analysis, +100 for each colleague who joins with your referral link. "Bar to beat": ACAPS's own ratings scored the same way. Risks from ACAPS's earlier risk list (IDs below R1000) resolved over longer than 6 months; they are labelled and their scores are indicative.

## Flow: moderators

Separate named accounts with equal rights (Sarah Okafor, Tomás Lindqvist, Mei Tanaka). Actions on comments are signed; only moderators see who did what. `?tab=inbox|risks|comments|experts|profile` opens a tab.

- **Inbox:** countries that need experts (none yet, or fewer than 3); then new comments to review. The badge counts new comments only.
- **Invites:** the link button in the top bar generates a new single-use link straight away (no country: the expert chooses theirs when creating their profile). *Copy link*, *Copy invitation message*, *Another link*, and an optional "who is it for" note visible to moderators only. The list shows open, used and cancelled links; open ones can be cancelled.
- **Risks:** search, Active / Archive / All, and a filter sheet (region, country, comments to review, **experts split**, disagreement with ACAPS; sorts include **biggest change in expert view** and **experts most split**). A risk page shows ACAPS's assessment, the experts' forecast (group answer, spread, trend), every trigger in full, and the analysis texts. *New risk* opens a form.
- **Expert input:** exports aggregated expert input for ACAPS's own systems as JSON (schema `acaps-ground-truth/expert-input/v3`). Risk fields use the Risk Radar export / API names (`Risk ID`, `Risk Title`, `Risk Type`, `ISO`, `Country`, `Probability`, `Impact`, `Risk Level`, `Risk trend`, `Status`), plus an `expert_input` block: forecast distribution, median, middle half, `opinions_split`, trend, per-trigger agreement and severity, and optionally contributors who opted in. No comments, no respondent countries, no names next to answers; nothing below 3 respondents.
- **Comments:** review what experts say ACAPS is missing, trigger by trigger: *Useful*, *Used in another risk*, *Mark reviewed*.
- **Experts:** everyone, by country, sorted by points, accuracy, answers or name, with the raw database record. **Trust signals** (moderators only, never shown to colleagues or the expert): how they got in, **Invited by ACAPS** (moderator's single-use link) or **Referred by an expert** (a member's referral link, without naming who), and what they do, **New** (fewer than 3 risks answered), **Active** (3+), **Established** (3+ and a comment marked useful or used, or 70%+ accuracy over 3+ matured forecasts). Filter by how experts joined; the same pills show next to each comment's author in the Comments tab. Neither signal says who someone is, so anonymity is kept.
- **Profile:** activity and display settings per account.

## Demo data

Risks, ACAPS ratings and outcomes are real (the Risk Radar export in `assets/`). All experts and their answers are synthetic and simulated deterministically from the ACAPS rating plus a per-expert "skill". Two storylines are fixed so the demo tells a clear story: **R1043** moves from Medium to High after ACAPS's 30 Sep 2026 update, and **R1049** has a split panel. Everything is saved on the device (`shared_preferences`); **Profile → Reset demo** wipes it. A shared database replaces this for a pilot.

Not done yet: a shared backend (server-side checks of invite and referral links and anonymity), a vetting step for referred experts (suggested by ACAPS), the pilot rule for referral points (after 3 answered risks), passwords, real push notifications, the live ACAPS API, translations, AI support for moderators.

## Run

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.22 or newer).

```bash
cd app
flutter pub get
flutter run -d edge        # or -d chrome, or an Android emulator / device
flutter test
dart run tool/identity_check.dart   # anonymity rules, runs without the Flutter test device
```

On Windows, building for the Windows desktop target needs Developer Mode, because of plugin symlinks. The web target doesn't.

`flutter create .` only generates the missing platform folders. It does not overwrite `lib/`.
