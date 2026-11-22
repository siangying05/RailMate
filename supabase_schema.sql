-- RailMate remote schema
-- Run this once in the Supabase dashboard: SQL Editor -> New query -> Run.
-- Every table is protected by row level security so a signed in user can only
-- read and write their own rows.

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  full_name     text        not null default 'Commuter',
  email         text        not null default '',
  mobile        text        not null default '',
  passenger_type text       not null default 'adult',
  preference    text        not null default 'fastest',
  home_station  text        not null default '',
  arrival_alerts boolean    not null default true,
  avoid_stairs  boolean     not null default false,
  walking_speed numeric     not null default 4.5,
  updated_at    timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ---------------------------------------------------------------------------
-- favourite_routes
-- ---------------------------------------------------------------------------
create table if not exists public.favourite_routes (
  id                  bigint generated always as identity primary key,
  user_id             uuid        not null references auth.users (id) on delete cascade,
  label               text        not null,
  origin_id           text        not null,
  origin_name         text        not null,
  destination_id      text        not null,
  destination_name    text        not null,
  landmark            text        not null default '',
  preferred_departure integer     not null default 480,
  created_at          timestamptz not null default now(),
  unique (user_id, origin_id, destination_id)
);

create index if not exists favourite_routes_user_idx
  on public.favourite_routes (user_id, created_at desc);

alter table public.favourite_routes enable row level security;

drop policy if exists "favourites_all_own" on public.favourite_routes;
create policy "favourites_all_own"
  on public.favourite_routes for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- tickets
-- ---------------------------------------------------------------------------
create table if not exists public.tickets (
  id               text        primary key,
  reference        text        not null unique,
  user_id          uuid        not null references auth.users (id) on delete cascade,
  origin_id        text        not null,
  origin_name      text        not null,
  destination_id   text        not null,
  destination_name text        not null,
  depart_at        timestamptz not null,
  issued_at        timestamptz not null,
  expires_at       timestamptz not null,
  passengers       integer     not null default 1,
  passenger_type   text        not null default 'adult',
  fare_card        text        not null default 'touchNGo',
  payment_method   text        not null default 'touchNGoEwallet',
  amount           numeric     not null default 0,
  line_summary     text        not null default '',
  travel_minutes   integer     not null default 0,
  status           text        not null default 'active'
);

create index if not exists tickets_user_idx
  on public.tickets (user_id, depart_at desc);

alter table public.tickets enable row level security;

drop policy if exists "tickets_all_own" on public.tickets;
create policy "tickets_all_own"
  on public.tickets for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Create a profile row automatically when a new account is confirmed.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, mobile, passenger_type)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', 'Commuter'),
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'mobile', ''),
    coalesce(new.raw_user_meta_data ->> 'passenger_type', 'adult')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
