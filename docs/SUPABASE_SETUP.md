# Supabase Setup Guide (First Time)

This guide walks you through creating a Supabase project and connecting it to the Sport Tracker Fantasy app.

---

## Part 1: Create Your Supabase Project (in the browser)

### Step 1: Sign up / Sign in

1. Go to **[supabase.com](https://supabase.com)** and click **Start your project**.
2. Sign in with **GitHub** (easiest), or create an account with email.

### Step 2: Create a new project

1. Click **New project**.
2. Choose your **Organization** (or create one).
3. Fill in:
   - **Name:** e.g. `Sport Tracker Fantasy` or `nba-fantasy`.
   - **Database password:** Create a strong password and **save it somewhere safe**. You need it for direct DB access (e.g. SQL Editor); the app does **not** use this.
   - **Region:** Pick the one closest to you (or your users) for lower latency.
4. Click **Create new project**. Wait 1–2 minutes for the project to be ready.

### Step 3: Get your project URL and API key

1. In the left sidebar, click **Project Settings** (gear icon at the bottom).
2. Click **API** in the left menu.
3. You’ll see:
   - **Project URL** — e.g. `https://xxxxxxxxxxxx.supabase.co`
   - **Project API keys:**
     - **anon (public)** — safe to use in the iOS app. This is the one we use.
     - **service_role** — never put this in the app; only for server/sync scripts.

Copy the **Project URL** and the **anon public** key. You’ll add them to the app in Part 2.

---

## Part 2: Add Supabase to the iOS App

### Step 1: Add your credentials

1. Open the project in **Xcode**.
2. Open **Sport_Tracker-Fantasy → Constants → SupabaseConfig.swift**.
3. Replace the two values with your real credentials from the Supabase dashboard:
   - `supabaseURL`: your **Project URL** (e.g. `"https://xxxxxxxxxxxx.supabase.co"`).
   - `supabaseAnonKey`: your **anon public** key.

   The file starts with placeholder values so the app builds and runs before you have a project; once you paste your URL and key, the app will talk to your Supabase project.

**Tip:** Don’t commit real keys to git. If you’re sharing the repo, leave the placeholders in and use a local-only copy or environment config for your keys.

### Step 2: Add the Supabase Swift package (if not already added)

1. In Xcode: **File → Add Package Dependencies…**
2. In the search field, paste:  
   `https://github.com/supabase/supabase-swift`
3. Click **Add Package**.
4. When asked which products to add, select **Supabase** and add it to the **Sport_Tracker-Fantasy** target.
5. Click **Add Package**.

### Step 3: Confirm the app uses Supabase

- The app initializes Supabase in **Sport_Tracker_FantasyApp.swift** using `SupabaseManager.shared`.
- You can add a simple test (e.g. sign in or read a table) later; for now, building and running without errors means the setup works.

---

For a summary of what’s in place (Supabase, schema, Edge Function, cron), see **[ACCOMPLISHED.md](./ACCOMPLISHED.md)**.

---

## Part 3: Quick reference

| What              | Where in Supabase                    |
|-------------------|--------------------------------------|
| Project URL       | Project Settings → API → Project URL |
| Anon (public) key | Project Settings → API → anon public  |
| Database tables   | Table Editor                         |
| Run SQL           | SQL Editor                           |
| Auth users        | Authentication → Users               |

---

## Next steps (after basics)

- **Auth:** Enable Email (or Magic Link) in **Authentication → Providers** and later add sign-in/sign-up screens.
- **Database:** When you’re ready, run the SQL from **SUPABASE_PLAN.md** and **FANTASY_APP_PLAN.md** to create tables (e.g. `profiles`, `leagues`, `league_members`).
- **RLS:** Turn on Row Level Security and add policies so users only see their own data.
- **Cron (sync reference data):** To run the **sync-reference-data** Edge Function every 12 hours, see **[CRON_SETUP.md](./CRON_SETUP.md)**.

You’re done with the basics when: (1) project exists on Supabase, (2) URL and anon key are in `SupabaseConfig.swift`, and (3) the app builds and runs.
,