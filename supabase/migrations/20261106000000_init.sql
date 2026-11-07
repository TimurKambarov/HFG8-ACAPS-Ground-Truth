-- =============================================================================
-- ACAPS Ground Truth — initial schema
--
-- Run once: Supabase dashboard -> SQL Editor -> paste this file -> Run.
-- (Or, with the Supabase CLI linked to the project: `supabase db push`.)
-- Safe to re-run: every object is created with IF NOT EXISTS / OR REPLACE.
--
-- Layout
--   Reference data (loaded by scripts/load_risks_to_supabase.py, read-only for users)
--     risks, risk_countries, risk_triggers
--   Users (passwords / sessions live in Supabase Auth: auth.users — never here)
--     profiles, invite_codes
--   Expert input (ground truthing + forecasting)
--     responses, comments, comment_votes, risk_skips
--   Logging
--     activity_log   (+ automatic 'sign_in' / 'sign_up' rows from Auth)
--   Views for the forecasting model
--     forecast_scores, acaps_baseline_scores
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Reference data: ACAPS Risk Radar export
-- -----------------------------------------------------------------------------

create table if not exists public.risks (
  risk_id                    text primary key,                 -- 'R1043'
  title                      text not null,
  risk_type                  text check (risk_type in (
                               'New emerging risk',
                               'Marked deterioration in an existing crisis',
                               'Future impact of a hazard which has already taken place')),
  iso                        text,                             -- raw, may be 'TCD, SDN'
  country                    text,                             -- raw, may be 'Chad, Sudan'
  rationale                  text,
  source                     text,
  intensity_of_hazard        smallint check (intensity_of_hazard between 1 and 5),
  impact                     smallint check (impact between 1 and 5),
  probability                text check (probability in ('Very Low','Low','Medium','High','Very High')),
  -- ACAPS probability on the 0.1..0.9 scale the app uses for Brier scoring
  probability_p              numeric(3,2) generated always as (
                               case probability
                                 when 'Very Low'  then 0.1 when 'Low'       then 0.3
                                 when 'Medium'    then 0.5 when 'High'      then 0.7
                                 when 'Very High' then 0.9 end) stored,
  risk_level                 text check (risk_level in ('Low','Medium','High')),
  risk_trend                 text check (risk_trend in ('Improved','Stable','Deteriorated')),
  status                     text check (status in ('Active','Materialised','Not materialised')),
  -- forecasting target: true / false once resolved, null while active or unknown
  outcome                    boolean generated always as (
                               case status when 'Materialised' then true
                                           when 'Not materialised' then false end) stored,
  what_materialised          text check (what_materialised in ('Hazard','Impact','Hazard and impact')),
  hazard_materialisation     text,
  materialisation_sources    text,
  triggers_raw               text,                             -- original structured text
  vulnerability              text,                             -- 'Current vulnerability / Coping capacities'
  vulnerability_sources      text,
  expected_exposure          text check (expected_exposure in (
                               '<20,000','20,000-100,000','100,000-250,000','250,000-500,000','>500,000')),
  expected_impact            text,
  expected_impact_sources    text,
  expected_priority_needs    text[] not null default '{}',
  impact_materialisation_description text,
  rationale_update           text,
  imported_at                timestamptz not null default now()
);

create index if not exists risks_status_idx on public.risks (status);

-- One row per country a risk covers (ISO and Country are parallel comma lists).
create table if not exists public.risk_countries (
  risk_id  text not null references public.risks (risk_id) on delete cascade,
  iso      text not null,
  country  text not null,
  primary key (risk_id, iso)
);
create index if not exists risk_countries_country_idx on public.risk_countries (country);

-- Parsed 'Triggers' field. trigger_id looks like 'R1043 - T0618'.
create table if not exists public.risk_triggers (
  trigger_id       text primary key,
  risk_id          text not null references public.risks (risk_id) on delete cascade,
  position         smallint not null,                          -- order within the risk
  title            text,
  description      text,
  completion_rate  smallint check (completion_rate between 0 and 100),
  raw              text
);
create index if not exists risk_triggers_risk_idx on public.risk_triggers (risk_id);

-- -----------------------------------------------------------------------------
-- Users
-- Credentials are handled by Supabase Auth (auth.users, auth.sessions).
-- profiles holds only app data, keyed by the auth user id.
-- -----------------------------------------------------------------------------

do $$ begin
  create type public.anonymity_level as enum ('known_to_acaps', 'pseudonymous', 'anonymous');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.user_role as enum ('expert', 'moderator');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id                        uuid primary key references auth.users (id) on delete cascade,
  role                      public.user_role not null default 'expert',
  pseudonym                 text not null unique,
  real_name                 text,                -- always null when anonymity = 'anonymous'
  anonymity                 public.anonymity_level not null default 'pseudonymous',
  home_country              text,
  interests                 text[] not null default '{}',   -- extra panels besides home_country
  on_rating                 boolean not null default true,  -- appears on the super-estimator board
  notifications             boolean not null default true,
  hide_from_other_countries boolean not null default false,
  simulated                 boolean not null default false, -- synthetic demo expert
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  constraint anonymous_has_no_name check (anonymity <> 'anonymous' or real_name is null)
);

-- Level 3 anonymity deletes the real name instead of rejecting the update.
create or replace function public.profiles_before_write()
returns trigger language plpgsql as $$
begin
  if new.anonymity = 'anonymous' then new.real_name := null; end if;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists profiles_before_write on public.profiles;
create trigger profiles_before_write before insert or update on public.profiles
  for each row execute function public.profiles_before_write();

-- Invite codes handed out by ACAPS (QR codes). Redeemed through redeem_invite().
create table if not exists public.invite_codes (
  code           text primary key,
  panel_country  text not null,
  max_uses       int,                 -- null = unlimited
  used_count     int not null default 0,
  expires_at     timestamptz,
  created_at     timestamptz not null default now()
);

insert into public.invite_codes (code, panel_country) values
  ('GT-CHAD-7Q4X', 'Chad'),
  ('GT-SDN-3K9M',  'Sudan')
on conflict (code) do nothing;

-- -----------------------------------------------------------------------------
-- Expert input
-- -----------------------------------------------------------------------------

-- One answer per expert, risk, survey item and Delphi round.
-- item_id is a trigger id ('R1043 - T0618') or 'risk' when the risk has no triggers.
create table if not exists public.responses (
  id            bigint generated always as identity primary key,
  expert_id     uuid not null references public.profiles (id) on delete cascade,
  risk_id       text not null references public.risks (risk_id) on delete cascade,
  item_id       text not null,
  round         smallint not null default 1,
  agree         text not null check (agree in ('yes', 'partly', 'no')),
  likelihood    smallint not null check (likelihood between 1 and 5),
  severity      smallint not null check (severity between 1 and 5),
  -- same 0.1..0.9 mapping as the app (likelihoodProbs)
  likelihood_p  numeric(3,2) generated always as (likelihood * 0.2 - 0.1) stored,
  missing       text not null default '',
  simulated     boolean not null default false,
  answered_at   timestamptz not null default now(),
  edited_at     timestamptz,
  unique (expert_id, risk_id, item_id, round)
);
create index if not exists responses_risk_idx on public.responses (risk_id);

-- "What is ACAPS missing?" contributions.
create table if not exists public.comments (
  id               uuid primary key default gen_random_uuid(),
  risk_id          text not null references public.risks (risk_id) on delete cascade,
  item_id          text not null,
  author_id        uuid references public.profiles (id) on delete set null,
  text             text not null,
  useful           boolean not null default false,   -- set by moderators
  used_in_risk_id  text references public.risks (risk_id) on delete set null,
  reviewed         boolean not null default false,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index if not exists comments_risk_idx on public.comments (risk_id);

create table if not exists public.comment_votes (
  comment_id  uuid not null references public.comments (id) on delete cascade,
  voter_id    uuid not null references public.profiles (id) on delete cascade,
  vote        smallint not null check (vote in (-1, 1)),   -- 1 agree, -1 disagree
  created_at  timestamptz not null default now(),
  primary key (comment_id, voter_id)
);

create table if not exists public.risk_skips (
  expert_id   uuid not null references public.profiles (id) on delete cascade,
  risk_id     text not null references public.risks (risk_id) on delete cascade,
  skipped_at  timestamptz not null default now(),
  primary key (expert_id, risk_id)
);

-- -----------------------------------------------------------------------------
-- Activity log (sign-ins, survey submissions, edits, moderator actions, ...)
-- -----------------------------------------------------------------------------

create table if not exists public.activity_log (
  id          bigint generated always as identity primary key,
  user_id     uuid references auth.users (id) on delete set null,
  event       text not null,          -- 'sign_in', 'sign_up', 'survey_submit', 'comment_review', ...
  risk_id     text,
  details     jsonb not null default '{}',
  created_at  timestamptz not null default now()
);
create index if not exists activity_log_user_idx  on public.activity_log (user_id, created_at desc);
create index if not exists activity_log_event_idx on public.activity_log (event, created_at desc);

-- -----------------------------------------------------------------------------
-- Auth hooks: create a profile on sign-up, log every sign-in.
-- Sign-up metadata (options.data in supabase.auth.signUp) may carry:
--   pseudonym, real_name, anonymity, home_country, interests (array)
-- -----------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare m jsonb := coalesce(new.raw_user_meta_data, '{}');
begin
  insert into public.profiles (id, pseudonym, real_name, anonymity, home_country, interests)
  values (
    new.id,
    coalesce(nullif(m->>'pseudonym', ''), 'Expert-' || substr(replace(new.id::text, '-', ''), 1, 6)),
    nullif(m->>'real_name', ''),
    coalesce((m->>'anonymity')::public.anonymity_level, 'pseudonymous'),
    nullif(m->>'home_country', ''),
    case when jsonb_typeof(m->'interests') = 'array'
         then array(select jsonb_array_elements_text(m->'interests')) else '{}' end
  );
  insert into public.activity_log (user_id, event) values (new.id, 'sign_up');
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- A new auth session = a sign-in. Never block the sign-in if logging fails.
create or replace function public.log_sign_in()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  begin
    insert into public.activity_log (user_id, event, details)
    values (new.user_id, 'sign_in', jsonb_build_object('aal', new.aal, 'user_agent', new.user_agent));
  exception when others then null;
  end;
  return new;
end $$;

-- Wrapped so the rest of the migration still runs if the auth schema refuses the trigger.
do $$ begin
  drop trigger if exists on_auth_session_created on auth.sessions;
  create trigger on_auth_session_created after insert on auth.sessions
    for each row execute function public.log_sign_in();
exception when others then
  raise notice 'Sign-in trigger not installed (%). Log sign-ins from the app instead.', sqlerrm;
end $$;

-- -----------------------------------------------------------------------------
-- Helper functions
-- -----------------------------------------------------------------------------

create or replace function public.is_moderator()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'moderator');
$$;

-- Returns the panel country for a valid invite code (and counts the use), else null.
create or replace function public.redeem_invite(invite text)
returns text language plpgsql security definer set search_path = '' as $$
declare c text;
begin
  update public.invite_codes
     set used_count = used_count + 1
   where code = upper(trim(invite))
     and (expires_at is null or expires_at > now())
     and (max_uses is null or used_count < max_uses)
  returning panel_country into c;
  return c;
end $$;

-- -----------------------------------------------------------------------------
-- Row level security
-- The secret / service-role key bypasses RLS (used by the loader and backend jobs).
-- -----------------------------------------------------------------------------

-- Explicit table privileges (RLS below narrows them to rows).
grant usage on schema public to anon, authenticated, service_role;
grant all on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;
grant select on public.risks, public.risk_countries, public.risk_triggers to anon, authenticated;
grant select, insert, update, delete on public.responses, public.comments, public.comment_votes,
  public.risk_skips to authenticated;
grant select, insert on public.activity_log to authenticated;
grant select on public.profiles to authenticated;
revoke all on public.invite_codes from anon, authenticated;
grant execute on function public.redeem_invite(text) to anon, authenticated;
grant execute on function public.is_moderator() to authenticated;

alter table public.risks          enable row level security;
alter table public.risk_countries enable row level security;
alter table public.risk_triggers  enable row level security;
alter table public.profiles       enable row level security;
alter table public.invite_codes   enable row level security;  -- no policies: only via redeem_invite()
alter table public.responses      enable row level security;
alter table public.comments       enable row level security;
alter table public.comment_votes  enable row level security;
alter table public.risk_skips     enable row level security;
alter table public.activity_log   enable row level security;

-- Risk data: readable by everyone (the app has a public view), writable by nobody but the service key.
drop policy if exists "risks readable" on public.risks;
create policy "risks readable" on public.risks for select to anon, authenticated using (true);
drop policy if exists "risk_countries readable" on public.risk_countries;
create policy "risk_countries readable" on public.risk_countries for select to anon, authenticated using (true);
drop policy if exists "risk_triggers readable" on public.risk_triggers;
create policy "risk_triggers readable" on public.risk_triggers for select to anon, authenticated using (true);

-- Profiles: you see and edit your own; moderators see all.
-- Peers' names should go through a view that applies the anonymity rules, not this table.
drop policy if exists "profiles self read" on public.profiles;
create policy "profiles self read" on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_moderator());
drop policy if exists "profiles self update" on public.profiles;
create policy "profiles self update" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
-- Users may not change role / simulated themselves.
revoke update on public.profiles from authenticated;
grant update (pseudonym, real_name, anonymity, home_country, interests, on_rating,
              notifications, hide_from_other_countries) on public.profiles to authenticated;

-- Responses: experts manage their own; moderators read all.
drop policy if exists "responses read" on public.responses;
create policy "responses read" on public.responses for select to authenticated
  using (expert_id = auth.uid() or public.is_moderator());
drop policy if exists "responses insert own" on public.responses;
create policy "responses insert own" on public.responses for insert to authenticated
  with check (expert_id = auth.uid());
drop policy if exists "responses update own" on public.responses;
create policy "responses update own" on public.responses for update to authenticated
  using (expert_id = auth.uid()) with check (expert_id = auth.uid());

-- Comments: every signed-in expert can read (the app shows them with display names);
-- authors write their own; moderators can update any (useful / reviewed / used_in).
drop policy if exists "comments read" on public.comments;
create policy "comments read" on public.comments for select to authenticated using (true);
drop policy if exists "comments insert own" on public.comments;
create policy "comments insert own" on public.comments for insert to authenticated
  with check (author_id = auth.uid());
drop policy if exists "comments update" on public.comments;
create policy "comments update" on public.comments for update to authenticated
  using (author_id = auth.uid() or public.is_moderator());
drop policy if exists "comments delete own" on public.comments;
create policy "comments delete own" on public.comments for delete to authenticated
  using (author_id = auth.uid() or public.is_moderator());

drop policy if exists "votes read" on public.comment_votes;
create policy "votes read" on public.comment_votes for select to authenticated using (true);
drop policy if exists "votes write own" on public.comment_votes;
create policy "votes write own" on public.comment_votes for all to authenticated
  using (voter_id = auth.uid()) with check (voter_id = auth.uid());

drop policy if exists "skips own" on public.risk_skips;
create policy "skips own" on public.risk_skips for all to authenticated
  using (expert_id = auth.uid()) with check (expert_id = auth.uid());

-- Activity log: write and read your own; moderators read all. No updates or deletes.
drop policy if exists "log insert own" on public.activity_log;
create policy "log insert own" on public.activity_log for insert to authenticated
  with check (user_id = auth.uid());
drop policy if exists "log read" on public.activity_log;
create policy "log read" on public.activity_log for select to authenticated
  using (user_id = auth.uid() or public.is_moderator());

-- -----------------------------------------------------------------------------
-- Views for the forecasting model / super-estimator board
-- security_invoker: callers only see rows RLS lets them see
-- (the service key sees everything).
-- -----------------------------------------------------------------------------

-- Every expert forecast on a resolved risk, with its Brier score.
create or replace view public.forecast_scores with (security_invoker = true) as
select r.expert_id,
       r.risk_id,
       r.item_id,
       r.round,
       r.likelihood_p                                   as p,
       k.outcome,
       power(r.likelihood_p - k.outcome::int, 2)        as brier,
       k.probability_p                                  as acaps_p,
       power(k.probability_p - k.outcome::int, 2)       as acaps_brier,
       r.answered_at
from public.responses r
join public.risks k using (risk_id)
where k.outcome is not null;

-- ACAPS' own track record: one row per resolved risk with a probability.
create or replace view public.acaps_baseline_scores with (security_invoker = true) as
select risk_id, risk_level, probability, probability_p as p, outcome,
       power(probability_p - outcome::int, 2) as brier
from public.risks
where outcome is not null and probability_p is not null;

grant select on public.forecast_scores, public.acaps_baseline_scores to authenticated;
grant select on public.acaps_baseline_scores to anon;
