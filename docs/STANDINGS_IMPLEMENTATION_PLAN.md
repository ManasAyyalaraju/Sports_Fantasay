# League Standings Tab – Implementation Plan

This document outlines how to implement the **Standings** tab (replacing Players tab) based on the Figma design.

---

## Answers to Design Questions

### 1. Do we need a `league_standings` table?

**No.** We compute standings **on-the-fly** from existing data:
- `roster_picks` → which players each user has in each league
- `player_game_stats` → all game stats with dates (already synced every 12h)
- `leagues` → `draft_date` for filtering

**Why compute on-the-fly:**
- ✅ Always accurate (no sync lag or inconsistency)
- ✅ Simpler (no extra table, RLS policies, or update jobs)
- ✅ Matches what HomeView already does for totals
- ✅ Data freshness: standings update automatically when `player_game_stats` syncs (every 12h)

**When to consider a table later:**
- If leaderboard queries become slow (unlikely with <1000 members)
- If you need historical snapshots ("standings as of week 5")
- If you want to pre-compute for faster reads (materialized view or cache table)

### 2. Is there a better approach?

**Yes—compute on-the-fly.** This is the recommended approach:
- Query `roster_picks` for all users in the league
- For each user's roster, fetch `player_game_stats` filtered by `game_date >= league.draft_date`
- Sum fantasy points per player, then per user
- Sort by total descending → assign ranks

This is exactly what HomeView's `totalRosterFantasyPoints` does, but for all members.

### 3. Draft functionality

**Skipped for now** (per user request). The "Schedule Draft" button can be a placeholder or hidden.

---

## Implementation Plan

### Phase 1: Remove Players Tab, Add Standings Tab

**Tasks:**

1. **Delete PlayersView**
   - Remove `Sport_Tracker-Fantasy/PlayersView.swift`
   - Remove any imports/references

2. **Update ContentView**
   - Remove Players tab (tag 1)
   - Add Standings tab (tag 1) with list icon (`list.number` or `list.bullet.clipboard`)
   - Keep Home (tag 0) and Leagues (tag 2)
   - Update tab bar: Home, Standings, Leagues

3. **Create StandingsView placeholder**
   - New file: `Sport_Tracker-Fantasy/Views/StandingsView.swift`
   - Basic structure: league selector, "Standings" title, empty state
   - Match Figma header style (gradient, league dropdown)

**Deliverable:** Standings tab exists and replaces Players tab; shows placeholder content.

---

### Phase 2: Backend – Load League Members + All Rosters + Compute Totals

**Tasks:**

1. **LeagueService – load league members**
   - Add `loadLeagueMembers(leagueId: UUID) async throws -> [LeagueMember]`
   - Query `league_members` where `league_id = leagueId` (RLS already allows members to read)
   - Return `id`, `league_id`, `user_id`, `joined_at`, `draft_order` (if present)

2. **RosterService – load all roster picks for a league**
   - Add `loadAllRosterPicks(leagueId: UUID) async throws -> [RosterPick]`
   - Query `roster_picks` where `league_id = leagueId` (RLS allows league members to read all picks)
   - Returns picks for **all users** in the league

3. **SupabaseNBAService – batch fetch game stats for multiple players**
   - Add `fetchGameStatsForPlayers(playerIds: Set<Int>, onOrAfterDate: Date?, season: String) async throws -> [PlayerGameStats]`
   - Query `player_game_stats` where `player_id IN (...)` and optionally `game_date >= onOrAfterDate`
   - Returns all matching game stats (for computing totals)

4. **LeaderboardService (new) – compute standings with live stats**
   - New file: `Sport_Tracker-Fantasy/Services/LeaderboardService.swift`
   - Add `loadStandings(leagueId: UUID, useSeasonAverages: Bool = false) async throws -> [LeagueStandingsEntry]`
   - **Implementation:**
     - Load league (to get `draftDate` and `season`)
     - Load all league members
     - Load all roster picks for the league (group by `user_id` → `[player_id]`)
     - For each member:
       - Get their roster player IDs
       - If `useSeasonAverages` (testing): fetch `season_averages` for those players, sum `fantasyScore`
       - Else (production with live stats):
         - **Live games:** Check `LiveGameManager` for any live players; add `LivePlayerStat.fantasyPoints` for this game
         - **Completed games:** Fetch `player_game_stats` for those players where `game_date >= draftDate`, sum `fantasyPoints` per game
         - **Total = live FP + completed games FP** (real-time updates for active games)
     - Sort by total descending
     - Assign ranks (handle ties: 1, 2, 2, 4)
   - Return `[LeagueStandingsEntry]` with `rank`, `userId`, `totalFantasyPoints`
   - **Note:** Standings update in real-time for players currently playing (via `LiveGameManager`)

**Model:**
```swift
struct LeagueStandingsEntry: Identifiable {
    let id: UUID // userId
    let rank: Int
    let userId: UUID
    let totalFantasyPoints: Double
}
```

**Deliverable:** Can compute standings for a league in code (no UI yet).

---

### Phase 3: Display Names (RLS on Profiles)

**Tasks:**

1. **Migration: RLS policy on `profiles`**
   - New migration: `supabase/migrations/YYYYMMDDHHMMSS_profiles_league_members_read.sql`
   - Policy: "League members can read profiles of users in the same league"
   - SQL:
     ```sql
     CREATE POLICY "League members can read same-league profiles"
       ON public.profiles FOR SELECT
       TO authenticated
       USING (
         EXISTS (
           SELECT 1 FROM public.league_members lm1
           WHERE lm1.user_id = auth.uid()
           AND EXISTS (
             SELECT 1 FROM public.league_members lm2
             WHERE lm2.league_id = lm1.league_id
             AND lm2.user_id = profiles.id
           )
         )
       );
     ```

2. **LeagueService or new helper – fetch profiles**
   - Add `fetchProfiles(userIds: [UUID]) async throws -> [UUID: Profile]` (or `[Profile]`)
   - Query `profiles` where `id IN (...)` (RLS allows if users share a league)
   - Map `user_id` → `display_name` (fallback to email or "Member" if null)

3. **Update LeaderboardService**
   - After computing standings, fetch profiles for all member `user_id`s
   - Add `displayName: String` to `LeagueStandingsEntry`
   - Use `display_name` from profile, fallback to email or "Member"

**Model update:**
```swift
struct LeagueStandingsEntry: Identifiable {
    let id: UUID // userId
    let rank: Int
    let userId: UUID
    let displayName: String
    let totalFantasyPoints: Double
}
```

**Deliverable:** Standings entries have display names.

---

### Phase 4: Standings UI (Figma Design)

**Tasks:**

1. **StandingsView – header (Figma style)**
   - Gradient header (same blue-green as Home)
   - League selector dropdown ("Vyom's League" with chevron)
   - Title "Leaders" (large bold white)
   - "Schedule Draft" button (placeholder, no action yet)
   - Hamburger menu icon (optional, for league settings later)

2. **Timeframe filters (segmented control)**
   - Three buttons: "Overall", "Today", "Last Week"
   - "Overall" is default (highlighted)
   - "Today" and "Last Week" are placeholders for now (can filter by date range later)
   - For MVP: only "Overall" works (uses `draft_date` cutoff)

3. **Leaderboard list**
   - Scrollable list of `LeagueStandingsEntry`
   - Each row:
     - **Left:** Team/display name (large bold white), user name below (smaller gray)
     - **Right:** Total fantasy points (large bold white number)
   - Highlight current user's row (different background or border)
   - Empty state if no members or no one has roster picks

4. **Loading and error states**
   - Loading spinner while fetching
   - Error message if fetch fails
   - Pull-to-refresh to reload standings

5. **Integration**
   - StandingsView uses `LeaderboardService`
   - When league is selected, call `loadStandings(leagueId:)`
   - For testing: use `useSeasonAverages: true` so adding players shows points immediately
   - In production: use `useSeasonAverages: false` (actual points after draft date)

**Deliverable:** Standings tab matches Figma design; shows ranked list with names and totals.

---

### Phase 5: Polish and Edge Cases

**Tasks:**

1. **Tie handling**
   - Same rank for ties (e.g., 1, 2, 2, 4)
   - Sort ties by display name or user ID for stability

2. **Empty states**
   - No league selected: "Select a league to see standings"
   - No members: "No members in this league"
   - No roster picks: "No rosters yet" or "Standings will appear after draft"

3. **Performance**
   - Cache standings in memory (invalidate on refresh or when roster changes)
   - Batch fetch game stats (one query for all player IDs)
   - Consider pagination if league has 100+ members (unlikely for MVP)

4. **Refresh**
   - Pull-to-refresh reloads standings
   - FAB on Standings tab (if desired) triggers refresh
   - Auto-refresh when returning to tab (optional)

**Deliverable:** Standings tab is polished and handles edge cases.

---

## Summary Table

| Phase | Focus | Deliverable |
|-------|-------|------------|
| **1** | Remove Players tab, add Standings tab | Standings tab exists with placeholder |
| **2** | Backend: members + rosters + compute totals | `LeaderboardService.loadStandings()` works |
| **3** | Display names (RLS on profiles) | Standings entries have display names |
| **4** | Standings UI (Figma design) | StandingsView matches Figma |
| **5** | Polish and edge cases | Production-ready standings |

---

## Files to Create/Modify

**New files:**
- `Sport_Tracker-Fantasy/Views/StandingsView.swift`
- `Sport_Tracker-Fantasy/Services/LeaderboardService.swift`
- `supabase/migrations/YYYYMMDDHHMMSS_profiles_league_members_read.sql`

**Modify:**
- `Sport_Tracker-Fantasy/ContentView.swift` (remove Players tab, add Standings tab)
- `Sport_Tracker-Fantasy/Services/LeagueService.swift` (add `loadLeagueMembers`)
- `Sport_Tracker-Fantasy/Services/RosterService.swift` (add `loadAllRosterPicks`)
- `Sport_Tracker-Fantasy/Services/SupabaseNBAService.swift` (add `fetchGameStatsForPlayers`)

**Delete:**
- `Sport_Tracker-Fantasy/PlayersView.swift` (if exists)

---

## Testing Approach

**Testing (use season averages):**
- Create a league
- Add players to rosters for multiple users
- Open Standings tab → should show totals based on season averages
- Verify ranks, names, and totals

**Production (actual points after draft date):**
- After live draft exists, switch to `useSeasonAverages: false`
- Standings only count games on or after `league.draft_date`
- Verify totals match Home screen totals (for current user)

---

## Notes

- **No `league_standings` table needed** — compute on-the-fly
- **"Schedule Draft" button** — placeholder for now (no action)
- **"Today" and "Last Week" filters** — placeholders; implement date-range filtering later if needed
- **Performance:** On-the-fly computation is fast enough for MVP (<100 members, <1000 games per league)
