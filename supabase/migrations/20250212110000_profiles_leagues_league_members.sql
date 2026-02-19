-- Profiles: optional; id = auth.uid(); RLS own row read/write
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can read own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- Leagues: creator_id -> auth.users; status: open, draft_scheduled, draft_in_progress, draft_completed, active
create table if not exists public.leagues (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  capacity int not null check (capacity >= 2 and capacity <= 20),
  draft_date timestamptz not null,
  invite_code text not null unique,
  creator_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'open' check (status in ('open', 'draft_scheduled', 'draft_in_progress', 'draft_completed', 'active')),
  season text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists leagues_invite_code_idx on public.leagues (invite_code);
create index if not exists leagues_creator_id_idx on public.leagues (creator_id);

alter table public.leagues enable row level security;

create policy "Authenticated users can read leagues"
  on public.leagues for select
  to authenticated
  using (true);

create policy "Creator can insert league"
  on public.leagues for insert
  to authenticated
  with check (auth.uid() = creator_id);

create policy "Creator can update own league"
  on public.leagues for update
  to authenticated
  using (auth.uid() = creator_id);

-- League members: one row per (league, user); draft_order set when draft starts
create table if not exists public.league_members (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  draft_order int check (draft_order is null or (draft_order >= 1 and draft_order <= 20)),
  unique (league_id, user_id)
);

create index if not exists league_members_league_id_idx on public.league_members (league_id);
create index if not exists league_members_user_id_idx on public.league_members (user_id);

alter table public.league_members enable row level security;

-- Members of a league can read all members of that league
create policy "League members can read members"
  on public.league_members for select
  to authenticated
  using (
    exists (
      select 1 from public.league_members lm
      where lm.league_id = league_members.league_id and lm.user_id = auth.uid()
    )
  );

-- Users can join (insert self) when league is open and under capacity
create policy "Users can join open league under capacity"
  on public.league_members for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.leagues l
      where l.id = league_id and l.status = 'open'
        and (select count(*) from public.league_members where league_id = l.id) < l.capacity
    )
  );

-- Only creator can delete members (leave/remove); for now allow user to delete own row (leave)
create policy "Users can delete own membership"
  on public.league_members for delete
  to authenticated
  using (auth.uid() = user_id);
