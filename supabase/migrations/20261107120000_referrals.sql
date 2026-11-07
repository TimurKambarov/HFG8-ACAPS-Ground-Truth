-- =============================================================================
-- ACAPS Ground Truth — moderator invite codes and expert referral codes
--
-- Run after 20261107000000_invite_auth.sql: Supabase dashboard -> SQL Editor ->
-- paste -> Run. Safe to re-run.
--
-- There is no installed app yet, so nobody shares links: people share CODES and
-- type them into the app ("I have a code").
--
--   GT-XXXX-XXXX   single-use invite a moderator creates for one trusted person
--                  (create_invite). ACAPS knows whom it invited.
--   REF-XXXX-XXXX  an expert's permanent referral code. Any number of trusted
--                  colleagues can join with it. Made automatically at sign-up.
--
-- Anonymity rules kept from the app:
--   * A moderator invite records THAT and WHEN it was used, never by which
--     account (so a fully anonymous expert cannot be traced through the note
--     "protection officer, Abéché"). The sign-up log no longer stores the code.
--   * A referral records referrer -> new member, so the referrer gets the
--     points and the count. The referrer only ever sees a count and dates
--     (my_referrals), never who joined. Moderators see per-expert counts.
--   * The new expert picks their own home country; codes no longer need one.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Codes: kind, owner, note, cancel, last use. Panel country becomes optional.
-- -----------------------------------------------------------------------------
alter table public.invite_codes add column if not exists kind text not null default 'invite';
alter table public.invite_codes drop constraint if exists invite_codes_kind_check;
alter table public.invite_codes add constraint invite_codes_kind_check check (kind in ('invite', 'referral'));

-- invite: the moderator who created it (null for codes seeded in SQL).
alter table public.invite_codes add column if not exists created_by uuid references auth.users (id) on delete set null;
-- referral: the expert whose personal code this is.
alter table public.invite_codes add column if not exists referrer_id uuid references auth.users (id) on delete cascade;
-- "Who is it for", moderators only.
alter table public.invite_codes add column if not exists note text;
alter table public.invite_codes add column if not exists revoked_at timestamptz;
alter table public.invite_codes add column if not exists used_at timestamptz;   -- last use

-- The new expert chooses their country in the sign-up form.
alter table public.invite_codes drop constraint if exists expert_code_has_panel;

alter table public.invite_codes drop constraint if exists referral_is_expert_code;
alter table public.invite_codes add constraint referral_is_expert_code
  check (kind <> 'referral' or (role = 'expert' and referrer_id is not null and max_uses is null));

-- One permanent referral code per expert.
create unique index if not exists invite_codes_one_referral_idx
  on public.invite_codes (referrer_id) where kind = 'referral';

-- -----------------------------------------------------------------------------
-- How an expert got in (trust signal for moderators, never shown to colleagues).
-- -----------------------------------------------------------------------------
alter table public.profiles add column if not exists joined_via text not null default 'acaps_invite';
alter table public.profiles drop constraint if exists profiles_joined_via_check;
alter table public.profiles add constraint profiles_joined_via_check
  check (joined_via in ('acaps_invite', 'expert_referral'));

-- -----------------------------------------------------------------------------
-- Who joined with whose referral code. No direct access: only through the
-- functions below, so a referrer never gets the new member's id.
-- -----------------------------------------------------------------------------
create table if not exists public.referrals (
  referred_id  uuid primary key references auth.users (id) on delete cascade,
  referrer_id  uuid not null references auth.users (id) on delete cascade,
  joined_at    timestamptz not null default now()
);
create index if not exists referrals_referrer_idx on public.referrals (referrer_id);

alter table public.referrals enable row level security;   -- no policies
revoke all on public.referrals from anon, authenticated;
grant all on public.referrals to service_role;

-- -----------------------------------------------------------------------------
-- A new random code, e.g. 'GT-7Q4X-K9MB'. No 0/O/1/I to misread.
-- Random bytes from gen_random_uuid(), skipping its fixed version/variant bytes.
-- -----------------------------------------------------------------------------
create or replace function public.new_code(prefix text)
returns text language plpgsql volatile set search_path = '' as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  b   bytea := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
  idx int[] := array[0, 1, 2, 3, 4, 5, 10, 11];
  s   text := '';
begin
  for i in 1..8 loop
    s := s || substr(alphabet, (get_byte(b, idx[i]) % 32) + 1, 1);
    if i = 4 then s := s || '-'; end if;
  end loop;
  return prefix || '-' || s;
end $$;

revoke all on function public.new_code(text) from public, anon, authenticated;

-- Gives an expert their referral code (or returns the one they have).
create or replace function public.ensure_referral_code(uid uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare c text;
begin
  select code into c from public.invite_codes where kind = 'referral' and referrer_id = uid;
  while c is null loop
    begin
      insert into public.invite_codes (code, kind, role, referrer_id, max_uses)
      values (public.new_code('REF'), 'referral', 'expert', uid, null)
      returning code into c;
    exception when unique_violation then
      -- Same random code twice (or a parallel call): look again, then retry.
      select code into c from public.invite_codes where kind = 'referral' and referrer_id = uid;
    end;
  end loop;
  return c;
end $$;

revoke all on function public.ensure_referral_code(uuid) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- Checking a code before the sign-up form (does not count as a use).
-- check_invite: one row when the code works now, else none (same as before,
--   plus `kind`). invite_status: why a code does not work, for the message.
-- -----------------------------------------------------------------------------
drop function if exists public.check_invite(text);
create function public.check_invite(invite text)
returns table (role public.user_role, panel_country text, kind text)
language sql stable security definer set search_path = '' as $$
  select c.role, c.panel_country, c.kind
    from public.invite_codes c
   where c.code = upper(trim(invite))
     and c.revoked_at is null
     and (c.expires_at is null or c.expires_at > now())
     and (c.max_uses is null or c.used_count < c.max_uses);
$$;

create or replace function public.invite_status(invite text)
returns text language sql stable security definer set search_path = '' as $$
  select coalesce((
    select case
             when c.revoked_at is not null then 'revoked'
             when c.expires_at is not null and c.expires_at <= now() then 'expired'
             when c.max_uses is not null and c.used_count >= c.max_uses then 'used'
             else 'ok'
           end
      from public.invite_codes c
     where c.code = upper(trim(invite))), 'unknown');
$$;

grant execute on function public.check_invite(text), public.invite_status(text) to anon, authenticated;

-- -----------------------------------------------------------------------------
-- Sign-up hook. Same as 20261107000000_invite_auth.sql, plus:
--   * revoked codes are refused
--   * experts send home_country (the code's panel is only a fallback)
--   * on_rating, notifications, hide_from_other_countries from the form
--   * a referral code records the referral; every expert gets their own code
--   * the log keeps the code's kind, not the code itself
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
  home     text;
  lvl      public.anonymity_level;
begin
  -- 1. Code: valid, not cancelled, not expired, not used up. Counts the use.
  update public.invite_codes c
     set used_count = c.used_count + 1,
         used_at    = now()
   where c.code = upper(trim(coalesce(m->>'invite', '')))
     and c.revoked_at is null
     and (c.expires_at is null or c.expires_at > now())
     and (c.max_uses is null or c.used_count < c.max_uses)
  returning * into inv;

  if inv.code is null then
    raise exception 'invite_invalid: a valid ACAPS invite or referral code is required';
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
    -- The expert's own choice; a code's panel (old seeded codes) only as a fallback.
    home := coalesce(nullif(trim(m->>'home_country'), ''), inv.panel_country);
    if home is null then
      raise exception 'expert_country_required';
    end if;
    insert into public.profiles (id, role, pseudonym, real_name, anonymity, home_country, interests,
                                 on_rating, notifications, hide_from_other_countries, joined_via)
    values (new.id, 'expert', pseudo, rname, lvl, home,
            case when jsonb_typeof(m->'interests') = 'array'
                 then array(select jsonb_array_elements_text(m->'interests') except select home) else '{}' end,
            coalesce((m->>'on_rating')::boolean, true),
            coalesce((m->>'notifications')::boolean, true),
            lvl <> 'anonymous' and coalesce((m->>'hide_from_other_countries')::boolean, false),
            case when inv.kind = 'referral' then 'expert_referral' else 'acaps_invite' end);
    if contact is not null then
      insert into public.expert_contacts (user_id, email) values (new.id, contact);
    end if;
    if inv.kind = 'referral' then
      insert into public.referrals (referred_id, referrer_id) values (new.id, inv.referrer_id);
    end if;
    -- The new member's own permanent referral code.
    perform public.ensure_referral_code(new.id);
  end if;

  insert into public.activity_log (user_id, event, details)
  values (new.id, 'sign_up', jsonb_build_object('kind', inv.kind, 'role', inv.role,
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

-- -----------------------------------------------------------------------------
-- Experts: my referral code and who joined with it (dates only).
-- -----------------------------------------------------------------------------

-- Also gives experts who signed up before this migration their code.
create or replace function public.my_referral_code()
returns text language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and role = 'expert') then
    return null;
  end if;
  return public.ensure_referral_code(auth.uid());
end $$;

create or replace function public.my_referrals()
returns table (joined_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select r.joined_at from public.referrals r where r.referrer_id = auth.uid() order by r.joined_at;
$$;

-- -----------------------------------------------------------------------------
-- Moderators: create, list, annotate and cancel single-use invite codes, and
-- see how many colleagues joined through each expert's referral code.
-- -----------------------------------------------------------------------------
create or replace function public.create_invite(note text default null)
returns text language plpgsql security definer set search_path = '' as $$
declare c text;
begin
  if not public.is_moderator() then
    raise exception 'moderator_only';
  end if;
  loop
    begin
      insert into public.invite_codes (code, kind, role, max_uses, created_by, note)
      values (public.new_code('GT'), 'invite', 'expert', 1, auth.uid(), nullif(trim(note), ''))
      returning code into c;
      return c;
    exception when unique_violation then
      -- Same random code as an existing one: try another.
    end;
  end loop;
end $$;

create or replace function public.list_invites()
returns table (code text, note text, created_at timestamptz, created_by uuid, created_by_name text,
               panel_country text, max_uses int, used_count int, used_at timestamptz, revoked_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_moderator() then
    raise exception 'moderator_only';
  end if;
  return query
    select c.code, c.note, c.created_at, c.created_by, p.real_name,
           c.panel_country, c.max_uses, c.used_count, c.used_at, c.revoked_at
      from public.invite_codes c
      left join public.profiles p on p.id = c.created_by
     where c.kind = 'invite' and c.role = 'expert'
     order by c.created_at desc;
end $$;

create or replace function public.set_invite_note(invite text, note text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_moderator() then
    raise exception 'moderator_only';
  end if;
  update public.invite_codes c set note = nullif(trim(set_invite_note.note), '')
   where c.code = upper(trim(invite)) and c.kind = 'invite';
end $$;

create or replace function public.revoke_invite(invite text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_moderator() then
    raise exception 'moderator_only';
  end if;
  update public.invite_codes c set revoked_at = coalesce(c.revoked_at, now())
   where c.code = upper(trim(invite)) and c.kind = 'invite';
end $$;

create or replace function public.referral_counts()
returns table (referrer_id uuid, n int)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_moderator() then
    raise exception 'moderator_only';
  end if;
  return query select r.referrer_id, count(*)::int from public.referrals r group by r.referrer_id;
end $$;

-- Security-definer functions are executable by PUBLIC by default: narrow that.
revoke all on function public.my_referral_code(), public.my_referrals(), public.create_invite(text),
  public.list_invites(), public.set_invite_note(text, text), public.revoke_invite(text),
  public.referral_counts() from public, anon;
grant execute on function public.my_referral_code(), public.my_referrals(), public.create_invite(text),
  public.list_invites(), public.set_invite_note(text, text), public.revoke_invite(text),
  public.referral_counts() to authenticated;

-- Experts who signed up before this migration get their referral code now.
select public.ensure_referral_code(p.id) from public.profiles p where p.role = 'expert';
