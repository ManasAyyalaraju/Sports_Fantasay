-- Roster picks: drafted players per league per user (player_id = NBA player id from API-Sports).
-- Unique (league_id, player_id) so a player can only be drafted once per league.

create table if not exists public.roster_picks (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  player_id int not null,
  pick_number int not null,
  round int not null,
  created_at timestamptz not null default now(),
  unique (league_id, player_id)
);

create index if not exists roster_picks_league_id_idx on public.roster_picks (league_id);
create index if not exists roster_picks_user_id_idx on public.roster_picks (user_id);
create index if not exists roster_picks_league_user_idx on public.roster_picks (league_id, user_id);

alter table public.roster_picks enable row level security;

-- League members can read all roster picks for their leagues
create policy "League members can read roster picks"
  on public.roster_picks for select
  to authenticated
  using (
    exists (
      select 1 from public.league_members lm
      where lm.league_id = roster_picks.league_id and lm.user_id = auth.uid()
    )
  );

-- Authenticated users can insert (app enforces: only during draft or manual add for testing)
create policy "Authenticated can insert roster pick"
  on public.roster_picks for insert
  to authenticated
  with check (auth.uid() = user_id);

-- No update; delete only own picks (e.g. leave league or undo test add)
create policy "Users can delete own roster picks"
  on public.roster_picks for delete
  to authenticated
  using (auth.uid() = user_id);
