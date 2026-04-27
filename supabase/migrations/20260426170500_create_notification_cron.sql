create extension if not exists pg_cron;
create extension if not exists pg_net;

create or replace function public.send_bible_verse_notifications()
returns void
language plpgsql
security definer
as $$
begin
  perform net.http_post(
    url := 'https://oezlfzzbsfwaujpwecpk.supabase.co/functions/v1/send-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
end;
$$;

select
  cron.schedule(
    'send-bible-verse-notifications',
    '*/5 * * * *',
    $$
    select public.send_bible_verse_notifications();
    $$
  );
