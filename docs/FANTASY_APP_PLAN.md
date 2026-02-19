# Fantasy App Plan: Leagues, Draft & Home

This document outlines how to extend the app into a full fantasy league product: signup, leagues, invites, snake draft, and home screen with multi-league support. **Planning only**—no implementation.

---

## 1. Scope Summary

| Feature | Description |
|--------|--------------|
| **Auth** | Users sign up / sign in (email or OAuth). |
| **Leagues** | User creates a league with fixed capacity and draft date; can invite friends or share a link. |
| **Join league** | Others join via invite link or code; league fills up to capacity. |
| **Draft** | Snake draft on the chosen date; all league members must be present. Uses existing player list (season averages, last 5 games). |
| **Roster** | Each user’s drafted players per league; shown on home. |
| **Home** | Toggle between leagues; show roster ranked by fantasy points; live players jump to top. |

---

## 2. How It Fits What You Already Have

- **NBA data:** Keep using your existing player list, season averages, and last-5-games (from API-Sports or Supabase once that’s in place). Draft UI uses this same data.
- **Live:** Keep `LiveGameManager` and live stats API for “player is playing live” and live fantasy points. Home sort = fantasy points, with live players forced to top.
- **Supabase:** Use the same project for both NBA reference data (existing plan) and **app data**: auth, leagues, members, draft state, roster (drafted players). One backend.

---

## 3. Data Model (Supabase)

All of this lives in the same Supabase project as your NBA tables.

### 3.1 Auth

- Use **Supabase Auth** (email/password or magic link; optionally Google/Apple).
- After sign-in you have `auth.uid()` (UUID) for the current user. Use this as the stable user id everywhere.

### 3.2 App tables

**`profiles`** (optional but recommended)

- `id` (uuid, PK) = `auth.uid()`
- `display_name`, `avatar_url`, `created_at`, `updated_at`
- Filled on first sign-in (trigger or app).

**`leagues`**

- `id` (uuid, PK)
- `name` (text)
- `capacity` (int) — e.g. 8, 10, 12
- `draft_date` (timestamptz) — when the draft runs
- `invite_code` (text, unique) — short code for “join by link” (e.g. `ABC12`)
- `creator_id` (uuid, FK → auth.users / profiles)
- `status` — e.g. `"open"` (joining), `"draft_scheduled"`, `"draft_in_progress"`, `"draft_completed"`, `"active"`
- `season` (text) — e.g. `"2024"` (aligns with your NBA season)
- `created_at`, `updated_at`

**`league_members`**

- `id` (uuid, PK)
- `league_id` (uuid, FK → leagues)
- `user_id` (uuid, FK → auth)
- `joined_at` (timestamptz)
- `draft_order` (int, nullable) — 1..capacity, set when draft starts (snake order for round 1)
- Unique on `(league_id, user_id)`.

**`drafts`** (one per league)

- `id` (uuid, PK)
- `league_id` (uuid, FK → leagues, unique)
- `status` — `"pending"`, `"in_progress"`, `"completed"`
- `current_round` (int, default 1)
- `current_pick_index` (int) — 0-based index in snake order for this round
- `snake_order` (int[] or jsonb) — e.g. `[user_id_1, user_id_2, ..., user_id_n, user_id_n, ..., user_id_1]` per round, or derive from `league_members.draft_order` + round parity
- `started_at`, `completed_at` (timestamptz, nullable)
- `created_at`, `updated_at`

**`roster_picks`** (drafted players per league)

- `id` (uuid, PK)
- `league_id` (uuid, FK → leagues)
- `user_id` (uuid, FK)
- `player_id` (int) — your NBA player id (API-Sports)
- `pick_number` (int) — 1, 2, 3… global pick number in draft
- `round` (int)
- `created_at`
- Unique on `(league_id, player_id)` (a player can only be drafted once per league).

### 3.3 Invite link

- Format: `yourapp://join?code=ABC12` or `https://yourapp.com/join?code=ABC12`
- Resolve `invite_code` → `league_id`, then insert into `league_members` for current user (and check capacity).

### 3.4 RLS (high level)

- **profiles:** User can read/write own row.
- **leagues:** Anyone authenticated can read; only creator can update (e.g. draft date, status); creator can insert.
- **league_members:** Members of the league can read; users can insert themselves (join) when league is open and under capacity; only system/creator might delete (e.g. leave league).
- **drafts:** League members can read; only your app logic (or a small Edge Function) should update draft state and picks.
- **roster_picks:** League members can read; inserts only during draft by the user whose turn it is (enforced in app or DB function).

---

## 4. User Flows

### 4.1 Create league

1. User taps “Create league.”
2. Form: league name, capacity (e.g. 8), draft date/time (date picker).
3. App creates row in `leagues` (status `open`), creates `league_members` for creator (e.g. `draft_order` = null for now).
4. Generate and show invite link/code (e.g. `yourapp://join?code=XYZ`).

### 4.2 Join league

1. User opens invite link or enters code.
2. App resolves code → league; checks capacity and that user isn’t already a member.
3. Insert `league_members`; optionally notify creator (later).

### 4.3 Draft day (snake draft)

1. **Before draft:** All members see “Draft at [date/time].” When draft date/time is reached, creator (or first person to open) “starts draft.”
2. **Start draft:**  
   - Set league status to `draft_scheduled` → `draft_in_progress`.  
   - Create `drafts` row for league.  
   - Assign `draft_order` to each member (random or predetermined): 1..N for round 1.  
   - Snake: round 1 order = [1,2,…,N], round 2 = [N,…,2,1], etc. Store order in `drafts` or compute from `league_members.draft_order` and round parity.
3. **During draft:**  
   - Each user sees “Your pick” or “Waiting for [user]” based on `drafts.current_round` and `current_pick_index`.  
   - When it’s their turn, user selects an NBA player from your existing player list (season averages + last 5 games).  
   - App inserts `roster_picks` (league_id, user_id, player_id, pick_number, round) and advances `current_pick_index` (and `current_round` when a round finishes).  
   - Other clients can poll or use Supabase Realtime on `drafts` and `roster_picks` to update the draft board.
4. **After last pick:** Set draft status to `completed`, league status to `active`.

### 4.4 Home screen (multi-league + roster by fantasy points)

1. **League selector:** User can be in many leagues. Show a picker/toggle (or dropdown) for “Current league.” Store selected league in local state (or user preference in `profiles`).
2. **Load roster:** For selected league, load `roster_picks` where `league_id = selected` and `user_id = me`, then resolve `player_id` to player info (from Supabase `players` + `season_averages` or from your existing API/cache).
3. **Rank by fantasy points:**  
   - For each roster player, get current fantasy points:  
     - If player is **live:** use live stats from `LiveGameManager` (or API-Sports live endpoint) and compute fantasy points.  
     - If not live: use season averages (or last 5 games average) from your existing data.  
   - Sort list by this fantasy score (descending).  
   - **Live at top:** Same as today—partition into “live” and “not live,” sort live by live fantasy points, then non-live by season (or last 5) fantasy points. So: live players first (sorted by live points), then rest (sorted by season/last5 points).
4. **UI:** Reuse your current home list concept (cards with player, team, points, live indicator), but data source is “roster for selected league” instead of “favorites.”

---

## 5. Draft UI (Concept)

- **Player pool:** Reuse `PlayersView`-style list (or a modal): same data (season averages, last 5 games), filter out already-drafted players for this league (query `roster_picks` for league).
- **Draft board:** Shows draft order, round, current pick, and each cell filled with player name as picks happen. Read from `roster_picks` + `drafts`.
- **My turn:** Big “Your pick” state; tap player to draft them and advance state.
- **Real-time:** Supabase Realtime subscriptions on `drafts` and `roster_picks` for this league so everyone sees updates without refresh.

---

## 6. Suggested Implementation Order

Do these in phases so you always have something working.

**Phase 1 – Auth & profiles**

- Enable Supabase Auth (email or magic link).
- Optional `profiles` table + RLS.
- Sign up / sign in screens; after login, show main app (tabs).
- Optional: persist “selected league” in `profiles` or AppStorage.

**Phase 2 – Leagues (create & join)**

- Tables: `leagues`, `league_members`.
- Create league screen (name, capacity, draft date); generate `invite_code`; create league + add creator to `league_members`.
- Join by link/code: resolve code → league, check capacity, add member.
- Leagues list screen: “My leagues” (where I’m in `league_members`).

**Phase 3 – Home: league selector + roster**

- No draft yet; manually add a few “roster” rows for testing (or a simple “Add player to roster” for your user in a league).
- Home: league picker → load roster for selected league → show players ranked by season fantasy points (reuse current home layout).
- Add “live at top” using existing `LiveGameManager` and live stats.

**Phase 4 – League standing**

- League standings / leaderboard: rank league members by roster fantasy points (e.g. season totals or live).
- Show position and points per league (league detail or a “Standings” view).

**Phase 5 – Draft (snake)**

- Table `drafts` and `roster_picks`.
- “Start draft” flow: set draft order (random), create `drafts` row, set league to `draft_in_progress`.
- Draft screen: show draft board + player pool; on your turn, pick player → insert `roster_picks`, advance draft state.
- Use Realtime or polling so all participants see updates.
- On last pick, set draft `completed` and league `active`.

**After Phase 5 – Polish**

- Invite link handling (universal link / deep link for `yourapp://join?code=...`).
- Notifications (optional): “Draft starting in 15 minutes,” “Your pick,” etc.
- Home: final sort (live first by live fantasy points, then rest by season/last5).

---

## 7. Cross-Reference with Existing Pieces

| Existing | Use in fantasy plan |
|----------|----------------------|
| `LiveScoresAPI` / Supabase NBA tables | Player list, season averages, last 5 games for draft and home. |
| `LiveGameManager` | “Is this roster player live?” and live fantasy points; home sort puts live at top. |
| `HomeView` | Becomes “roster for selected league” sorted by fantasy points; data source switches from favorites to roster. |
| `PlayersView` | Unchanged for browsing; reused inside draft as player pool. |
| `ContentView` | Add auth gate (signed out → sign in/sign up); keep tabs; league selector can live on Home or in nav. |
| Favorites | Can remain local (AppStorage) for “my favorite players” outside leagues, or deprecate in favor of roster-only home. |

---

## 8. Summary

- **Auth:** Supabase Auth; one user id per user.
- **Leagues:** Create (name, capacity, draft date, invite code); join via link/code; store in `leagues` + `league_members`.
- **Draft:** Snake draft on draft date; state in `drafts`, picks in `roster_picks`; same player list (season avg + last 5) you already have.
- **Home:** Multi-league toggle; roster for selected league; rank by fantasy points; live players at top using existing live stats.
- **Order:** Auth → Leagues (create/join) → Home with roster + league selector → Draft flow → Polish.

This plan keeps your current NBA and live data flow, and adds a clear path to a full league-based fantasy product on Supabase.