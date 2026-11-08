-- =============================================================================
-- ACAPS Ground Truth — invite-only sign-up, pseudonym login, moderator invites
--
-- Run after 20261106000000_init.sql: Supabase dashboard -> SQL Editor -> paste -> Run.
-- Safe to re-run.
--
-- How logging in works
--   Supabase Auth only knows email + password. So:
--   * Experts log in with pseudonym + password. Their Auth email is made up from the
--     pseudonym:  lower(pseudonym) || '@' || public.expert_login_domain()
--     It never receives mail and is never shown. An optional real email for
--     notifications goes to public.expert_contacts (owner-only).
--   * Moderators log in with their real email + password. They are never anonymous.
--
-- Sign-up is only possible with a valid invite code, checked inside the database
-- (handle_new_user). The invite decides the role and, for experts, the home panel.
--
-- Dashboard setting required: Authentication -> Sign In / Providers -> Email ->
-- "Confirm email" OFF (made-up addresses cannot be confirmed).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Login domain for experts. Single source of truth: the app reads it via RPC.
-- If Supabase Auth rejects it ("email_address_invalid"), change it here only.
-- -----------------------------------------------------------------------------
create or replace function public.expert_login_domain()
returns text language sql immutable as $$ select 'gt-experts.invalid' $$;

grant execute on function public.expert_login_domain() to anon, authenticated;

-- -----------------------------------------------------------------------------
-- Invite codes: a code now carries a role. Expert codes need a panel country.
-- -----------------------------------------------------------------------------
alter table public.invite_codes add column if not exists role public.user_role not null default 'expert';
alter table public.invite_codes alter column panel_country drop not null;

alter table public.invite_codes drop constraint if exists expert_code_has_panel;
-- Dropped for good by 20261107120000_referrals.sql (experts choose their country),
-- so not added back when this file is re-run after it.
do $$ begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'invite_codes' and column_name = 'kind') then
    alter table public.invite_codes add constraint expert_code_has_panel
      check (role <> 'expert' or panel_country is not null);
  end if;
end $$;

insert into public.invite_codes (code, panel_country, role, max_uses) values
  ('GT-ACAPS-MOD1', null, 'moderator', 10)
on conflict (code) do nothing;

-- Read-only check for the app (shows "Chad panel" / "ACAPS moderator" before the form).
-- Does not count as a use: only a successful sign-up does.
-- Dropped first: 20261107120000_referrals.sql adds a column to the result.
drop function if exists public.check_invite(text);
create function public.check_invite(invite text)
returns table (role public.user_role, panel_country text)
language sql stable security definer set search_path = '' as $$
  select c.role, c.panel_country
    from public.invite_codes c
   where c.code = upper(trim(invite))
     and (c.expires_at is null or c.expires_at > now())
     and (c.max_uses is null or c.used_count < c.max_uses);
$$;

grant execute on function public.check_invite(text) to anon, authenticated;

-- The old redeem_invite() counted a use on every check. Replaced by check_invite()
-- plus the count in handle_new_user().
drop function if exists public.redeem_invite(text);

-- -----------------------------------------------------------------------------
-- Profiles: pseudonym is the login name.
-- -----------------------------------------------------------------------------
alter table public.profiles drop constraint if exists pseudonym_format;
alter table public.profiles add constraint pseudonym_format
  check (pseudonym ~ '^[A-Za-z0-9][A-Za-z0-9_-]{2,29}$');

-- "Sahel-Owl" and "sahel-owl" would map to the same login address.
create unique index if not exists profiles_pseudonym_lower_idx on public.profiles (lower(pseudonym));

-- Moderators sign their reviews: always known to ACAPS, always with a real name.
alter table public.profiles drop constraint if exists moderator_is_named;
alter table public.profiles add constraint moderator_is_named
  check (role <> 'moderator' or (anonymity = 'known_to_acaps' and real_name is not null));

-- Fixed after sign-up (changing it would also change the login address).
revoke update (pseudonym) on public.profiles from authenticated;

-- -----------------------------------------------------------------------------
-- Optional contact email for experts. Not in profiles, because moderators can
-- read every profile and an email would reveal who a pseudonymous expert is.
-- Only the owner reads it; notification jobs use the secret key.
-- -----------------------------------------------------------------------------
create table if not exists public.expert_contacts (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  email       text not null check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.expert_contacts enable row level security;
grant select, insert, update, delete on public.expert_contacts to authenticated;

drop policy if exists "contacts own" on public.expert_contacts;
create policy "contacts own" on public.expert_contacts for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Sign-up hook, now invite-only.
-- Sign-up metadata (options.data in supabase.auth.signUp):
--   invite        required, e.g. 'GT-CHAD-7Q4X'
--   pseudonym     experts: required, must match the Auth email
--   anonymity     experts: known_to_acaps | pseudonymous | anonymous
--   real_name     required for moderators and for expert levels 1-2
--   contact_email experts: optional
--   interests     experts: optional array of extra panels
-- real_name, contact_email and invite are removed from Auth metadata afterwards,
-- so they live only in profiles / expert_contacts / activity_log.
-- Any failure here aborts the sign-up; the app sees "Database error saving new user".
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  m        jsonb := coalesce(new.raw_user_meta_data, '{}');
  inv      public.invite_codes%rowtype;
  domain   text := public.expert_login_domain();
  pseudo   text := nullif(trim(m->>'pseudonym'), '');
  rname    text := nullif(trim(m->>'real_name'), '');
  contact  text := nullif(trim(m->>'contact_email'), '');
  lvl      public.anonymity_level;
begin
  -- 1. Invite: valid, not expired, not used up. Counts the use.
  update public.invite_codes c
     set used_count = c.used_count + 1
   where c.code = upper(trim(coalesce(m->>'invite', '')))
     and (c.expires_at is null or c.expires_at > now())
     and (c.max_uses is null or c.used_count < c.max_uses)
  returning * into inv;

  if inv.code is null then
    raise exception 'invite_invalid: a valid ACAPS invite code is required';
  end if;

  if inv.role = 'moderator' then
    -- 2a. Moderator: real email, real name, known to ACAPS.
    if new.email is null or lower(new.email) like ('%@' || domain) then
      raise exception 'moderator_email_required';
    end if;
    if rname is null then
      raise exception 'moderator_name_required';
    end if;
    insert into public.profiles (id, role, pseudonym, real_name, anonymity, home_country)
    values (new.id, 'moderator',
            'ACAPS-' || substr(replace(new.id::text, '-', ''), 1, 6),
            rname, 'known_to_acaps', null);
  else
    -- 2b. Expert: Auth email must be the pseudonym login address.
    if pseudo is null or lower(coalesce(new.email, '')) <> (lower(pseudo) || '@' || domain) then
      raise exception 'expert_login_mismatch: email must be lower(pseudonym)@%', domain;
    end if;
    lvl := coalesce((m->>'anonymity')::public.anonymity_level, 'pseudonymous');
    if lvl <> 'anonymous' and rname is null then
      raise exception 'expert_name_required';
    end if;
    insert into public.profiles (id, role, pseudonym, real_name, anonymity, home_country, interests)
    values (new.id, 'expert', pseudo, rname, lvl, inv.panel_country,
            case when jsonb_typeof(m->'interests') = 'array'
                 then array(select jsonb_array_elements_text(m->'interests')) else '{}' end);
    if contact is not null then
      insert into public.expert_contacts (user_id, email) values (new.id, contact);
    end if;
  end if;

  insert into public.activity_log (user_id, event, details)
  values (new.id, 'sign_up', jsonb_build_object('invite', inv.code, 'role', inv.role,
                                                'panel', inv.panel_country,
                                                'contact_email', contact is not null));

  -- 3. Keep personal data out of Auth metadata.
  update auth.users
     set raw_user_meta_data = raw_user_meta_data - 'real_name' - 'contact_email' - 'invite'
   where id = new.id;

  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();
