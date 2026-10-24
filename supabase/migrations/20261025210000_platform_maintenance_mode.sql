begin;

create table public.platform_maintenance_settings (
  singleton boolean primary key default true check (singleton),
  maintenance_until timestamptz,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default pg_catalog.now()
);

insert into public.platform_maintenance_settings (singleton)
values (true);

alter table public.platform_maintenance_settings enable row level security;
revoke all on table public.platform_maintenance_settings
  from public, anon, authenticated;

create or replace function public.get_platform_maintenance_mode()
returns table (
  caller_is_super_admin boolean,
  maintenance_active boolean,
  maintenance_until timestamptz,
  server_time timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    public.is_super_admin(),
    coalesce(
      settings.maintenance_until > pg_catalog.statement_timestamp(),
      false
    ),
    settings.maintenance_until,
    pg_catalog.statement_timestamp()
  from public.platform_maintenance_settings as settings
  where settings.singleton is true;
$$;

revoke all on function public.get_platform_maintenance_mode()
  from public, anon;
grant execute on function public.get_platform_maintenance_mode()
  to authenticated;

create or replace function public.set_platform_maintenance_mode(
  p_maintenance_until timestamptz
)
returns table (
  caller_is_super_admin boolean,
  maintenance_active boolean,
  maintenance_until timestamptz,
  server_time timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_server_time timestamptz := pg_catalog.statement_timestamp();
begin
  if v_user_id is null or not (select public.is_super_admin()) then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can change platform maintenance mode.';
  end if;

  if p_maintenance_until is not null
    and p_maintenance_until <= v_server_time
  then
    raise exception using
      errcode = '22023',
      message = 'Maintenance must end at a future time.';
  end if;

  insert into public.platform_maintenance_settings (
    singleton,
    maintenance_until,
    updated_by,
    updated_at
  )
  values (
    true,
    p_maintenance_until,
    v_user_id,
    v_server_time
  )
  on conflict (singleton) do update
    set maintenance_until = excluded.maintenance_until,
        updated_by = excluded.updated_by,
        updated_at = excluded.updated_at;

  return query
  select
    true,
    coalesce(
      settings.maintenance_until > v_server_time,
      false
    ),
    settings.maintenance_until,
    v_server_time
  from public.platform_maintenance_settings as settings
  where settings.singleton is true;
end;
$$;

revoke all on function public.set_platform_maintenance_mode(timestamptz)
  from public, anon;
grant execute on function public.set_platform_maintenance_mode(timestamptz)
  to authenticated;

commit;
