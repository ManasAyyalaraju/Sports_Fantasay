# League Leaderboard – Phased Plan (Phase 4)

This document outlines how to add a **league leaderboard** so users can see where they and other members stand in each league. It aligns with **Phase 4** in [ACCOMPLISHED.md](./ACCOMPLISHED.md) and [FANTASY_APP_PLAN.md](./FANTASY_APP_PLAN.md).

---

## Current State (Summary)

- **Leagues:** `leagues`, `league_members`. Create, join by code, list “my leagues,” league detail. No API yet to load “members of this league” with display names.
- **Roster:** `roster_picks` (league_id, user_id, player_id, pick_number, round). RosterService loads roster for **one** user in one league. RLS allows **any league member** to read all `roster_picks` for that league.
- **Fantasy scoring:**
  - **Season:** `SeasonAverages.fantasyScore` = pts + (reb × 1.2) + (ast × 1.5) + (stl × 3) + (blk × 3) (see `NBAModels.swift`).
  - **Live:** `LivePlayerStat.fantasyPoints` = points + (rebounds × 1.2) + … − turnovers (see `LiveModels.swift`). Home already uses LiveGameManager for “live at top.”
- **Profiles:** `profiles` (id, display_name, avatar_url). RLS: users can only read **own** profile. So we cannot yet show other members’ names from the client without a backend change.
- **League detail:** `LeagueDetailView` shows league info and “Add player to roster (test).” No leaderboard/standings yet.

---

## Goal

- **Per league:** Show a **leaderboard** (standings) of all members, ranked by total fantasy points.
- **Per member:** Show rank (1, 2, 3…), display name, and total points (season-based first; optional later: live total or “Season” vs “Live” toggle).
- **Where:** From league detail (e.g. “Standings” / “Leaderboard” section or button → dedicated view).

---

## Production vs testing

- **Production:** Rosters will be drafted live. We do **not** need a leaderboard before the draft; the leaderboard is only relevant after the draft, when members have rosters and we count fantasy points from games on or after draft date.
- **Testing:** For now we test the leaderboard the same way we test rosters—by manually adding players via "Add player to roster (test)" from league detail. The leaderboard should work with manually added roster picks and show standings as soon as someone has players on their roster. For testing we use **season averages** to compute totals (sum of each roster player's season fantasy score), so adding a player immediately shows points on the leaderboard without needing real games or a past draft date. When the live draft exists, we switch to **actual points after draft date** for production standings.

---

## Standings scoring: when and how to count fantasy points

### Production (after live draft): actual points after draft date

For **league standings** in production, count **actual** fantasy points from games played **on or after the league's draft date** (and in the league's season). That way:

- You only get credit for games **after** you drafted the player.
- Standings reflect real performance in the league, not pre-draft stats.
- Standings update as new box scores are synced (your cron runs every 12h and upserts `player_game_stats`).

**When we start counting (production)**

- For each roster player, sum fantasy points from `player_game_stats` where `game_date >= league.draft_date` (and `season` matches `league.season`). No special "draft completed" flag required; the league's `draft_date` is the cutoff. We do not show a leaderboard before the draft in production (rosters are drafted live).

**Fantasy points per game (same as live)**

- Use the same formula as `LivePlayerStat.fantasyPoints`:  
  `pts + (reb × 1.2) + (ast × 1.5) + (stl × 3) + (blk × 3) − turnovers`  
- `player_game_stats` has: `pts`, `reb`, `ast`, `stl`, `blk`, `turnovers`; `game_date` (string, e.g. `"2025-02-01T00:00:00.000Z"`) for filtering.

**When standings update**

- **On read:** When the user opens the leaderboard (or pulls to refresh), the app loads `player_game_stats` for all roster players with `game_date >= draft_date`, sums per player then per user, and sorts. No separate "update standings" job needed.
- **Data freshness:** Your existing **sync-reference-data** cron (every 12h) already upserts `player_game_stats`; the next time a user opens the standings, they see the latest totals. Optionally you could add a materialized view or cache table later if you need faster reads.

**Implementation outline**

1. **Cutoff:** Use `league.draftDate` (and `league.season`) when querying. Parse `game_date` from `player_game_stats` (e.g. ISO8601 or `yyyy-MM-dd`) and only include rows where `game_date >= draftDate` (same calendar day or later).
2. **Data:** Add a method to fetch "game stats for these players on or after this date" (e.g. in SupabaseNBAService: batch fetch from `player_game_stats` where `player_id in (...)` and `game_date >= draftDateStr`, then sum fantasy points per player in the app). Alternatively, a Postgres RPC could return per-player or per-user totals.
3. **Per-user total:** For each league member, take their roster (player IDs from `roster_picks`); for each player, sum fantasy points from the filtered game stats; add those sums to get that member's total. Sort by total descending → rank.

### Testing: season averages (for manual roster testing)

- **Total = sum of each roster player's season average fantasy score** (from `season_averages`). No game date filter.
- Use this for **testing** so that when you add a player to a roster via "Add player to roster (test)", the leaderboard immediately shows points for that player (no real draft or games after draft date needed). In production, after the live draft exists, switch to **actual points after draft date** for the main standings.

---

## Phases

### Phase 4a – Backend: League members + roster reads + scoring data

**Goal:** App can get (1) list of league members for a league, (2) all roster picks for that league, and (3) season averages for any set of player IDs, so we can compute total fantasy points per user in the app.

**Tasks:**

1. **LeagueService – load league members**
   - Add `loadLeagueMembers(leagueId: UUID) async throws -> [LeagueMember]`.
   - Query `league_members` for the given `league_id` (RLS already allows members to read). Return at least `id`, `league_id`, `user_id`, `joined_at` (and `draft_order` if present). No display names yet.

2. **RosterService (or new LeaderboardService) – roster picks for whole league**
   - Add a way to load **all** `roster_picks` for a league (all users), not just the current user. RLS allows league members to read all picks for that league.
   - Example: `loadAllRosterPicks(leagueId: UUID) async throws -> [RosterPick]` (or return a structure grouped by `user_id` → `[player_id]`).

3. **Scoring data (testing: season averages)**
   - Reuse existing Supabase: `season_averages` (and `SupabaseNBAService.fetchSeasonAverage(for:)` or batch fetch). No schema change.
   - Define “total season fantasy points” for a user in a league = sum of `SeasonAverages.fantasyScore` for each player on that user’s roster (current season). Same formula as Home.

**Deliverable:** You can, in code, for a given league: get all member `user_id`s; get each member’s roster (player IDs); fetch season averages for those players; sum fantasy points per user and sort. No UI yet.

---

### Phase 4b – Display names for leaderboard

**Goal:** Leaderboard rows show display names, not just user IDs.

**Options (pick one):**

- **Option A – RLS on `profiles`:** Add a policy so that **league members can read `profiles` of users who are in the same league.**  
  - e.g. “SELECT on profiles WHERE id IN (SELECT user_id FROM league_members WHERE league_id = :league_id AND league_id IN (SELECT league_id FROM league_members WHERE user_id = auth.uid()))”.  
  - Then in the app: after loading league members, fetch `profiles` for those `user_id`s (with a single `in("id", values: memberIds)` query). Use `display_name`; fallback to email or “Member” if null.

- **Option B – Database view / RPC:** Create a Postgres function or view that returns leaderboard rows (e.g. rank, user_id, display_name, total_fantasy_points) for a given league_id, with security check that `auth.uid()` is in that league.  
  - View would join league_members, roster_picks, season_averages, profiles. More work upfront, but one round-trip and consistent scoring logic on the server.

**Recommendation:** Start with **Option A** (RLS + client-side aggregation) for speed; you already have LeagueService, RosterService, and SupabaseNBAService. Option B can be a later optimization.

**Tasks:**

1. **Migration:** Add RLS policy on `profiles`: “Users can read profiles of other users who share at least one league with them.” (Exact policy text in migration.)
2. **LeagueService or new helper:** Load profiles for a list of user IDs (e.g. `fetchProfiles(userIds: [UUID])`). Map `user_id` → display_name (or fallback).
3. **Leaderboard model:** Define a struct e.g. `LeagueLeaderboardEntry(rank: Int, userId: UUID, displayName: String, totalFantasyPoints: Double)` and build it in the app from: members + roster-by-user + season totals + display names.

**Deliverable:** You have an ordered list of leaderboard entries (rank, display name, total season fantasy points) for a league.

---

### Phase 4c – Leaderboard service and UI

**Goal:** A dedicated leaderboard for a league, visible from league detail, with refresh.

**Tasks:**

1. **LeaderboardService (or extend LeagueService)**
   - Add something like: `loadLeaderboard(leagueId: UUID) async -> [LeagueLeaderboardEntry]`.
   - Implementation: call `loadLeagueMembers(leagueId)`, `loadAllRosterPicks(leagueId)`, batch-fetch season averages for all involved player IDs, fetch profiles for member user IDs, compute per-user totals, sort descending by points, assign ranks. Cache or not per your preference (e.g. cache in memory for the current league and invalidate on leave/refresh).

2. **League leaderboard view**
   - New view: `LeagueLeaderboardView(league: League)`.
   - Shows a list: Rank | Display name | Total FP (e.g. “142.5 pts” or “142.5” with a label). Highlight current user’s row.
   - Loading and error states; pull-to-refresh or “Refresh” button that calls `loadLeaderboard(leagueId:)` again.
   - Empty state if no members or no one has roster picks yet.

3. **Entry point from league detail**
   - In `LeagueDetailView`, add a section or button: “Standings” / “Leaderboard” that pushes or presents `LeagueLeaderboardView(league: league)`.
   - Optional: show a compact “You: rank X of Y” or “Your rank: 2” on the league detail card so users see their position at a glance before opening full leaderboard.

**Deliverable:** From league detail, user can open the leaderboard, see all members ranked by total season fantasy points, with names and refresh.

---

### Phase 4d (Optional) – Live scoring and polish

**Goal:** Optional “Live” total or “Season vs Live” toggle; small UX improvements.

**Tasks:**

1. **Live total (optional)**
   - For each member’s roster, compute “live” fantasy total using `LiveGameManager` for players currently live (same formula as Home), and season fantasy for the rest. Either show “Live total” as a second column or add a toggle “Season | Live” and recompute/sort when toggled. This requires tracking the same player IDs for live stats as you do on Home.

2. **Polish**
   - Ties: same rank, next rank skips (e.g. 1, 2, 2, 4).
   - Formatting: consistent decimal places for points; “—” or “0” when no roster.
   - Accessibility: labels for rank and points.

**Deliverable:** Leaderboard is usable and, if you implement it, can show live-based ranking.

---

## Data flow (after Phase 4c)

1. User opens a league → League detail.
2. User taps “Standings” / “Leaderboard” → `LeagueLeaderboardView(league)`.
3. View calls `loadLeaderboard(leagueId)` which:
   - Loads `league_members` for league.
   - Loads all `roster_picks` for league (grouped by user_id).
   - Batch-loads `season_averages` for all player IDs in those rosters.
   - Loads `profiles` for all member user_ids (Phase 4b policy).
   - For each user: sum fantasy points of their roster players; sort by total desc; assign ranks.
4. UI shows list: Rank, Name, Total FP; current user highlighted.

---

## Summary table

| Phase   | Focus                          | Deliverable                                              |
|---------|---------------------------------|----------------------------------------------------------|
| **4a**  | Backend: members + roster + scoring | Load members, all roster picks for league, season totals per user (in code). |
| **4b**  | Display names                  | RLS or RPC for names; leaderboard entries have display_name. |
| **4c**  | Service + UI                   | LeaderboardService + LeagueLeaderboardView; entry from LeagueDetailView. |
| **4d**  | Optional: live + polish        | Live total or Season/Live toggle; tie-handling and formatting. |

---

## Files to add or touch (reference)

- **LeagueService.swift:** `loadLeagueMembers(leagueId:)`.
- **RosterService.swift** (or new **LeaderboardService.swift**): `loadAllRosterPicks(leagueId:)`; optionally `loadLeaderboard(leagueId:)` here or in LeagueService.
- **Profiles:** New migration for RLS “read profiles of same-league members”; optional helper to fetch profiles by user IDs.
- **Views:** `LeagueLeaderboardView.swift` (new).
- **LeagueDetailView.swift:** Add “Standings” / “Leaderboard” section or button → present/push leaderboard.
- **Models:** e.g. `LeagueLeaderboardEntry` (rank, userId, displayName, totalFantasyPoints) in LeagueService or a small LeaderboardModels file.

You can implement 4a → 4b → 4c in order, then 4d if you want live scoring and polish.
