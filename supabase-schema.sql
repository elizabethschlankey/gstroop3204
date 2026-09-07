-- PayHubble accounts — run this once in your Supabase project's SQL editor
-- (Project → SQL Editor → New query → paste this in → Run).
--
-- This creates:
--   1. profiles         — maps each account to the username they log in with
--   2. hubs             — one row per account holding their payment methods,
--                         buyer page, settings and activity log
--   3. two small lookup functions so people can sign in with a username
--      instead of an email address, while Supabase Auth still handles the
--      email/password underneath (so "forgot password" keeps working)
--
-- Everything is locked down with Row Level Security: a signed-in user can
-- only ever read or write their own profile and their own hub row. The
-- lookup functions run as SECURITY DEFINER so they can check a username
-- against auth.users without granting broader table access to anyone.

create extension if not exists citext;

-- ---------- profiles ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username citext unique not null,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "read own profile" on public.profiles;
create policy "read own profile" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "insert own profile" on public.profiles;
create policy "insert own profile" on public.profiles
  for insert with check (auth.uid() = id);

drop policy if exists "update own profile" on public.profiles;
create policy "update own profile" on public.profiles
  for update using (auth.uid() = id);

-- ---------- hubs (the actual payment data) ----------
create table if not exists public.hubs (
  user_id uuid primary key references auth.users(id) on delete cascade,
  profile jsonb not null default '{}'::jsonb,
  page jsonb not null default '{}'::jsonb,
  settings jsonb not null default '{}'::jsonb,
  activity jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.hubs enable row level security;

drop policy if exists "read own hub" on public.hubs;
create policy "read own hub" on public.hubs
  for select using (auth.uid() = user_id);

drop policy if exists "insert own hub" on public.hubs;
create policy "insert own hub" on public.hubs
  for insert with check (auth.uid() = user_id);

drop policy if exists "update own hub" on public.hubs;
create policy "update own hub" on public.hubs
  for update using (auth.uid() = user_id);

-- ---------- username <-> email lookups ----------
-- Sign-in flow: look up the email for a typed username, then call
-- supabase.auth.signInWithPassword with that email. Runs as the function
-- owner (SECURITY DEFINER) so it can see auth.users without exposing it.
create or replace function public.email_for_username(uname citext)
returns text
language sql
security definer
set search_path = public
as $$
  select au.email
  from public.profiles p
  join auth.users au on au.id = p.id
  where p.username = uname
  limit 1;
$$;

grant execute on function public.email_for_username(citext) to anon, authenticated;

-- Sign-up flow: check a username is free before creating the account.
create or replace function public.username_available(uname citext)
returns boolean
language sql
security definer
set search_path = public
as $$
  select not exists (select 1 from public.profiles where username = uname);
$$;

grant execute on function public.username_available(citext) to anon, authenticated;

-- ---------- one more setting to change by hand ----------
-- In the dashboard: Authentication → Providers → Email → turn OFF
-- "Confirm email". PayHubble signs people in immediately after they create
-- an account; password-reset emails still work fine with this off, since
-- that only depends on the account having a real email address on file.
