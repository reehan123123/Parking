-- Application-level daily cap on password-recovery emails per account.
--
-- This is independent of Supabase's own built-in per-address/per-hour email
-- rate limits. It is enforced only for the "recovery" email action type by
-- the send-email Edge Function (the Auth "Send Email" hook), which calls
-- record_password_reset_attempt() with the service-role client before
-- sending each recovery email. No authenticated or anonymous client has any
-- grant on the table or function; RLS denies all client access by default.

create table if not exists public.password_reset_request_log (
  email text not null,
  requested_on date not null,
  request_count integer not null default 0,
  primary key (email, requested_on)
);

alter table public.password_reset_request_log enable row level security;

comment on table public.password_reset_request_log is
  'Per-day attempt counter for self-service password-recovery emails, '
  'written only by the send-email Edge Function via the service-role key.';

create or replace function public.record_password_reset_attempt(p_email text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(trim(p_email));
  v_today date := (now() at time zone 'utc')::date;
  v_count integer;
begin
  if v_email = '' then
    raise exception 'invalid_email' using errcode = '22023';
  end if;

  insert into public.password_reset_request_log (email, requested_on, request_count)
  values (v_email, v_today, 1)
  on conflict (email, requested_on)
    do update set request_count = public.password_reset_request_log.request_count + 1
  returning request_count into v_count;

  return v_count;
end;
$$;

comment on function public.record_password_reset_attempt(text) is
  'Atomically increments and returns today''s UTC password-recovery email '
  'count for the given email address. security definer so it can bypass '
  'RLS on password_reset_request_log; only service_role may execute it.';

revoke all on function public.record_password_reset_attempt(text) from public;
revoke all on function public.record_password_reset_attempt(text) from anon, authenticated;
grant execute on function public.record_password_reset_attempt(text) to service_role;

revoke all on table public.password_reset_request_log from anon, authenticated;
