# Testing Fantasy Features Phase by Phase

Use this to verify each phase before moving to the next.

---

## Phase 2 – Leagues (create & join)

**What’s in scope:** Leagues tab, create league, join by code, my leagues list, league detail.

**What’s not yet in scope:** Home roster, league selector on Home (that’s Phase 3). Home still shows **favorites** only.

### 1. Apply migrations

From the project root:

```bash
npx supabase db push
```

Or in Supabase Dashboard: **SQL Editor** → run each migration in `supabase/migrations/` in order:

- `20250212110000_profiles_leagues_league_members.sql`

(You can skip `20250212120000_roster_picks.sql` until Phase 3 if you prefer.)

### 2. Run the app

1. Sign in (or sign up).
2. You should see **Home** (favorites) and **Players** as before, plus a third tab **Leagues**.

### 3. Test Create League

1. Open the **Leagues** tab.
2. Tap **Create League**.
3. Enter a name (e.g. "Test League"), pick capacity (e.g. 8), set a draft date in the future.
4. Tap **Create League**.
5. You should see the **Invite code** (e.g. 6 characters) and the invite link `sporttracker://join?code=...`.
6. Tap **Done**. You should be back on Leagues list and see your new league.

### 4. Test My Leagues list

1. On **Leagues**, you should see at least one league with name, status (e.g. "Open"), capacity, and draft date.
2. Tap a league → **League detail** with name, capacity, draft date, invite code.

### 5. Test Join League (second device or second account)

1. On another device (or sign out and sign up with a different account).
2. Open **Leagues** → **Join League**.
3. Enter the **exact** invite code from step 3 (case-insensitive).
4. Tap **Join League**. You should see success and the league in **My Leagues**.
5. Try joining again with the same code → should see "You are already in this league" (or similar).
6. Try joining with a wrong code → should see "No open league found" (or similar).

### 6. Optional: Leave league

- In league detail (or future UI), leaving = deleting your row from `league_members`. RLS allows users to delete their own membership. No in-app button yet; you can test via Supabase Dashboard if needed.

---

## Phase 3 – Home roster + league selector (after Phase 2 is verified)

**What gets added:** League selector on Home, roster loaded from `roster_picks`, Home shows roster for selected league (sorted by fantasy points, live at top). Manual “add to roster” for testing (e.g. from league detail).

**How to test Phase 3 when it’s re-enabled:**

1. Apply `20250212120000_roster_picks.sql` if not already applied.
2. Select a league on Home (picker). Home should load roster for that league (empty at first).
3. Add a few players to your roster (manual add from league detail or Players).
4. Confirm Home shows those players, sorted: live first by fantasy points, then rest by season average.
5. Switch league (or “No league”) and confirm list/empty state updates.

---

## Phase 4 – League standing (after Phase 3 is verified)

**What gets added:** League standings / leaderboard: rank league members by roster fantasy points (e.g. season totals or live), show position and points per league.

**How to test:** In a league with 2+ members and rosters, open league detail or a “Standings” tab; confirm members are ordered by points and display is correct.

---

## Phase 5 – Drafts (after Phase 4 is verified)

**What gets added:** Drafts table, start draft, snake draft UI, draft board, player pool, “Your pick”, realtime updates.

**How to test:** Run draft with 2+ members; confirm order, picks, and roster after completion.

---

## Current app state (for phase-by-phase testing)

- **Phase 2:** Implemented and **active**. Leagues tab = create, join, list, detail.
- **Phase 3:** Implemented and **active**. League selector + roster on Home; add/remove player; add-to-roster flow with player detail and confirmation.
- **Phase 4 – League standing:** Not implemented yet; add after Phase 3 is verified.
- **Phase 5 – Drafts:** Not implemented yet; add after Phase 4 is verified.
