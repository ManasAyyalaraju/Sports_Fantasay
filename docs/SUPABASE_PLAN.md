# Supabase Setup & Workflow Plan (Planning Only)

This document describes how to set up Supabase for the Sport Tracker Fantasy app and how the data workflow would work. **No implementation is included**—this is planning only.

---

## 1. Why Supabase Here

- **Reference data** (teams, players, season schedule, season averages) is stored in Supabase so the app rarely hits API-Sports for it.
- **Live data** (games in progress, live player stats) stays from API-Sports when the user is tracking live.
- Result: daily API usage is mostly for live tracking instead of repeated roster/stats fetches.

---

## 2. Supabase Project Setup (High-Level)

1. **Create a Supabase project** at [supabase.com](https://supabase.com) (e.g. region closest to your users).
2. **Note:**
   - Project URL: `https://<project-ref>.supabase.co`
   - Anon (public) key: for client-side read/write where you allow it
   - Service role key: only for server-side or trusted sync jobs (never in the app binary)
3. **Database:** Use the SQL Editor in the Supabase Dashboard to run the schema and RLS (Section 3 & 4 below) when you’re ready to implement.

---

## 3. Database Schema (Proposed)

Tables mirror your app’s reference data and API-Sports concepts. Use your existing `NBAModels` / API response shapes as the source of truth for field names and types when you implement.

### 3.1 `teams`

| Column        | Type         | Notes                          |
|---------------|--------------|--------------------------------|
| id            | int4 PRIMARY KEY | API-Sports team ID         |
| name          | text         |                                |
| nickname      | text         | nullable                       |
| code          | text         | e.g. "LAL", "GSW"              |
| city          | text         | nullable                       |
| logo          | text         | nullable, URL                  |
| conference    | text         | from leagues JSON if needed    |
| division      | text         | from leagues JSON if needed    |
| nba_franchise | boolean      | default true                   |
| all_star      | boolean      | default false                  |
| updated_at    | timestamptz  | default now()                  |

- **Sync:** When you refresh teams from API-Sports, upsert by `id`.

### 3.2 `players`

| Column       | Type         | Notes                          |
|--------------|--------------|--------------------------------|
| id           | int4 PRIMARY KEY | API-Sports player ID       |
| first_name   | text         |                                |
| last_name    | text         |                                |
| position     | text         | e.g. "G", "F", "C"             |
| height       | text         | nullable (e.g. "6-10")         |
| weight       | text         | nullable                       |
| jersey       | text         | nullable                       |
| college      | text         | nullable                       |
| country      | text         | nullable                       |
| draft_year   | int4         | nullable                       |
| team_id      | int4         | nullable, FK → teams(id)       |
| season       | text         | e.g. "2024" (current season)    |
| updated_at   | timestamptz  | default now()                  |

- **Sync:** When you refresh roster from API-Sports (e.g. per team or bulk), upsert by `(id, season)` or by `id` if you only keep current season.
- **Usage:** App loads player list and player detail from here instead of calling API-Sports.

### 3.3 `games`

| Column          | Type         | Notes                          |
|-----------------|--------------|--------------------------------|
| id              | int4 PRIMARY KEY | API-Sports game ID         |
| season          | text         | e.g. "2024"                    |
| stage           | int2         | 1=preseason, 2=regular, etc.   |
| date            | timestamptz  | game start                     |
| status          | text         | e.g. "Finished", "In Progress" |
| home_team_id    | int4         | FK → teams(id)                 |
| visitor_team_id | int4         | FK → teams(id)                 |
| home_score      | int4         | nullable                       |
| visitor_score   | int4         | nullable                       |
| updated_at      | timestamptz  | default now()                  |

- **Sync:** When you fetch season games from API-Sports, upsert by `id`. Used for “regular season vs preseason” and for displaying schedule/results.
- **Usage:** App uses this for game list and for filtering “regular season” (e.g. for stats). Live games can still be fetched from API-Sports only when user is on live tab.

### 3.4 `game_details` (optional but useful)

Denormalized game info for display (team names, abbreviations, scores). Can be merged into `games` if you prefer a single table.

| Column              | Type | Notes        |
|---------------------|------|-------------|
| game_id             | int4 PRIMARY KEY | FK → games |
| home_team_name      | text |             |
| home_team_code      | text |             |
| visitor_team_name   | text |             |
| visitor_team_code    | text |             |
| home_score          | int4 |             |
| visitor_score       | int4 |             |
| updated_at          | timestamptz |     |

- **Sync:** Filled when you sync `games` (or in the same batch). Upsert by `game_id`.

### 3.5 `season_averages`

| Column       | Type         | Notes                          |
|--------------|--------------|--------------------------------|
| id           | uuid PRIMARY KEY | default gen_random_uuid()   |
| player_id    | int4         | FK → players(id)               |
| season       | text         | e.g. "2024"                    |
| pts          | float8       |                                |
| reb          | float8       |                                |
| ast          | float8       |                                |
| stl          | float8       |                                |
| blk          | float8       |                                |
| games_played | int4         |                                |
| min          | text         | e.g. "32"                      |
| fg_pct       | float8       |                                |
| fg3_pct      | float8       |                                |
| ft_pct       | float8       |                                |
| updated_at   | timestamptz  | default now()                  |

- **Sync:** When you refresh stats from API-Sports (e.g. for your “star” player set), upsert by `(player_id, season)`.
- **Usage:** App uses this for “players with stats” list and player detail instead of calling `players/statistics` repeatedly.

### 3.6 Indexes (when you implement)

- `players(team_id)`, `players(season)`
- `games(season)`, `games(status)`, `games(date)`
- `season_averages(player_id, season)`

---

## 4. Row Level Security (RLS)

- **Goal:** Allow the app to read reference data without auth; restrict who can write (e.g. only your sync process).
- **Option A – Public read, no anonymous write:**  
  - Enable RLS on all tables.  
  - Policies: `SELECT` allowed for `anon` (or for `authenticated` if you add auth later).  
  - No `INSERT`/`UPDATE`/`DELETE` for `anon`.  
  - Sync is done with **service role** (server or trusted client only) or via a **Postgres function** called with the service role.
- **Option B – Public read and “sync” via Edge Function:**  
  - Same read policies.  
  - Writes only from an Edge Function that uses the service role and calls API-Sports; app never writes to Supabase for sync.

Recommendation: **Option B** if you can run a scheduled Edge Function or cron so the API-Sports key never lives in the app.

---

## 5. Workflow (Who Writes / Who Reads / When)

### 5.1 Data flow overview

```
API-Sports (teams, players, games, stats)
        │
        ▼
   [Sync process]
        │
        ▼
   Supabase DB (teams, players, games, game_details, season_averages)
        │
        ▼
   iOS app (read reference data)
        │
   Live data only when user is tracking:
        │
        ▼
   API-Sports (live games, live player stats) ──► App (LiveGameManager)
```

### 5.2 Sync process (two options)

**Option 1 – App-initiated sync (API-Sports key in app)**  
- **When:** On first launch, or pull-to-refresh, or once per day in background.  
- **How:** App calls API-Sports (teams → games → players by team → players/statistics for star players), then upserts into Supabase using the anon key if you add a small “sync” API (e.g. Edge Function that accepts body and uses service role to upsert). Or app writes with anon key if you temporarily allow authenticated upsert.  
- **Pros:** Simple, no cron. **Cons:** API-Sports key in app; sync runs on each device (can duplicate calls if many users refresh).

**Option 2 – Server-side sync (recommended)**  
- **When:** Scheduled (e.g. daily or every 6–12 hours) or after games.  
- **How:** Supabase Edge Function (or external cron job) runs with API-Sports key in env, fetches teams → games → players → season_averages, then upserts into Supabase using the **service role** client.  
- **Pros:** One place for API-Sports usage; key never in app. **Cons:** Need to deploy and schedule the function.

### 5.3 App read path

- **Players list / search:** Query Supabase `players` (join `teams`), optionally join `season_averages`. No API-Sports call.
- **Player detail (season averages, last N games):** Read `season_averages` and, if you store per-game stats in Supabase, read from there; otherwise keep a small number of API-Sports calls for “last 5 games” or move that into sync later.
- **Games / schedule:** Read from `games` (and `game_details` if you use it). No API-Sports for past/finished games.
- **Live tab / live tracking:** Unchanged. App continues to call `LiveScoresAPI.fetchLiveGames()` and `fetchLiveStatsForPlayers(trackedPlayerIds)` on a timer (e.g. 60s). No Supabase for live data unless you later add a “live scores” pipeline that writes to Supabase and use Realtime (more complex).

### 5.4 Staleness and “last updated”

- Add an `updated_at` (or a single `metadata` table with `last_sync_at`) so the app can show “Data as of …”.
- Optionally: if Supabase is empty or `last_sync_at` is very old, app can show a message or fall back to a one-time API-Sports fetch until the next sync (if you keep that path).

---

## 6. What Stays in the App (No Supabase)

- **Live games list:** API-Sports `games?live=all`.
- **Live player stats:** API-Sports `players/statistics` for live games only, for tracked (favorite) players.
- **Player photos:** Keep using your existing `PlayerPhotoService` (and any external image URLs).
- **Favorites / user preferences:** Can stay local (UserDefaults) or move to Supabase later if you add auth.

---

## 7. Implementation Order (When You Decide to Build)

1. Create Supabase project and run schema (Section 3) + RLS (Section 4).  
2. Implement sync (Option 1 or 2).  
3. Add Supabase Swift client to the iOS app; implement a small “SupabaseService” that reads teams, players, games, season_averages.  
4. Change `LiveScoresAPI` (or a new facade) to: read reference data from Supabase first; call API-Sports only for live and (if you keep it) for fallback or one-off refresh.  
5. Keep `LiveGameManager` as-is for live polling.

---

## 8. Summary

| Data              | Source (after plan)     | When updated        |
|-------------------|-------------------------|---------------------|
| Teams             | Supabase                | Sync (daily/cron)   |
| Players           | Supabase                | Sync (daily/cron)   |
| Games (season)    | Supabase                | Sync (daily/cron)   |
| Season averages   | Supabase                | Sync (daily/cron)   |
| Live games        | API-Sports              | Every 60s when live |
| Live player stats | API-Sports              | Every 60s when live |

This keeps daily API-Sports usage focused on live tracking while reference data is served from Supabase.
