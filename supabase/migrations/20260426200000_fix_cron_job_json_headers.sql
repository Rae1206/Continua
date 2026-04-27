-- Corrección del error en el cron job: invalid input syntax for type json
-- El problema era con la construcción de los headers en la función net.http_post

create or replace function public.send_bible_verse_notifications()
returns void
language plpgsql
security definer
as $$
declare
  anon_key constant text := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lemxmenpic2Z3YXVqcHdlY3BrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyMzAyODYsImV4cCI6MjA5MjgwNjI4Nn0.5PJNICEbf321blyYONUEVvws9H3frQ5gqaeCeiRwafc';
  headers jsonb;
begin
  -- Construir los headers como un objeto JSONB válido
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer ' || anon_key,
    'apikey', anon_key
  );
  
  -- Llamar a la función con los headers correctamente formateados
  perform net.http_post(
    url := 'https://oezlfzzbsfwaujpwecpk.supabase.co/functions/v1/send-notification',
    headers := headers,
    body := '{}'::jsonb
  );
end;
$$;