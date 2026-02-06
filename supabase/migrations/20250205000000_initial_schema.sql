-- Sport Tracker Fantasy - Initial schema for fantasyball project
-- Run this in Supabase Dashboard → SQL Editor

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- User profiles (extends auth.users)
create table if not exists public.user_profiles (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade unique,
  name text not null,
  email text not null,
  created_at timestamptz default now()
);

-- Followed teams (user favorites)
create table if not exists public.followed_teams (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  team_name text not null,
  league text not null,
  sport text default 'basketball',
  created_at timestamptz default now(),
  unique (user_id, team_name, league)
);

-- Followed players
create table if not exists public.followed_players (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  player_name text not null,
  team_name text,
  sport text default 'basketball',
  created_at timestamptz default now()
);

-- Fantasy squads (user-created lineups)
create table if not exists public.fantasy_squads (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  sport text default 'basketball',
  created_at timestamptz default now()
);

-- Fantasy squad players (players in each squad)
create table if not exists public.fantasy_squad_players (
  id uuid primary key default uuid_generate_v4(),
  squad_id uuid not null references public.fantasy_squads(id) on delete cascade,
  player_name text not null,
  team_name text,
  position text,
  created_at timestamptz default now()
);

-- Row Level Security
alter table public.user_profiles enable row level security;
alter table public.followed_teams enable row level security;
alter table public.followed_players enable row level security;
alter table public.fantasy_squads enable row level security;
alter table public.fantasy_squad_players enable row level security;

-- Policies: users can only access their own data
create policy "Users can manage own user_profiles"
  on public.user_profiles for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can manage own followed_teams"
  on public.followed_teams for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can manage own followed_players"
  on public.followed_players for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can manage own fantasy_squads"
  on public.fantasy_squads for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can manage own fantasy_squad_players"
  on public.fantasy_squad_players for all
  using (
    exists (
      select 1 from public.fantasy_squads
      where fantasy_squads.id = squad_id and fantasy_squads.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.fantasy_squads
      where fantasy_squads.id = squad_id and fantasy_squads.user_id = auth.uid()
    )
  );
