create table if not exists public.parking_sessions (
  id uuid primary key default gen_random_uuid(),
  plate_number text not null,
  photo_path text,
  entry_time timestamptz not null,
  allowed_duration_value integer not null,
  allowed_duration_unit text not null,
  expires_at timestamptz not null,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint parking_sessions_plate_number_check
    check (char_length(btrim(plate_number)) between 1 and 64),
  constraint parking_sessions_duration_value_check
    check (allowed_duration_value > 0),
  constraint parking_sessions_duration_unit_check
    check (
      allowed_duration_unit in ('minutes', 'hours', 'days', 'months')
    )
);

create index if not exists parking_sessions_plate_number_idx
  on public.parking_sessions (plate_number);

create index if not exists parking_sessions_expires_at_idx
  on public.parking_sessions (expires_at);

create index if not exists parking_sessions_created_by_idx
  on public.parking_sessions (created_by);

create or replace function public.set_parking_session_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = pg_catalog.now();
  return new;
end;
$$;

drop trigger if exists set_parking_session_updated_at
  on public.parking_sessions;

create trigger set_parking_session_updated_at
before update on public.parking_sessions
for each row
execute function public.set_parking_session_updated_at();

alter table public.parking_sessions enable row level security;

revoke all on table public.parking_sessions from public, anon, authenticated;
grant select, insert, update, delete
  on table public.parking_sessions
  to authenticated;

create policy "Users can view their own parking sessions"
on public.parking_sessions
for select
to authenticated
using ((select auth.uid()) = created_by);

create policy "Users can create their own parking sessions"
on public.parking_sessions
for insert
to authenticated
with check ((select auth.uid()) = created_by);

create policy "Users can update their own parking sessions"
on public.parking_sessions
for update
to authenticated
using ((select auth.uid()) = created_by)
with check ((select auth.uid()) = created_by);

create policy "Users can delete their own parking sessions"
on public.parking_sessions
for delete
to authenticated
using ((select auth.uid()) = created_by);

insert into storage.buckets (id, name, public)
values ('vehicle-photos', 'vehicle-photos', false)
on conflict (id) do update
set public = excluded.public;

create policy "Users can read their own vehicle photos"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'vehicle-photos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and exists (
    select 1
    from public.parking_sessions as session
    where session.id::text = (storage.foldername(name))[2]
      and session.created_by = (select auth.uid())
  )
);

create policy "Users can upload their own vehicle photos"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'vehicle-photos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and exists (
    select 1
    from public.parking_sessions as session
    where session.id::text = (storage.foldername(name))[2]
      and session.created_by = (select auth.uid())
  )
);

create policy "Users can update their own vehicle photos"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'vehicle-photos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and exists (
    select 1
    from public.parking_sessions as session
    where session.id::text = (storage.foldername(name))[2]
      and session.created_by = (select auth.uid())
  )
)
with check (
  bucket_id = 'vehicle-photos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and exists (
    select 1
    from public.parking_sessions as session
    where session.id::text = (storage.foldername(name))[2]
      and session.created_by = (select auth.uid())
  )
);

create policy "Users can delete their own vehicle photos"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'vehicle-photos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and exists (
    select 1
    from public.parking_sessions as session
    where session.id::text = (storage.foldername(name))[2]
      and session.created_by = (select auth.uid())
  )
);
