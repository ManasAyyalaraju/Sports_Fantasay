# Roster picks RLS DELETE policy and verification

## 1. Exact SQL for the DELETE policy

Your migration already defines this policy; if it’s missing or was changed in the DB, run the following in the **Supabase Dashboard → SQL Editor** (or add a new migration and run it).

```sql
-- Drop if it exists (e.g. wrong name or you're re-applying)
drop policy if exists "Users can delete own roster picks" on public.roster_picks;

-- Allow authenticated users to delete only their own roster picks
create policy "Users can delete own roster picks"
  on public.roster_picks
  for delete
  to authenticated
  using (auth.uid() = user_id);
```

- **`to authenticated`** – only requests that present a valid JWT (logged-in user) are considered.
- **`using (auth.uid() = user_id)`** – the row is visible for delete only when the row’s `user_id` equals the JWT’s user id (`auth.uid()`).

So: authenticated users can delete only rows where `user_id = auth.uid()`.

---

## 2. Where to run it in Supabase

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your project.
2. Go to **SQL Editor**.
3. Paste the SQL above and click **Run**.

To manage via migrations instead:

- Put the same SQL in a new file under `supabase/migrations/` (e.g. `20250212140000_roster_picks_delete_policy.sql`).
- Run `supabase db push` (or your usual migration command) so it runs against your linked project.

---

## 3. Why SELECT works but DELETE returns 0 rows

- **SELECT** is allowed by the “League members can read roster picks” policy (league membership + `auth.uid()`), so you see 1 row.
- **DELETE** is allowed only by “Users can delete own roster picks” with `using (auth.uid() = user_id)`.

If the DELETE policy is present and correct, the usual cause of “DELETE returns 0 rows” is:

- **`auth.uid()` is null** for the delete request (no JWT or invalid/expired session).
- Then `auth.uid() = user_id` is false for every row, so RLS allows no rows to be deleted and PostgREST reports 0 rows.

So you need to ensure the app is sending the request **with an authenticated session** (see below).

---

## 4. Verify you’re deleting with an authenticated session

You want: **anon key + valid user session** (JWT in the request). **Not** service role; **not** anon without a session.

### In the app (Swift)

- Use **only the anon (public) key** in the Supabase client, not the service role key.
- Before calling `removePlayerFromRoster`, ensure the user is logged in and the client has a session:
  - e.g. use `AuthViewModel.currentUserId != nil`, or
  - `try? await client.auth.session` and check it’s non-nil and not expired.
- The Supabase Swift client attaches the session JWT to database requests when a session exists. If there’s no session or it’s expired, requests go as “anon” and `auth.uid()` is null, so the DELETE policy will allow 0 rows.

### In the dashboard (sanity check)

- **Table Editor**: You can’t “run as” a specific user there; it uses the role/key of the dashboard (often service role), so RLS may be bypassed. Don’t rely on that to test the app’s behavior.
- **SQL Editor**: Run:
  - `select auth.uid();`  
  With the anon key and no JWT this returns `null`. With a valid user JWT (e.g. from your app’s session), it would return that user’s UUID. So the important check is that **the app** is sending a valid user JWT for the delete.

### Quick checklist

| Check | Meaning |
|------|--------|
| Client uses **anon key** (e.g. `SupabaseConfig.supabaseAnonKey`) | Correct; never use service_role in the app. |
| User is **signed in** before removing from roster | So a session exists. |
| `try await client.auth.session` **succeeds** before delete | Confirms session is present and used for subsequent requests. |
| SELECT returns 1 row, DELETE returns 0 | Strong signal that DELETE is running with `auth.uid() = null` (policy is correct but JWT not sent or not valid). |

After (re)applying the DELETE policy and ensuring the app sends an authenticated session (anon key + logged-in user), DELETE should return 1 row and the roster pick should disappear and stay gone after refresh.
