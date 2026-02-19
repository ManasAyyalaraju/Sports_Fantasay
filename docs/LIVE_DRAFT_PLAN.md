# Live Draft Functionality – Plan (Incremental Phases)

This document plans the **live draft** feature (Phase 5) so it can be built incrementally. It assumes Phases 1–4 are done as described in [ACCOMPLISHED.md](./ACCOMPLISHED.md): Auth, Leagues, Roster, and League Standings.

---

## Current State (Where We Are)

| Area | Status | Relevant for draft |
|------|--------|--------------------|
| **Leagues** | Done | `leagues`, `league_members`; `league_members.draft_order` exists (nullable, 1..capacity). League status: `open` → `draft_scheduled` / `draft_in_progress` / `draft_completed` / `active`. |
| **Roster** | Done | `roster_picks` (league_id, user_id, player_id, pick_number, round). RosterService: add/remove, load roster. |
| **Drafts** | Not started | No `drafts` table yet. No “start draft” or draft UI. |

References: [FANTASY_APP_PLAN.md](./FANTASY_APP_PLAN.md) (draft data model and flow), [TESTING_PHASES.md](./TESTING_PHASES.md) (Phase 5 testing).

---

## Scope: What “Live Draft” Means Here

- **Snake draft:** Round 1 order = 1, 2, …, N; round 2 = N, …, 2, 1; and so on.
- **One draft per league:** When the league’s draft date/time is reached (or creator starts), one draft runs until all rounds are complete.
- **Live experience:** All participants see the same state; when one user picks, others see it without manual refresh (Realtime or short polling).
- **Player pool:** Same data as today (players from Supabase + season averages / last games). Already-drafted players for that league are excluded.
- **Outcome:** After the last pick, draft is `completed`, league becomes `active`, and rosters are exactly the `roster_picks` rows created during the draft (no separate “post-draft sync”).

---

## Phase Overview

| Phase | Name | Goal | Delivered in this phase |
|-------|------|------|-------------------------|
| **5.1** | Draft schema & start draft | Backend and “start draft” flow | `drafts` table, RLS, assign draft order, create draft, set league status |
| **5.2** | Draft service & state | App can read/write draft state and picks | DraftService: load draft, advance pick, “whose turn”, optional Realtime |
| **5.3** | Draft lobby & “Your pick” | Users see draft status and know when it’s their turn | Draft lobby screen: round, pick #, “Your pick” / “Waiting for [name]” |
| **5.4** | Player pool & pick flow | User can pick a player on their turn | Player pool (exclude drafted), tap to pick → insert roster_pick + advance |
| **5.5** | Draft board | Visual grid of all picks | Draft board UI: rounds × slots, cells fill as picks happen |
| **5.6** | Realtime & completion | Live updates and clean finish | Realtime on `drafts` + `roster_picks`; on last pick: draft completed, league active |

Each phase is testable on its own before moving to the next.

---

## Phase 5.1 – Draft Schema & Start Draft

**Goal:** Persist draft state and support “start draft” (assign order, create draft, update league).

### 5.1.1 Database

- **New table: `drafts`** (one row per league when draft has started)
  - `id` (uuid, PK)
  - `league_id` (uuid, FK → leagues, UNIQUE)
  - `status`: `pending` | `in_progress` | `completed`
  - `current_round` (int, default 1)
  - `current_pick_index` (int, 0-based index in the **current round’s** snake order, e.g. 0 to capacity-1)
  - `total_picks_made` (int, default 0) — optional but useful: global count of roster_picks for this league during this draft
  - `started_at`, `completed_at` (timestamptz, nullable)
  - `created_at`, `updated_at`

- **Snake order:** No need to store a long `snake_order` array. Derive from `league_members.draft_order`:
  - Round 1 order = members sorted by `draft_order` ascending (1, 2, …, N).
  - Round 2 order = same reversed (N, …, 1).
  - So for round `r`, pick index `i` (0-based) → user at position `(r odd ? i : (N-1-i))` in the 1..N order.

- **RLS:** League members can SELECT `drafts` for their leagues. INSERT/UPDATE: either via service role (e.g. Edge Function “start draft”) or via a DB function that checks “creator starting draft” / “user making their pick” so the app doesn’t need service role in client.

### 5.1.2 Start-draft flow

- **Who can start:** League creator, or any member (per product choice). Suggested: creator only for 5.1.
- **When:** League status is `open` or `draft_scheduled` and (optionally) draft date/time is reached or “Start draft” is tapped.
- **Steps:**
  1. Validate: league full (members count = capacity), status allows start.
  2. Assign `draft_order` to each `league_members` row (random 1..N, no duplicates).
  3. INSERT `drafts` (league_id, status = `in_progress`, current_round = 1, current_pick_index = 0, started_at = now()).
  4. UPDATE `leagues` SET status = `draft_in_progress`.

**Implementation options:**

- **A) Edge Function** (e.g. `start-draft`): Receives `league_id`; uses service role to update `league_members` and create `drafts` and update `leagues`. App calls this with JWT; function verifies caller is league creator (or member).
- **B) App + RLS:** If RLS allows league creator to UPDATE `league_members` and INSERT into `drafts`, app can do the same steps with anon + session. Requires migrations that allow creator to set `draft_order` and a policy (or function) to INSERT `drafts` when league is open.

Recommendation: start with **Edge Function** for 5.1 so all “start draft” logic is in one place and you don’t need complex RLS for `drafts` writes.

### 5.1.3 App (minimal for 5.1)

- **League detail:** When league status is `open` (or `draft_scheduled`) and user is creator, show **“Start draft”** button.
- Button calls Edge Function (or future DraftService.startDraft) which runs the steps above.
- After success, league status becomes `draft_in_progress`; show “Draft in progress” and a way to open the draft screen (can be a simple “Open draft” link for 5.1).

### 5.1.4 Deliverables & test

- Migration: `drafts` table + RLS (SELECT for league members).
- Edge Function `start-draft` (or equivalent) + secrets if needed.
- “Start draft” in app; verify in DB: `league_members.draft_order` set, `drafts` row exists, `leagues.status` = `draft_in_progress`.

---

## Phase 5.2 – Draft Service & State

**Goal:** App can load draft state, compute “whose turn,” and advance the draft when a pick is made.

### 5.2.1 DraftService (Swift)

- **Models:** e.g. `Draft`, `DraftState` (current_round, current_pick_index, status, started_at, league_id).
- **Load draft:** `loadDraft(leagueId:)` → fetch `drafts` for league; fetch `league_members` (with draft_order, user_id, and optionally display_name from profiles) for that league. Return a single “draft state” object that includes:
  - Round, pick index, list of members in snake order for current round.
  - **Whose turn:** From current_round + current_pick_index + snake order → one user_id (and display_name).
- **Advance pick:** `makePick(leagueId:userId:playerId:)`:
  - Verify it’s this user’s turn (using same snake logic).
  - INSERT `roster_picks` (league_id, user_id, player_id, pick_number = total_picks_made + 1, round = current_round).
  - UPDATE `drafts` SET total_picks_made = total_picks_made + 1, current_pick_index = current_pick_index + 1 (and if at end of round: current_round += 1, current_pick_index = 0). If total_picks_made reaches (capacity * num_rounds), set status = `completed`, completed_at = now(), and UPDATE league status to `active`.

**Rounds:** Typical snake draft has a fixed number of rounds (e.g. 15 rounds for 12 players = 180 picks). Define “number of rounds” per league (e.g. from `leagues` or constant). When total_picks_made == capacity * num_rounds, draft is complete.

### 5.2.2 RLS for writes

- **roster_picks:** Already allow INSERT for authenticated user with user_id = auth.uid(). For draft, we must ensure inserts only during draft and only when it’s that user’s turn. That can be enforced in app + optional DB trigger/function, or by having “make pick” go through an Edge Function that uses service role and validates turn.
- **drafts:** UPDATE (current_round, current_pick_index, total_picks_made, status, completed_at) must be restricted. Options: (1) Edge Function only (recommended for 5.2), or (2) RLS policy that allows update only if a function says “current user is the one whose turn it is” (complex).

Recommendation: **“Make pick” via Edge Function** that: validates turn, inserts roster_pick, updates draft (and league on completion). App calls this with league_id, player_id; user is from JWT.

### 5.2.3 Realtime (optional in 5.2)

- Subscribe to `drafts` and `roster_picks` for the league so the app can refresh state when another client advances the draft. Can be added in 5.2 or 5.6.

### 5.2.4 Deliverables & test

- DraftService: load draft, compute “whose turn,” call make-pick Edge Function.
- Edge Function `make-pick` (or `draft-pick`): validate turn, insert roster_pick, update drafts (and league when done).
- Unit/logic test: start draft, then call makePick for each turn in order and verify roster_picks and draft row in DB.

---

## Phase 5.3 – Draft Lobby & “Your Pick”

**Goal:** A dedicated draft screen that shows current round, current pick number, and either “Your pick” or “Waiting for [display name].”

### 5.3.1 UI

- **Entry:** From League detail, when league status is `draft_in_progress`, show **“Join draft”** or **“Open draft”** that pushes (or presents) **DraftLobbyView**.
- **DraftLobbyView (minimal):**
  - Title: “Draft” or league name.
  - Display: “Round X, Pick Y” (or “Pick #Z” globally).
  - Big state: **“Your pick”** when current user is the one whose turn it is; **“Waiting for [Name]”** otherwise.
  - Optional: list of members and their draft order for the current round.
  - No player pool yet (that’s 5.4); “Your pick” can show a placeholder “Select player” that does nothing, or a button that opens the pool.

### 5.3.2 Data

- Use DraftService: on appear, load draft state; optionally poll every few seconds or use Realtime so “Your pick” / “Waiting for…” updates when someone else picks.

### 5.3.3 Deliverables & test

- DraftLobbyView with round/pick and “Your pick” / “Waiting for [Name]”.
- With two accounts, start draft and confirm correct user sees “Your pick” and the other sees “Waiting for [Creator]” (or vice versa depending on draft order).

---

## Phase 5.4 – Player Pool & Pick Flow

**Goal:** When it’s the user’s turn, they can open a player list (pool), exclude already-drafted players, and tap a player to pick them; draft advances and others see the update.

### 5.4.1 Player pool

- **Source:** Same as current app: players from Supabase (e.g. `players` + `season_averages` for current season). Optionally reuse SupabaseNBAService / existing player loading.
- **Exclude:** All player_ids already in `roster_picks` for this league (drafted so far). Load roster_picks for league once and filter.
- **UI:** List or grid of players (photo, name, team, position, season avg fantasy pts). Search/filter by name or team. Can be a sheet from DraftLobbyView or a pushed view.

### 5.4.2 Pick flow

- User taps a player → confirm “Draft [Name]?” → call DraftService.makePick(leagueId, playerId) (user from session). On success: close pool, refresh draft state (or Realtime updates it). Next user sees “Your pick”.
- If makePick fails (e.g. not your turn, player already taken), show error and refresh state.

### 5.4.3 Edge cases

- Double-tap: disable button or ignore second request until first completes.
- Already drafted: pool already excludes them; if someone else drafts same player between open and tap, server returns error and client refreshes pool and state.

### 5.4.4 Deliverables & test

- Draft player pool view (filtered list), tap to pick, success/error handling.
- Run a full 2-member draft (e.g. 2 rounds): each user picks in turn, verify roster_picks and final roster on Home.

---

## Phase 5.5 – Draft Board

**Goal:** A visual “draft board”: rows = rounds, columns = pick order in round (or one row per pick #); cells show player name (and optionally team/position) as picks are made.

### 5.5.1 Data

- Load `roster_picks` for league ordered by pick_number (or round, then order within round). Join to players (and optionally teams) for names. Draft state gives current round/pick so you can highlight “current cell”.

### 5.5.2 UI

- Grid: e.g. rounds 1..R, picks 1..N per round; each cell = “Pick #X” and player name when filled. Empty cells for future picks. Highlight the “current pick” cell.
- Optional: show who made each pick (user display name) in the cell or in a legend.

### 5.5.3 Deliverables & test

- DraftBoardView (tab or section in draft screen). All participants see the same board; when one picks, board updates (poll or Realtime).

---

## Phase 5.6 – Realtime & Completion

**Goal:** All clients see draft state and board update live; when the last pick is made, draft and league status are set correctly and users see “Draft complete” (and can return to league/Home).

### 5.6.1 Realtime

- Subscribe to Supabase Realtime for:
  - `drafts` (filter by league_id): so when current_round, current_pick_index, status change, all clients update.
  - `roster_picks` (filter by league_id): so when a new pick is inserted, draft board and pool update.
- On receiving an event, refresh draft state (and roster list for pool) from server so you don’t rely on local ordering.

### 5.6.2 Completion

- Already in 5.2: when last pick is made, Edge Function sets draft status = `completed`, completed_at = now(), league status = `active`.
- In app: when draft status becomes `completed`, show an alert or banner “Draft complete!” and optionally auto-navigate to league detail or Home. Disable “Your pick” / pool; show draft board as read-only.

### 5.6.3 Optional

- Pick timer (e.g. 90 seconds per pick): countdown in UI; if time runs out, auto-skip (e.g. assign “best available” or leave slot empty — product decision).
- Notifications: “Draft starting in 15 min,” “Your pick” — can be a later phase.

### 5.6.4 Deliverables & test

- Realtime subscriptions; two devices both in draft see updates without refresh.
- Complete a full draft; verify league status = active, draft status = completed, and Home shows correct rosters for both users.

---

## Dependencies Between Phases

```
5.1 (schema + start draft)
  → 5.2 (DraftService + make-pick)
       → 5.3 (lobby + "Your pick")
            → 5.4 (player pool + pick flow)
                 → 5.5 (draft board)
                      → 5.6 (realtime + completion)
```

- 5.1 must be done first (schema and start flow).
- 5.2 depends on 5.1 (need draft row and draft_order to compute turn).
- 5.3 depends on 5.2 (need DraftService state).
- 5.4 depends on 5.3 (need lobby to open pool from “Your pick”).
- 5.5 can be built after 5.2 (only needs roster_picks + draft state); can ship with 5.3 or 5.4.
- 5.6 can be added anytime after 5.2; best UX after 5.4 so multiple users see each other’s picks live.

---

## Summary Table

| Phase | Focus | Backend | App |
|-------|--------|--------|-----|
| 5.1 | Schema & start | `drafts` table, RLS, start-draft Edge Function | “Start draft” in league detail |
| 5.2 | State & advance | make-pick Edge Function | DraftService (load, whose turn, makePick) |
| 5.3 | Lobby | — | DraftLobbyView: round, pick, “Your pick” / “Waiting for…” |
| 5.4 | Picking | — | Player pool (exclude drafted), tap to pick |
| 5.5 | Board | — | Draft board grid (rounds × picks) |
| 5.6 | Live & done | — | Realtime, completion UI |

---

## Doc History

- Created: plan for incremental live draft (Phase 5), aligned with ACCOMPLISHED.md and FANTASY_APP_PLAN.md.
