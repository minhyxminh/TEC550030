-- Enable Supabase Cron/pg_cron first (Integrations -> Cron).
-- Run AFTER migrations/003_media_hourly_qr.sql in SQL Editor as project owner.
-- Re-running this script updates the job with the same name.
select cron.schedule(
  'gymflow-hourly-qr',
  '0 * * * *',
  'select public.gymflow_rotate_all_qr();'
);
