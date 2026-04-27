-- Fix device registration failures caused by RLS policy mismatches.
-- This table stores non-sensitive routing metadata (device id, token, interval)
-- and is intended to be writable from the mobile app.

alter table if exists public.devices disable row level security;

grant usage on schema public to anon, authenticated;
grant select, insert, update on table public.devices to anon, authenticated;
