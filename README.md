# Sport Tracker Fantasy

An iOS app for tracking live sports scores and managing fantasy lineups. Built with SwiftUI and Supabase.

## Features

- **Home** – NBA live scores and upcoming games (Yesterday / Today / Tomorrow)
- **Search** – Placeholder for teams, players, and fixtures (coming soon)
- **Fantasy** – Create and manage fantasy squads (synced via Supabase)
- **Following** – Follow teams and players (synced via Supabase)

## Supabase Setup (fantasyball project)

### 1. Get your project credentials

1. Open your [Supabase Dashboard](https://supabase.com/dashboard)
2. Select the **fantasyball** project
3. Go to **Project Settings** → **API**
4. Copy:
   - **Project URL** (e.g. `https://xxxxx.supabase.co`)
   - **anon public** key (under Project API keys)

### 2. Configure the app

Edit `Sport_Tracker-Fantasy/SupabaseConfig.swift`:

```swift
static let url = "https://YOUR_PROJECT_REF.supabase.co"
static let anonKey = "your-anon-key-here"
```

Replace the placeholders with your actual values.

### 3. Run the database migration

1. In the Supabase Dashboard, go to **SQL Editor**
2. Open `supabase/migrations/20250205000000_initial_schema.sql`
3. Copy its contents and run the SQL in the editor

This creates the tables: `followed_teams`, `followed_players`, `fantasy_squads`, `fantasy_squad_players`, with Row Level Security (RLS).

### 4. Enable anonymous auth

1. Go to **Authentication** → **Providers**
2. Enable **Anonymous Sign-In**

The app uses anonymous auth to give each device a persistent user ID for syncing data.

## Building

1. Open `Sport_Tracker-Fantasy.xcodeproj` in Xcode
2. Resolve package dependencies (File → Packages → Resolve Package Versions) if needed
3. Build and run (⌘R)

## Structure

- `SupabaseConfig.swift` – Project URL and anon key
- `SupabaseClient.swift` – Shared Supabase client
- `SupabaseService.swift` – Database operations (followed teams/players, fantasy squads)
- `SupabaseModels.swift` – Codable models for Supabase tables
