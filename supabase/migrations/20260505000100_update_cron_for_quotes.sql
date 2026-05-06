-- ============================================
-- Migration: Update cron job for quote notifications
-- Replaces Bible verse cron with quote notifications
-- ============================================

-- 1. Unschedule the old Bible verse cron job
select cron.unschedule('send-bible-verse-notifications');

-- 2. Drop the old Bible verse function if it exists
drop function if exists public.send_bible_verse_notifications();

-- 3. Create new function for quote notifications
create or replace function public.send_quote_notifications()
returns void
language plpgsql
security definer
as $$
declare
  anon_key constant text := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lemxmenpic2Z3YXVqcHdlY3BrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyMzAyODYsImV4cCI6MjA5MjgwNjI4Nn0.5PJNICEbf321blyYONUEVvws9H3frQ5gqaeCeiRwafc';
  headers jsonb;
begin
  -- Build valid JSONB headers
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer ' || anon_key,
    'apikey', anon_key
  );

  -- Invoke the Edge Function that sends quote notifications
  perform net.http_post(
    url := 'https://oezlfzzbsfwaujpwecpk.supabase.co/functions/v1/send-notification',
    headers := headers,
    body := '{}'::jsonb
  );
end;
$$;

-- 4. Schedule the new cron job (every 15 minutes by default)
-- Adjust the interval as needed: '*/15 * * * *' = every 15 min
-- Other options: '*/30 * * * *' (30 min), '0 * * * *' (hourly)
select
  cron.schedule(
    'send-quote-notifications',
    '*/15 * * * *',
    $$
    select public.send_quote_notifications();
    $$
  );

-- ============================================
-- Verification queries (run manually to check status):
--
-- List all cron jobs:
--   select * from cron.job;
--
-- Check cron job execution history:
--   select * from cron.job_run_details order by start_time desc limit 10;
--
-- Manually trigger the function:
--   select public.send_quote_notifications();
-- ============================================
