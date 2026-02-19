# What We’ve Accomplished So Far

This doc summarizes what’s in place for the Sport Tracker Fantasy app and Supabase backend.

---

## 1. Supabase project and app connection

- **Supabase project** created (e.g. region chosen, database and API available).
- **iOS app** connected to Supabase:
  - Project URL and anon key in `SupabaseConfig.swift`.
  - Supabase Swift package added; `SupabaseManager.shared` used in the app.

See **[SUPABASE_SETUP.md](./SUPABASE_SETUP.md)** for first-time setup steps.

---

## 2. Database schema and reference data

- **Tables** in Supabase (aligned with API-Sports and app needs):
  - **teams** – NBA teams (id, name, code, city, logo, conference, division, etc.).
  - **players** – Players with team_id, season, position, height, weight, etc.
  - **games** – Season games (id, season, stage, date, status, home/visitor team and scores).
  - **game_details** – Denormalized game info (team names, codes, scores) for display.
  - **season_averages** – Per-player season stats (pts, reb, ast, stl, blk, games_played, shooting %s).
  - **player_game_stats** – Per-game stats for players (for “last N games” and detail views).

- **Row Level Security (RLS)** and policies set so the app can read reference data as intended.

See **[SUPABASE_PLAN.md](./SUPABASE_PLAN.md)** for schema and workflow design.

---

## 3. Sync Edge Function: `sync-reference-data`

- **Edge Function** `sync-reference-data` is deployed and working.
- It runs in this order:
  1. **syncTeamsAndPlayers()** – Fetches NBA teams from API-Sports, upserts `teams`; then fetches players per team for the current season and upserts `players`.
  2. **syncGames()** – Fetches season games from API-Sports, upserts `games` and `game_details`.
  3. **syncSeasonAverages()** – Uses existing `games`/`game_details` for metadata; fetches player statistics from API-Sports and upserts `season_averages` and `player_game_stats`.

- **Config:** Uses `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `API_SPORTS_KEY` from Edge Function secrets. Accepts **POST** only; no request body required.

- **Location:** `supabase/functions/sync-reference-data/index.ts`.

---

## 4. Automated sync: cron every 12 hours

- **pg_cron** and **pg_net** are enabled in the Supabase project.
- **Vault secrets** are set:
  - `project_url` – Supabase project URL (used to build the Edge Function URL).
  - `anon_key` – Anon (publishable) key used to invoke the Edge Function (JWT).
- **Cron job** is scheduled:
  - **Name:** `invoke-sync-reference-data-every-12-hours` (or `invoke-sync-reference-data-12-hours`).
  - **Schedule:** `0 */12 * * *` (runs at **00:00** and **12:00 UTC**).
  - **Action:** Sends an HTTP POST to `/functions/v1/sync-reference-data` with `Authorization: Bearer <anon_key>`.

So reference data (teams, players, games, game_details, season_averages, player_game_stats) is refreshed automatically every 12 hours without running the Edge Function manually.

See **[CRON_SETUP.md](./CRON_SETUP.md)** for how to set up or change the cron and vault.

---

## 5. Auth (sign up & sign in)

- **Sign-up flow** works: WelcomeView → NameOnboardingView (name) → EmailOnboardingView (email) → SignUpView (password). Uses Supabase Auth with `display_name` in user metadata.
- **Sign-in flow** uses the same UI as sign-up: black background, back button, underlined email/password fields, teal pill “Log in” button. **SignInView** calls `AuthViewModel.signIn(email:password:)`.
- **AuthViewModel** (`Services/AuthViewModel.swift`): `signUp`, `signIn`, `signOut`, `currentUserId`, `currentUserEmail`, `currentUserDisplayName`, auth state observed via `authStateChanges`.
- **RootView** shows WelcomeView when signed out and ContentView when signed in.

---

## 6. Favorites per account

- **Table** `user_favorite_players`: `user_id` (uuid, FK → auth.users), `player_id` (int), primary key `(user_id, player_id)`. RLS so users only read/insert/delete their own rows.
- **Migration:** `supabase/migrations/20250212100000_user_favorite_players.sql`.
- **FavoritesService** (`Services/FavoritesService.swift`): Loads favorites from Supabase for the current user, `addFavorite`/`removeFavorite`/`toggleFavorite`. `@Published favoritePlayerIds` drives the UI.
- **ContentView** uses FavoritesService (no more `@AppStorage`): loads on appear with `.task(id: auth.currentUserId)` so switching accounts reloads favorites; passes `favoritePlayerIds` and `onToggleFavorite` to HomeView and PlayersView.
- **HomeView** and **PlayersView** take `favoritePlayerIds: Set<Int>` and `onToggleFavorite: (Int) async -> Void`; HomeView uses `.task(id: Array(favoritePlayerIds).sorted())` so the list refreshes as soon as favorites load after login.

Favorites are stored in Supabase per user, so each account has its own list and they sync across devices.

---

## 7. Leagues (Phase 2)

- **Tables:** `profiles` (id, display_name, etc.), `leagues` (id, name, capacity, draft_date, invite_code, creator_id, status, season, created_at, updated_at), `league_members` (league_id, user_id, role, joined_at). RLS so users see only leagues they’re in and can create/join.
- **Migrations:** `20250212110000_profiles_leagues_league_members.sql`, `20250212130000_fix_league_members_rls_recursion.sql` (fixes RLS recursion on league_members).
- **LeagueService** (`Services/LeagueService.swift`): Create league, join by invite code, load my leagues, load league members; `@Published myLeagues` drives the Profile tab's My Leagues section and Home's league selector.
- **Leagues UI:** ProfileView shows My Leagues (with ranks) plus Join League / Create League. CreateLeagueView (name, capacity, draft date → invite code + `sporttracker://join?code=...`), JoinLeagueView (enter code → join), LeagueDetailView (name, capacity, draft date, invite code, “Add player to roster (test)” for Phase 3).

---

## 8. Roster (Phase 3)

- **Table** `roster_picks`: `id`, `league_id`, `user_id`, `player_id`, `pick_number`, `round`, `created_at`; unique `(league_id, player_id)`. RLS: league members can read; authenticated can insert (with `user_id = auth.uid()`); users can delete own picks.
- **Migrations:** `20250212120000_roster_picks.sql`, `20250212140000_roster_picks_delete_policy.sql` (ensures DELETE policy so authenticated users can delete rows where `user_id = auth.uid()`).
- **RosterService** (`Services/RosterService.swift`): `loadRoster(leagueId:userId:)`, `addPlayerToRoster(...)`, `removePlayerFromRoster(leagueId:playerId:)`. User id for delete is derived from `client.auth.session` (not passed in). Single DELETE by `league_id`, `user_id`, `player_id`; SELECT before delete to confirm row exists (with logging); `.select("id")` on delete to verify; local `rosterPlayerIds` updated only after successful delete. UUIDs sent with `.lowercased()` for Supabase filters where needed.
- **Home:** League selector (picker) on Home; roster for selected league loaded from `roster_picks`; Home shows “Your Roster” with players sorted (live first by fantasy points, then by season average); empty state when no league or no picks. Remove-from-roster action on each roster card (calls `removePlayerFromRoster` then reloads roster).
- **Add player to roster (test):** From League detail, “Add player to roster (test)” opens **AddPlayerToRosterView** (sheet). List of available players (excluding already on roster); tap a player → **PlayerDetailView** (pushed), with “Add to roster” button; tap “Add to roster” → add via RosterService, detail is popped, then “Added to roster” alert with player name on the list; OK dismisses sheet and refreshes roster. Navigation uses `AddPlayerNavValue` (Hashable wrapper) and `navigationDestination(for: AddPlayerNavValue.self)` on the stack root; **PlayerDetailView** has `isPushed: true` when presented from this flow so it does **not** wrap in its own `NavigationStack` (avoids nested stack / blank screen). Confirmation: alert “X has been added to your roster” after successful add.

---

## 9. Player detail and add-to-roster UX

- **PlayerDetailView** when used from Add Player flow: optional `league`, `isOnRoster`, `onAddToRoster`; when set, shows “Add to roster” button; optional `isPushed` – when `true`, content is not wrapped in a second `NavigationStack` (used when pushed from AddPlayerToRosterView). Toolbar: when `isPushed`, no leading close button (system back used); when sheet, X button to dismiss.
- **AddPlayerToRosterView:** `NavigationStack(path: $path)`; list rows are `NavigationLink(value: navValue(for: p.player))`; destination is `PlayerDetailView(..., isPushed: true)`. On successful add: `path.removeLast()` then `addedPlayerName = player.displayFullName` so alert shows on the list; OK runs `onAdded()` and dismisses sheet.
- **Cancelled requests:** In `PlayerDetailView.loadPlayerData()`, if Supabase request fails with `NSURLErrorCancelled` or `URLError.cancelled` (user left screen), we do not log it as an error and do not fall back to API-Sports; we set `isLoading = false` and return.

---

## 10. Roster delete reliability and docs

- **RLS DELETE for roster_picks:** Policy “Users can delete own roster picks” (`auth.uid() = user_id`) applied via migration `20250212140000_roster_picks_delete_policy.sql`. If SELECT returns rows but DELETE returns 0, the usual cause is missing policy or `auth.uid()` null (no JWT); app uses anon key + session so JWT is sent.
- **Doc:** **[ROSTER_PICKS_RLS_DELETE.md](./ROSTER_PICKS_RLS_DELETE.md)** – exact SQL for the DELETE policy, where to run it (Dashboard SQL Editor or migrations), and how to verify the app is deleting with an authenticated session (not service role, not anon without session).

---

## 11. League Standings (Phase 4)

- **LeaderboardService** (`Services/LeaderboardService.swift`): Computes league standings from roster picks + player stats. `loadStandings(leagueId:useSeasonAverages:)` returns `[LeagueStandingsEntry]` (rank, userId, displayName, totalFantasyPoints). Uses live stats when available (LiveGameManager), else `player_game_stats` since league draft date, else `season_averages`. Supports `useSeasonAverages` for testing when live stats are unavailable.
- **Standings tab:** StandingsView shows the league leaderboard. Header: league selector (Menu), “Leaders”, Schedule Draft button + circular menu. Pill filters: Overall / Today / Last Week. Leaderboard rows: dark cards with display name, “Rank N”, and total fantasy points on the right. Same background as Home (black + radial gradients `#00EFEB`, `#0073EF`). Tapping a row opens **UserRosterView** (sheet) for that user’s roster.
- **UserRosterView** (when viewing another user’s roster): Header shows display name and total pts (e.g. “Manas”, “249 pts”). Roster list shows each player’s **points contributed** to that total (live FP, else last game since draft, else season average). Players sorted by contribution **descending**. Row shows player photo, name, jersey/position tag, and “X pts” on the right. No “Next:” game line or “Upcoming”/“Live” status pill in this view.

---

## 12. Profile tab and tab bar (UI)

- **Third tab renamed:** “Leagues” tab → **Profile** tab. Tab icon changed from `sportscourt` to `person.fill` / `person` (profile silhouette) per Figma.
- **ProfileView** (`Views/ProfileView.swift`): Implements Figma 19:431. Header: “My Profile” (grey), user display name (bold white). Two buttons: Join League (white bg, dark text + icon), Create League (dark bg, white text + plus). “My Leagues” section: list of leagues with name, status subtitle, and **rank** (e.g. “1st”, “3rd”) loaded via LeaderboardService. Same background as Home (black + radial gradients). Tapping a league pushes LeagueDetailView.
- **Custom tab bar:** Pill-shaped bar with icons only (no labels). Container: `.background(.white.opacity(0.08))`, `.clipShape(RoundedRectangle(cornerRadius: 100))`. Selected tab: `.background(.white.opacity(0.12))`, pill shape, 84×50. Tabs: Home, Standings, Profile.

---

## 13. Home view (UI)

- **Background:** Black base + two radial gradients (top-left `#00EFEB`, top-right `#0073EF`, 0.58 opacity, radius 400, centers `(0, 0.12)` and `(1, 0.12)`).
- **Roster rows (RosterPlayerRow):** Player photo, name, **next game line** (matchup + time, e.g. “ATL @ PHI, 6:00PM”) from `LiveScoresAPI.fetchUpcomingGamesForTeams`, jersey/position tag. **Status pill:** “In Progress” (red) when live, “Final” for ~12 hours after game end, else “Upcoming” (grey). Fantasy points shown when available (live or recent final). **12-hour Final→Upcoming rule:** After a game ends, “Final” is shown for ~12 hours, then reverts to “Upcoming” with next-game info.
- **Next-game fetch:** `nextGameByTeamId` cached per team; fetched via `LiveScoresAPI.fetchUpcomingGamesForTeams` when roster loads; cache invalidated when switching leagues.

---

## 14. App color theme

Defined in **Theme.swift** (`AppColors`) and used across Home, Standings, Profile, and supporting views.

| Role | Hex | Usage |
|------|-----|--------|
| **Primary** | `#0073EF` | Blue; theme primary, gradient start |
| **Secondary** | `#00EFEB` | Teal/cyan; theme secondary, gradient end |
| **Accent** | White | Buttons, links, loading spinners, highlights (CTAs use white on dark or dark on white for contrast) |
| **Background** | `#0A0A0A` | Main app background (black) |
| **Card / surface** | `#1C1C1E` | Cards, inputs, secondary surfaces |
| **Elevated** | `#2C2C2E` | Pills, tags, elevated UI |
| **Secondary text** | `#8E8E93` | Muted labels, captions |
| **Tertiary text** | `#3A3A3C` | Lowest emphasis text |
| **Live / error** | `#FF3B30` | Live indicator, errors, destructive |
| **Gold** | `#FFD700` | Favorites, rankings highlight |

**Tab background (all tabs):** Black base + two radial gradients (same on Home, Standings, Profile):

- **Top-left:** `#00EFEB` (teal), 0.58 opacity, radius 400, center `(0, 0.12)`
- **Top-right:** `#0073EF` (blue), 0.58 opacity, radius 400, center `(1, 0.12)`

**Auth screens (Welcome, Sign in, Forgot/Reset password):** Primary action button uses `#00989C` (teal) for the “Log in” / “Sign up” pill.

**Primary gradient:** `LinearGradient` blue → teal (`#0073EF` → `#00EFEB`), used where a gradient accent is needed.

---

## 15. Summary

| Area                    | Status | Notes |
|-------------------------|--------|--------|
| Supabase project        | Done   | URL + anon key in app; Swift client in use |
| Database tables         | Done   | teams, players, games, game_details, season_averages, player_game_stats, **user_favorite_players**, **profiles**, **leagues**, **league_members**, **roster_picks** |
| RLS                     | Done   | Reference data read; user_favorite_players per user; leagues/league_members; roster_picks (select/insert/delete own) |
| Edge Function           | Done   | sync-reference-data syncs all reference tables |
| Cron (12h)              | Done   | pg_cron + pg_net + Vault; runs 00:00 & 12:00 UTC |
| Auth                    | Done   | Sign up + sign in; AuthViewModel, currentUserId |
| Favorites               | Done   | Per account in Supabase; FavoritesService; load on login |
| Leagues (Phase 2)       | Done   | Create, join by code, list, detail; LeagueService; RLS recursion fix |
| Roster (Phase 3)        | Done   | roster_picks; RosterService; league selector + roster on Home; add/remove player |
| **League Standings (Phase 4)** | Done | LeaderboardService; StandingsView; league selector; Overall/Today/Last Week filters; tap row → UserRosterView |
| **Profile tab**         | Done   | Third tab = Profile (person icon); ProfileView with My Profile, Join/Create League, My Leagues + ranks |
| **Custom tab bar**      | Done   | Pill-shaped; icons only; Home, Standings, Profile |
| **Home UI**             | Done   | Black + radial gradients; roster rows with next-game line, status pill, FP; 12-hour Final→Upcoming |
| **UserRosterView UI**   | Done   | Points per player, sorted descending; no Next/Upcoming/Live in this view |
| Add-to-roster UX        | Done   | Tap player → detail → “Add to roster” → confirm alert; pop then alert; no nested stack |
| Roster delete           | Done   | Session-derived user id; SELECT then DELETE; RLS DELETE policy; doc for verification |
| **App color theme**    | Done   | Theme.swift; primary blue, secondary teal, accent white; tab radial gradients; auth teal |

---

## Next steps (optional)

- **Phase 5 – Drafts:** Drafts table, start draft, snake draft UI, draft board, player pool, “Your pick”, realtime updates (see **[FANTASY_APP_PLAN.md](./FANTASY_APP_PLAN.md)** and **[TESTING_PHASES.md](./TESTING_PHASES.md)**).
- **After Phase 5 (optional):** Universal link `sporttracker://join?code=...`, optional notifications, final Home sort behavior.
- **Monitoring:** Use **Edge Functions → sync-reference-data → Logs** and **Database → Cron Jobs** to confirm sync and cron runs.
