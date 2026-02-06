# Quick Supabase Setup Guide 🚀

Your credentials are already configured! Now you just need to set up the database.

## Step 1: Run the SQL Migration (Create Tables)

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Click on your **fantasyball** project
3. Click **SQL Editor** in the left sidebar
4. Click **New query**
5. Copy and paste the entire contents of `supabase/migrations/20250205000000_initial_schema.sql`
6. Click **Run** (or press ⌘+Enter / Ctrl+Enter)

This creates 4 tables:
- `followed_teams` - Teams you follow
- `followed_players` - Players you follow  
- `fantasy_squads` - Your fantasy lineups
- `fantasy_squad_players` - Players in each lineup

## Step 2: Enable Anonymous Sign-In

1. In Supabase Dashboard, click **Authentication** in the left sidebar
2. Click **Providers**
3. Scroll down to find **Anonymous** provider
4. Toggle it **ON** (enable it)
5. Click **Save**

This lets the app create anonymous users so each device can sync data.

## Step 3: Test It!

1. Build and run your app in Xcode (⌘R)
2. Go to the **Following** tab
3. Tap the **+** button
4. Add a team name (e.g., "Lakers")
5. If it works, you'll see it appear in the list! 🎉

## Troubleshooting

**"Supabase not configured" message?**
- Make sure your URL and anon key are correct in `SupabaseConfig.swift`
- The URL should look like: `https://xxxxx.supabase.co`
- The anon key is a long JWT token

**"Couldn't load data" error?**
- Make sure you ran the SQL migration (Step 1)
- Make sure anonymous auth is enabled (Step 2)
- Check the Xcode console for error messages

**Tables don't exist?**
- Go back to SQL Editor and run the migration again
- Check for any error messages in red

## What Happens Next?

Once set up:
- ✅ Follow teams from the Home tab (tap the ⋯ menu on any game)
- ✅ Add teams/players in the Following tab
- ✅ Create fantasy squads in the Fantasy tab
- ✅ All data syncs to Supabase automatically!
