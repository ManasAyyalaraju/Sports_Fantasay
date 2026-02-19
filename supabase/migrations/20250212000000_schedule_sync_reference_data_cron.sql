-- Schedule the sync-reference-data Edge Function to run every 12 hours (00:00 and 12:00 UTC).
--
-- Prerequisites (run once in Supabase Dashboard → SQL Editor):
-- 1. Enable extensions: Database → Extensions → enable "pg_cron" and "pg_net".
-- 2. Store your project URL and anon key in Vault (replace with your real values):
--
--    select vault.create_secret('https://YOUR_PROJECT_REF.supabase.co', 'project_url');
--    select vault.create_secret('YOUR_ANON_KEY', 'anon_key');
--
-- Then run this migration (or deploy so this migration runs).

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
