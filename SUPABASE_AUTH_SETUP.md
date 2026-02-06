# Supabase Authentication Setup ✅

Email/password authentication has been fully integrated into the app!

## What's Been Implemented

### ✅ Authentication Methods
- **Sign Up** - New users can create accounts during onboarding
- **Sign In** - Existing users can log in
- **Sign Out** - Users can log out (ready for future use)
- **Session Management** - App checks auth status on launch

### ✅ User Profiles
- User profiles table stores name and email
- Automatically created when user signs up
- Linked to Supabase auth.users

### ✅ Onboarding Flow
- Collects name, email, and password
- Signs up user when they complete onboarding
- Shows error messages if signup fails

### ✅ Login Screen
- Separate login view accessible from welcome screen
- Email/password validation
- Error handling for invalid credentials

## Database Setup

### 1. Run Updated Migration

The migration file has been updated to include the `user_profiles` table. Run this in Supabase SQL Editor:

```sql
-- User profiles table
create table if not exists public.user_profiles (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade unique,
  name text not null,
  email text not null,
  created_at timestamptz default now()
);

-- Enable RLS
alter table public.user_profiles enable row level security;

-- Policy: users can only access their own profile
create policy "Users can manage own user_profiles"
  on public.user_profiles for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
```

### 2. Enable Email Auth Provider

1. Go to Supabase Dashboard → **Authentication** → **Providers**
2. Make sure **Email** provider is enabled
3. Configure email settings:
   - **Confirm email**: Can be disabled for testing (users sign in immediately)
   - **Secure email change**: Optional
   - **Secure password change**: Optional

### 3. Configure Email Templates (Optional)

If you want custom email templates:
1. Go to **Authentication** → **Email Templates**
2. Customize signup, password reset, etc.

## How It Works

### Sign Up Flow
1. User goes through onboarding (Name → Email → Password)
2. On "Join League" or "Create League", app calls `signUp()`
3. Supabase creates auth user
4. User profile is created automatically
5. User is signed in and onboarding completes

### Sign In Flow
1. User taps "Log In" on welcome screen
2. LoginView appears
3. User enters email/password
4. App calls `signIn()`
5. On success, user is signed in and onboarding completes

### App Launch
1. App checks if user is authenticated
2. If authenticated → show main app
3. If not authenticated → show onboarding
4. If onboarding completed but not authenticated → sign in anonymously (fallback)

## Code Structure

### SupabaseService Auth Methods
```swift
// Sign up new user
func signUp(email: String, password: String, name: String) async throws

// Sign in existing user
func signIn(email: String, password: String) async throws

// Sign out
func signOut() async throws

// Check auth status
var isAuthenticated: Bool { get async }

// Get current user
func getCurrentUser() async throws -> User?
```

### OnboardingViewModel
- Collects user data (name, email, password)
- Calls `signUp()` when user completes onboarding
- Handles loading states and errors

### LoginViewModel
- Handles login form state
- Validates email/password
- Calls `signIn()` and handles errors

## Testing

### Test Sign Up
1. Reset onboarding: `UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")`
2. Run app
3. Go through onboarding flow
4. Enter name, email, password
5. Tap "Join League" or "Create League"
6. Should sign up and show main app

### Test Sign In
1. On welcome screen, tap "Log In"
2. Enter email/password of existing user
3. Tap "Sign In"
4. Should sign in and show main app

### Check User Profile
After signup, check Supabase Dashboard:
- **Authentication** → **Users** - Should see new user
- **Table Editor** → **user_profiles** - Should see profile with name and email

## Security Notes

- ✅ Passwords are hashed by Supabase (never stored in plain text)
- ✅ Row Level Security (RLS) ensures users only see their own data
- ✅ Email verification can be enabled for extra security
- ✅ Session tokens are managed securely by Supabase SDK

## Troubleshooting

**"Supabase not configured" error**
- Check `SupabaseConfig.swift` has your project URL and anon key

**Sign up fails**
- Check Supabase Dashboard → Authentication → Providers → Email is enabled
- Check email isn't already registered
- Check password meets requirements (min 8 chars)

**Sign in fails**
- Verify email/password are correct
- Check user exists in Supabase Dashboard → Authentication → Users
- Check email is confirmed (if email confirmation is enabled)

**User profile not created**
- Check migration was run successfully
- Check RLS policies are correct
- Check Supabase logs for errors

## Next Steps

- [ ] Add password reset flow
- [ ] Add email verification
- [ ] Add profile editing
- [ ] Add sign out functionality in settings
- [ ] Add "Remember me" option
- [ ] Add social auth (Google, Apple, etc.)
