# Cron: Automate sync-reference-data Every 12 Hours

The **sync-reference-data** Edge Function updates all Supabase reference tables (teams, players, games, game_details, season_averages, player_game_stats) from API-Sports. This guide sets up a **pg_cron** job so the function runs automatically every 12 hours (00:00 and 12:00 UTC).

---

## How it works

- **pg_cron** runs on a schedule (`0 */12 * * *` = every 12 hours at minute 0).
- **pg_net** sends an HTTP POST to your Edge Function URL.
- Your **project URL** and **anon key** are read from **Supabase Vault** so they are not hardcoded in the cron SQL.

The Edge Function itself uses the **service role** and **API_SPORTS_KEY** from its own secrets to perform the sync; the cron only needs the anon key to *invoke* the function (JWT verification).

---

## Prerequisites

- Supabase project with the **sync-reference-data** Edge Function deployed.
- **API_SPORTS_KEY** set in the function’s secrets (Dashboard → Edge Functions → sync-reference-data → Secrets).

---

## Step 1: Enable extensions

1. In the Supabase Dashboard, go to **Database → Extensions**.
2. Enable **pg_cron**.
3. Enable **pg_net**.

---

## Step 2: Store URL and anon key in Vault

In **SQL Editor**, run the following **once**, replacing the placeholders with your real values from **Project Settings → API**:

```sql
-- Replace with your Project URL (e.g. https://abcdefgh.supabase.co)
select vault.create_secret('https://acsimphtpplkitisjlpp.supabase.co', 'project_url');

-- Replace with your anon (public) key
select vault.create_secret('sb_publishable_4ueMqfTHKgHB3XFPVTew6A_Mpm_LmcF', 'anon_key');
```

Use the same **Project URL** and **anon public** key you use in the iOS app. Do not use the service role key here.

---

## Step 3: Apply the cron schedule

**Option A – Migration (recommended)**  
If you use Supabase migrations, the schedule is already in:

- `supabase/migrations/20250212000000_schedule_sync_reference_data_cron.sql`

Run your usual deploy (e.g. `supabase db push` or your CI/CD) so this migration runs. No need to run the SQL by hand.

**Option B – Run SQL manually**  
In **SQL Editor**, run:

```sql
select cron.schedule(
  'invoke-sync-reference-data-every-12-hours',
  '0 */12 * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/sync-reference-data',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'anon_key')
    ),
    body := '{}'::jsonb
  ) as request_id;
  $$
);
```

---

## Verify

- **Cron job:** In **Database → Cron Jobs** (or run `select * from cron.job;` in SQL Editor), you should see `invoke-sync-reference-data-every-12-hours` with schedule `0 */12 * * *`.
- **Runs:** After the next :00 (UTC) at 00:00 or 12:00, check **Edge Functions → sync-reference-data → Logs** for invocations, or **Database → Logs** for pg_net requests.

---

## Change the schedule

To run at a different interval, update the cron job:

```sql
-- Unschedule the existing job
select cron.unschedule('invoke-sync-reference-data-every-12-hours');

-- Reschedule (examples):
-- Every 6 hours:  '0 */6 * * *'
-- Daily at 3am UTC: '0 3 * * *'
-- Every 12 hours (same as before): '0 */12 * * *'
select cron.schedule(
  'invoke-sync-reference-data-every-12-hours',
  '0 */12 * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/sync-reference-data',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'anon_key')
    ),
    body := '{}'::jsonb
  ) as request_id;
  $$
);
```

---

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| Cron job not listed | Extensions **pg_cron** and **pg_net** enabled (Database → Extensions). |
| Function not invoked / 401 | Vault secrets **project_url** and **anon_key** exist and are correct (Project Settings → API). |
| Function fails (500 / API errors) | Edge Function logs (Edge Functions → sync-reference-data → Logs); ensure **API_SPORTS_KEY** is set in the function’s secrets. |
