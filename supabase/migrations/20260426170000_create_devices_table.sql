create extension if not exists pgcrypto;

create table if not exists public.devices (
  id text primary key,
  fcm_token text,
  platform text,
  interval_seconds integer not null default 900,
  last_notified_at timestamptz,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.devices enable row level security;

create policy "allow public device inserts"
on public.devices
for insert
to anon, authenticated
with check (true);

create policy "allow public device updates"
on public.devices
for update
to anon, authenticated
using (true)
with check (true);

create policy "allow public device reads"
on public.devices
for select
to anon, authenticated
using (true);

create or replace function public.set_devices_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_set_devices_updated_at on public.devices;

create trigger trg_set_devices_updated_at
before update on public.devices
for each row
execute function public.set_devices_updated_at();
