-- Favorites per account: one row per (user, player).
-- RLS ensures users only see and modify their own favorites.

create table if not exists public.user_favorite_players (
  user_id uuid not null references auth.users(id) on delete cascade,
  player_id int not null,
  created_at timestamptz not null default now(),
  primary key (user_id, player_id)
);

-- Index for "fetch all favorites for this user"
create index if not exists user_favorite_players_user_id_idx
  on public.user_favorite_players (user_id);

-- RLS: users can only read/insert/delete their own rows
alter table public.user_favorite_players enable row level security;

create policy "Users can read own favorites"
  on public.user_favorite_players for select
  using (auth.uid() = user_id);

create policy "Users can insert own favorites"
  on public.user_favorite_players for insert
  with check (auth.uid() = user_id);

create policy "Users can delete own favorites"
  on public.user_favorite_players for delete
  using (auth.uid() = user_id);
