begin;

create table public.device_session_settings (
  singleton_id smallint primary key default 1,
  platform_device_limit integer not null default 1,
  stale_session_days integer not null default 30,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint device_session_settings_singleton_check
    check (singleton_id = 1),
  constraint device_session_settings_limit_check
    check (platform_device_limit between 1 and 50),
  constraint device_session_settings_stale_days_check
    check (stale_session_days between 7 and 365)
);

insert into public.device_session_settings (singleton_id)
values (1);

create table public.tenant_device_session_policies (
  tenant_id uuid primary key
    references public.tenants(id) on delete cascade,
  device_limit integer,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint tenant_device_session_policies_limit_check
    check (device_limit is null or device_limit between 1 and 50)
);

insert into public.tenant_device_session_policies (tenant_id)
select tenant.id
from public.tenants as tenant
on conflict (tenant_id) do nothing;

create table public.tenant_member_device_session_overrides (
  tenant_id uuid not null,
  user_id uuid not null,
  device_limit integer not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  primary key (tenant_id, user_id),
  constraint tenant_member_device_session_overrides_limit_check
    check (device_limit between 1 and 50),
  constraint tenant_member_device_session_overrides_membership_fkey
    foreign key (tenant_id, user_id)
    references public.tenant_memberships(tenant_id, user_id)
    on delete cascade
);

create table public.device_sessions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null
    references public.tenants(id) on delete cascade,
  user_id uuid not null
    references auth.users(id) on delete cascade,
  auth_session_id uuid not null,
  installation_id uuid not null,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  last_activity_at timestamptz not null default now(),
  ended_at timestamptz,
  ended_by uuid references auth.users(id) on delete set null,
  end_reason text,
  constraint device_sessions_status_check
    check (status in ('active', 'revoked', 'expired', 'signed_out'))
);

create unique index device_sessions_tenant_user_auth_session_uidx
  on public.device_sessions (tenant_id, user_id, auth_session_id);
create index device_sessions_active_installations_idx
  on public.device_sessions (tenant_id, user_id, status, installation_id);
create index device_sessions_user_auth_session_idx
  on public.device_sessions (user_id, auth_session_id, status);
create index device_sessions_user_activity_idx
  on public.device_sessions (user_id, status, last_activity_at desc);

create table public.device_session_audit_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete set null,
  actor_user_id uuid references auth.users(id) on delete set null,
  subject_user_id uuid references auth.users(id) on delete set null,
  auth_session_id uuid,
  installation_id uuid,
  action text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint device_session_audit_action_check
    check (
      action in (
        'platform_policy_updated',
        'tenant_policy_updated',
        'member_override_updated',
        'session_registered',
        'session_revoked_by_user',
        'session_revoked_by_admin',
        'session_signed_out',
        'session_expired',
        'session_limit_rejected',
        'membership_removed'
      )
    )
);

create index device_session_audit_tenant_created_idx
  on public.device_session_audit_events (tenant_id, created_at desc);
create index device_session_audit_created_idx
  on public.device_session_audit_events (created_at desc);
create unique index device_session_limit_rejections_uidx
  on public.device_session_audit_events (
    tenant_id,
    subject_user_id,
    auth_session_id,
    action
  )
  where action = 'session_limit_rejected';

alter table public.device_session_settings enable row level security;
alter table public.tenant_device_session_policies enable row level security;
alter table public.tenant_member_device_session_overrides
  enable row level security;
alter table public.device_sessions enable row level security;
alter table public.device_session_audit_events enable row level security;

revoke all on table public.device_session_settings
  from public, anon, authenticated;
revoke all on table public.tenant_device_session_policies
  from public, anon, authenticated;
revoke all on table public.tenant_member_device_session_overrides
  from public, anon, authenticated;
revoke all on table public.device_sessions
  from public, anon, authenticated;
revoke all on table public.device_session_audit_events
  from public, anon, authenticated;

create or replace function public.create_tenant_device_session_policy()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.tenant_device_session_policies (tenant_id)
  values (new.id)
  on conflict (tenant_id) do nothing;

  return new;
end;
$$;

revoke all on function public.create_tenant_device_session_policy()
  from public, anon, authenticated;

create trigger create_tenant_device_session_policy
after insert on public.tenants
for each row
execute function public.create_tenant_device_session_policy();

create or replace function public.write_device_session_audit_event(
  p_tenant_id uuid,
  p_actor_user_id uuid,
  p_subject_user_id uuid,
  p_auth_session_id uuid,
  p_installation_id uuid,
  p_action text,
  p_details jsonb
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.device_session_audit_events (
    tenant_id,
    actor_user_id,
    subject_user_id,
    auth_session_id,
    installation_id,
    action,
    details
  )
  values (
    p_tenant_id,
    p_actor_user_id,
    p_subject_user_id,
    p_auth_session_id,
    p_installation_id,
    p_action,
    coalesce(p_details, '{}'::jsonb)
  );
$$;

revoke all on function public.write_device_session_audit_event(
  uuid, uuid, uuid, uuid, uuid, text, jsonb
) from public, anon, authenticated;

create or replace function public.revoke_removed_member_device_sessions()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_user_id uuid := (select auth.uid());
begin
  with revoked_sessions as (
    update public.device_sessions as device_session
    set
      status = 'revoked',
      ended_at = pg_catalog.clock_timestamp(),
      ended_by = v_actor_user_id,
      end_reason = 'membership_removed'
    where device_session.tenant_id = old.tenant_id
      and device_session.user_id = old.user_id
      and device_session.status = 'active'
    returning
      device_session.tenant_id,
      device_session.user_id,
      device_session.auth_session_id,
      device_session.installation_id
  )
  insert into public.device_session_audit_events (
    tenant_id,
    actor_user_id,
    subject_user_id,
    auth_session_id,
    installation_id,
    action
  )
  select
    revoked_sessions.tenant_id,
    v_actor_user_id,
    revoked_sessions.user_id,
    revoked_sessions.auth_session_id,
    revoked_sessions.installation_id,
    'membership_removed'
  from revoked_sessions;

  return old;
end;
$$;

revoke all on function public.revoke_removed_member_device_sessions()
  from public, anon, authenticated;

create trigger revoke_removed_member_device_sessions
after delete on public.tenant_memberships
for each row
execute function public.revoke_removed_member_device_sessions();

create or replace function public.list_my_device_session_tenant_choices()
returns table (
  tenant_id uuid,
  tenant_name text,
  tenant_slug text,
  role text,
  archived_at timestamptz,
  valid_until date
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;

  if public.is_temporary_password_reset_required() then
    return;
  end if;

  return query
  select
    tenant.id,
    tenant.name,
    tenant.slug,
    membership.role,
    tenant.archived_at,
    tenant.valid_until
  from public.tenant_memberships as membership
  join public.tenants as tenant on tenant.id = membership.tenant_id
  where membership.user_id = v_user_id
    and tenant.archived_at is null
    and tenant.valid_until >=
      (pg_catalog.now() at time zone 'Asia/Kolkata')::date
  order by tenant.name, tenant.id;
end;
$$;

create or replace function public.register_device_session(
  p_tenant_id uuid,
  p_installation_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_auth_session_id uuid :=
    nullif((select auth.jwt() ->> 'session_id'), '')::uuid;
  v_existing_installation_id uuid;
  v_existing_status text;
  v_existing boolean := false;
  v_bound_installation_id uuid;
  v_device_limit integer;
  v_stale_session_days integer;
  v_policy_source text;
  v_active_device_count integer;
  v_installation_is_active boolean;
begin
  if v_user_id is null
    or v_auth_session_id is null
    or p_tenant_id is null
    or p_installation_id is null
  then
    raise exception using
      errcode = '22023',
      message = 'A signed-in session, tenant, and installation ID are required.';
  end if;

  if public.is_temporary_password_reset_required() then
    raise exception using
      errcode = '42501',
      message = 'Complete the required password change before registering a device.';
  end if;

  if public.is_super_admin() then
    return pg_catalog.jsonb_build_object(
      'accepted', true,
      'exempt', true,
      'active_device_count', 0
    );
  end if;

  perform 1
  from public.tenant_memberships as membership
  join public.tenants as tenant on tenant.id = membership.tenant_id
  where membership.tenant_id = p_tenant_id
    and membership.user_id = v_user_id
    and tenant.archived_at is null
    and tenant.valid_until >=
      (pg_catalog.now() at time zone 'Asia/Kolkata')::date
  for key share of membership;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The signed-in user is not an active member of this tenant.';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'device-session:' || v_user_id::text || ':' || v_auth_session_id::text,
      0::bigint
    )
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'device-tenant:' || v_user_id::text || ':' || p_tenant_id::text,
      0::bigint
    )
  );

  select settings.stale_session_days
  into v_stale_session_days
  from public.device_session_settings as settings
  where settings.singleton_id = 1
  for share;

  if v_stale_session_days is null then
    raise exception using
      errcode = '55000',
      message = 'Device-session settings are not initialized.';
  end if;

  with expired_sessions as (
    update public.device_sessions as device_session
    set
      status = 'expired',
      ended_at = pg_catalog.clock_timestamp(),
      end_reason = 'inactive_timeout'
    where device_session.tenant_id = p_tenant_id
      and device_session.user_id = v_user_id
      and device_session.status = 'active'
      and device_session.last_activity_at <
        pg_catalog.now() - pg_catalog.make_interval(
          days => v_stale_session_days
        )
    returning
      device_session.tenant_id,
      device_session.user_id,
      device_session.auth_session_id,
      device_session.installation_id
  )
  insert into public.device_session_audit_events (
    tenant_id,
    actor_user_id,
    subject_user_id,
    auth_session_id,
    installation_id,
    action
  )
  select
    expired_sessions.tenant_id,
    v_user_id,
    expired_sessions.user_id,
    expired_sessions.auth_session_id,
    expired_sessions.installation_id,
    'session_expired'
  from expired_sessions;

  select device_session.installation_id, device_session.status
  into v_existing_installation_id, v_existing_status
  from public.device_sessions as device_session
  where device_session.tenant_id = p_tenant_id
    and device_session.user_id = v_user_id
    and device_session.auth_session_id = v_auth_session_id
  for update;
  v_existing := found;

  if v_existing and v_existing_installation_id <> p_installation_id then
    return pg_catalog.jsonb_build_object(
      'accepted', false,
      'reason', 'installation_mismatch'
    );
  end if;

  if v_existing and v_existing_status <> 'active' then
    return pg_catalog.jsonb_build_object(
      'accepted', false,
      'reason', 'session_ended'
    );
  end if;

  select device_session.installation_id
  into v_bound_installation_id
  from public.device_sessions as device_session
  where device_session.user_id = v_user_id
    and device_session.auth_session_id = v_auth_session_id
  order by device_session.created_at
  limit 1;

  if found and v_bound_installation_id <> p_installation_id then
    return pg_catalog.jsonb_build_object(
      'accepted', false,
      'reason', 'installation_mismatch'
    );
  end if;

  select
    coalesce(
      member_override.device_limit,
      tenant_policy.device_limit,
      settings.platform_device_limit
    ),
    case
      when member_override.device_limit is not null then 'account_override'
      when tenant_policy.device_limit is not null then 'tenant_policy'
      else 'platform_default'
    end
  into v_device_limit, v_policy_source
  from public.device_session_settings as settings
  join public.tenant_device_session_policies as tenant_policy
    on tenant_policy.tenant_id = p_tenant_id
  left join public.tenant_member_device_session_overrides as member_override
    on member_override.tenant_id = p_tenant_id
    and member_override.user_id = v_user_id
  where settings.singleton_id = 1
  for share of settings, tenant_policy;

  if v_device_limit is null then
    raise exception using
      errcode = '55000',
      message = 'The effective device limit could not be resolved.';
  end if;

  if v_existing and v_existing_status = 'active' then
    update public.device_sessions as device_session
    set last_activity_at = pg_catalog.clock_timestamp()
    where device_session.tenant_id = p_tenant_id
      and device_session.user_id = v_user_id
      and device_session.auth_session_id = v_auth_session_id;

    select pg_catalog.count(distinct device_session.installation_id)::integer
    into v_active_device_count
    from public.device_sessions as device_session
    where device_session.tenant_id = p_tenant_id
      and device_session.user_id = v_user_id
      and device_session.status = 'active';

    return pg_catalog.jsonb_build_object(
      'accepted', true,
      'effective_limit', v_device_limit,
      'active_device_count', v_active_device_count,
      'policy_source', v_policy_source
    );
  end if;

  select exists (
    select 1
    from public.device_sessions as device_session
    where device_session.tenant_id = p_tenant_id
      and device_session.user_id = v_user_id
      and device_session.installation_id = p_installation_id
      and device_session.status = 'active'
  )
  into v_installation_is_active;

  select pg_catalog.count(distinct device_session.installation_id)::integer
  into v_active_device_count
  from public.device_sessions as device_session
  where device_session.tenant_id = p_tenant_id
    and device_session.user_id = v_user_id
    and device_session.status = 'active';

  if not v_installation_is_active
    and v_active_device_count >= v_device_limit
  then
    insert into public.device_session_audit_events (
      tenant_id,
      actor_user_id,
      subject_user_id,
      auth_session_id,
      installation_id,
      action,
      details
    )
    values (
      p_tenant_id,
      v_user_id,
      v_user_id,
      v_auth_session_id,
      p_installation_id,
      'session_limit_rejected',
      pg_catalog.jsonb_build_object(
        'effective_limit',
        v_device_limit,
        'active_device_count',
        v_active_device_count,
        'policy_source',
        v_policy_source
      )
    )
    on conflict do nothing;

    return pg_catalog.jsonb_build_object(
      'accepted', false,
      'reason', 'device_limit_reached',
      'effective_limit', v_device_limit,
      'active_device_count', v_active_device_count,
      'policy_source', v_policy_source
    );
  end if;

  insert into public.device_sessions (
    tenant_id,
    user_id,
    auth_session_id,
    installation_id
  )
  values (
    p_tenant_id,
    v_user_id,
    v_auth_session_id,
    p_installation_id
  );

  insert into public.device_session_audit_events (
    tenant_id,
    actor_user_id,
    subject_user_id,
    auth_session_id,
    installation_id,
    action,
    details
  )
  values (
    p_tenant_id,
    v_user_id,
    v_user_id,
    v_auth_session_id,
    p_installation_id,
    'session_registered',
    pg_catalog.jsonb_build_object(
      'effective_limit',
      v_device_limit,
      'policy_source',
      v_policy_source
    )
  );

  return pg_catalog.jsonb_build_object(
    'accepted', true,
    'effective_limit', v_device_limit,
    'active_device_count',
    v_active_device_count + case when v_installation_is_active then 0 else 1 end,
    'policy_source', v_policy_source
  );
end;
$$;

create or replace function public.release_current_device_sessions()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_auth_session_id uuid :=
    nullif((select auth.jwt() ->> 'session_id'), '')::uuid;
begin
  if v_user_id is null or v_auth_session_id is null then
    return;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'device-session:' || v_user_id::text || ':' || v_auth_session_id::text,
      0::bigint
    )
  );

  with released_sessions as (
    update public.device_sessions as device_session
    set
      status = 'signed_out',
      ended_at = pg_catalog.clock_timestamp(),
      ended_by = v_user_id,
      end_reason = 'signed_out'
    where device_session.user_id = v_user_id
      and device_session.auth_session_id = v_auth_session_id
      and device_session.status = 'active'
    returning
      device_session.tenant_id,
      device_session.user_id,
      device_session.auth_session_id,
      device_session.installation_id
  )
  insert into public.device_session_audit_events (
    tenant_id,
    actor_user_id,
    subject_user_id,
    auth_session_id,
    installation_id,
    action
  )
  select
    released_sessions.tenant_id,
    v_user_id,
    released_sessions.user_id,
    released_sessions.auth_session_id,
    released_sessions.installation_id,
    'session_signed_out'
  from released_sessions;
end;
$$;

create or replace function public.list_my_device_sessions()
returns table (
  tenant_id uuid,
  tenant_name text,
  installation_id uuid,
  active_session_count integer,
  last_activity_at timestamptz,
  includes_current_session boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_auth_session_id uuid :=
    nullif((select auth.jwt() ->> 'session_id'), '')::uuid;
  v_stale_session_days integer;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;

  select settings.stale_session_days
  into v_stale_session_days
  from public.device_session_settings as settings
  where settings.singleton_id = 1;

  with expired_sessions as (
    update public.device_sessions as device_session
    set
      status = 'expired',
      ended_at = pg_catalog.clock_timestamp(),
      end_reason = 'inactive_timeout'
    where device_session.user_id = v_user_id
      and device_session.status = 'active'
      and device_session.last_activity_at <
        pg_catalog.now() - pg_catalog.make_interval(
          days => v_stale_session_days
        )
    returning
      device_session.tenant_id,
      device_session.user_id,
      device_session.auth_session_id,
      device_session.installation_id
  )
  insert into public.device_session_audit_events (
    tenant_id,
    actor_user_id,
    subject_user_id,
    auth_session_id,
    installation_id,
    action
  )
  select
    expired_sessions.tenant_id,
    v_user_id,
    expired_sessions.user_id,
    expired_sessions.auth_session_id,
    expired_sessions.installation_id,
    'session_expired'
  from expired_sessions;

  return query
  select
    device_session.tenant_id,
    tenant.name,
    device_session.installation_id,
    pg_catalog.count(*)::integer,
    pg_catalog.max(device_session.last_activity_at),
    pg_catalog.bool_or(
      device_session.auth_session_id = v_auth_session_id
    )
  from public.device_sessions as device_session
  join public.tenants as tenant on tenant.id = device_session.tenant_id
  where device_session.user_id = v_user_id
    and device_session.status = 'active'
  group by
    device_session.tenant_id,
    tenant.name,
    device_session.installation_id
  order by tenant.name, pg_catalog.max(device_session.last_activity_at) desc;
end;
$$;

create or replace function public.revoke_my_device_installation(
  p_tenant_id uuid,
  p_installation_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_revoked_count integer;
begin
  if v_user_id is null or p_tenant_id is null or p_installation_id is null then
    raise exception using
      errcode = '22023',
      message = 'A signed-in user, tenant, and installation ID are required.';
  end if;

  with revoked_sessions as (
    update public.device_sessions as device_session
    set
      status = 'revoked',
      ended_at = pg_catalog.clock_timestamp(),
      ended_by = v_user_id,
      end_reason = 'revoked_by_user'
    where device_session.tenant_id = p_tenant_id
      and device_session.user_id = v_user_id
      and device_session.installation_id = p_installation_id
      and device_session.status = 'active'
    returning
      device_session.tenant_id,
      device_session.user_id,
      device_session.auth_session_id,
      device_session.installation_id
  ),
  audit_events as (
    insert into public.device_session_audit_events (
      tenant_id,
      actor_user_id,
      subject_user_id,
      auth_session_id,
      installation_id,
      action
    )
    select
      revoked_sessions.tenant_id,
      v_user_id,
      revoked_sessions.user_id,
      revoked_sessions.auth_session_id,
      revoked_sessions.installation_id,
      'session_revoked_by_user'
    from revoked_sessions
    returning 1
  )
  select pg_catalog.count(*)::integer
  into v_revoked_count
  from audit_events;

  return v_revoked_count;
end;
$$;

create or replace function public.set_platform_device_session_policy(
  p_device_limit integer,
  p_stale_session_days integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_user_id uuid := (select auth.uid());
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can update the platform device policy.';
  end if;

  if p_device_limit is null or p_device_limit not between 1 and 50
    or p_stale_session_days is null
    or p_stale_session_days not between 7 and 365
  then
    raise exception using
      errcode = '22023',
      message = 'Device limits must be 1-50 and stale expiry must be 7-365 days.';
  end if;

  update public.device_session_settings
  set
    platform_device_limit = p_device_limit,
    stale_session_days = p_stale_session_days,
    updated_at = pg_catalog.clock_timestamp(),
    updated_by = v_actor_user_id
  where singleton_id = 1;

  if not found then
    raise exception using
      errcode = '55000',
      message = 'Device-session settings are not initialized.';
  end if;

  perform public.write_device_session_audit_event(
    null,
    v_actor_user_id,
    null,
    null,
    null,
    'platform_policy_updated',
    pg_catalog.jsonb_build_object(
      'device_limit',
      p_device_limit,
      'stale_session_days',
      p_stale_session_days
    )
  );

  return pg_catalog.jsonb_build_object(
    'platform_device_limit',
    p_device_limit,
    'stale_session_days',
    p_stale_session_days
  );
end;
$$;

create or replace function public.get_platform_device_session_policy()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_settings public.device_session_settings;
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can view the platform device policy.';
  end if;

  select settings.*
  into v_settings
  from public.device_session_settings as settings
  where settings.singleton_id = 1;

  if not found then
    raise exception using
      errcode = '55000',
      message = 'Device-session settings are not initialized.';
  end if;

  return pg_catalog.jsonb_build_object(
    'platform_device_limit',
    v_settings.platform_device_limit,
    'stale_session_days',
    v_settings.stale_session_days,
    'max_device_limit',
    50,
    'min_stale_session_days',
    7,
    'max_stale_session_days',
    365
  );
end;
$$;

create or replace function public.set_tenant_device_session_limit(
  p_tenant_id uuid,
  p_device_limit integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_user_id uuid := (select auth.uid());
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can update tenant device policies.';
  end if;

  if p_tenant_id is null
    or (
      p_device_limit is not null
      and p_device_limit not between 1 and 50
    )
  then
    raise exception using
      errcode = '22023',
      message = 'Select a tenant and use a device limit between 1 and 50.';
  end if;

  insert into public.tenant_device_session_policies (
    tenant_id,
    device_limit,
    updated_at,
    updated_by
  )
  values (
    p_tenant_id,
    p_device_limit,
    pg_catalog.clock_timestamp(),
    v_actor_user_id
  )
  on conflict (tenant_id)
  do update set
    device_limit = excluded.device_limit,
    updated_at = excluded.updated_at,
    updated_by = excluded.updated_by;

  perform public.write_device_session_audit_event(
    p_tenant_id,
    v_actor_user_id,
    null,
    null,
    null,
    'tenant_policy_updated',
    pg_catalog.jsonb_build_object('device_limit', p_device_limit)
  );
end;
$$;

create or replace function public.set_tenant_member_device_session_limit(
  p_tenant_id uuid,
  p_user_id uuid,
  p_device_limit integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_user_id uuid := (select auth.uid());
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can update member device overrides.';
  end if;

  if p_tenant_id is null
    or p_user_id is null
    or (
      p_device_limit is not null
      and p_device_limit not between 1 and 50
    )
  then
    raise exception using
      errcode = '22023',
      message = 'Select a member and use a device limit between 1 and 50.';
  end if;

  if not exists (
    select 1
    from public.tenant_memberships as membership
    where membership.tenant_id = p_tenant_id
      and membership.user_id = p_user_id
  ) then
    raise exception using
      errcode = 'P0002',
      message = 'The tenant member could not be found.';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'device-tenant:' || p_user_id::text || ':' || p_tenant_id::text,
      0::bigint
    )
  );

  if p_device_limit is null then
    delete from public.tenant_member_device_session_overrides as member_override
    where member_override.tenant_id = p_tenant_id
      and member_override.user_id = p_user_id;
  else
    insert into public.tenant_member_device_session_overrides (
      tenant_id,
      user_id,
      device_limit,
      updated_at,
      updated_by
    )
    values (
      p_tenant_id,
      p_user_id,
      p_device_limit,
      pg_catalog.clock_timestamp(),
      v_actor_user_id
    )
    on conflict (tenant_id, user_id)
    do update set
      device_limit = excluded.device_limit,
      updated_at = excluded.updated_at,
      updated_by = excluded.updated_by;
  end if;

  perform public.write_device_session_audit_event(
    p_tenant_id,
    v_actor_user_id,
    p_user_id,
    null,
    null,
    'member_override_updated',
    pg_catalog.jsonb_build_object('device_limit', p_device_limit)
  );
end;
$$;

create or replace function public.get_tenant_device_session_policy(
  p_tenant_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can view tenant device policies.';
  end if;

  select pg_catalog.jsonb_build_object(
    'platform_device_limit',
    settings.platform_device_limit,
    'tenant_device_limit',
    tenant_policy.device_limit,
    'effective_device_limit',
    coalesce(tenant_policy.device_limit, settings.platform_device_limit),
    'stale_session_days',
    settings.stale_session_days,
    'active_device_count',
    (
      select pg_catalog.count(distinct device_session.installation_id)
      from public.device_sessions as device_session
      where device_session.tenant_id = p_tenant_id
        and device_session.status = 'active'
        and device_session.last_activity_at >= pg_catalog.now()
          - pg_catalog.make_interval(days => settings.stale_session_days)
    ),
    'active_session_count',
    (
      select pg_catalog.count(*)
      from public.device_sessions as device_session
      where device_session.tenant_id = p_tenant_id
        and device_session.status = 'active'
        and device_session.last_activity_at >= pg_catalog.now()
          - pg_catalog.make_interval(days => settings.stale_session_days)
    )
  )
  into v_result
  from public.device_session_settings as settings
  join public.tenant_device_session_policies as tenant_policy
    on tenant_policy.tenant_id = p_tenant_id
  where settings.singleton_id = 1;

  if v_result is null then
    raise exception using
      errcode = 'P0002',
      message = 'The tenant or device-session policy could not be found.';
  end if;

  return v_result;
end;
$$;

create or replace function public.list_tenant_member_device_session_policies(
  p_tenant_id uuid
)
returns table (
  user_id uuid,
  email text,
  role text,
  account_device_limit integer,
  effective_device_limit integer,
  policy_source text,
  active_device_count bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_stale_session_days integer;
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can view member device policies.';
  end if;

  if not exists (
    select 1 from public.tenants as tenant where tenant.id = p_tenant_id
  ) then
    raise exception using
      errcode = 'P0002',
      message = 'The tenant could not be found.';
  end if;

  select settings.stale_session_days
  into v_stale_session_days
  from public.device_session_settings as settings
  where settings.singleton_id = 1;

  with expired_sessions as (
    update public.device_sessions as device_session
    set
      status = 'expired',
      ended_at = pg_catalog.clock_timestamp(),
      end_reason = 'inactive_timeout'
    where device_session.tenant_id = p_tenant_id
      and device_session.status = 'active'
      and device_session.last_activity_at <
        pg_catalog.now() - pg_catalog.make_interval(
          days => v_stale_session_days
        )
    returning
      device_session.tenant_id,
      device_session.user_id,
      device_session.auth_session_id,
      device_session.installation_id
  )
  insert into public.device_session_audit_events (
    tenant_id,
    actor_user_id,
    subject_user_id,
    auth_session_id,
    installation_id,
    action
  )
  select
    expired_sessions.tenant_id,
    (select auth.uid()),
    expired_sessions.user_id,
    expired_sessions.auth_session_id,
    expired_sessions.installation_id,
    'session_expired'
  from expired_sessions;

  return query
  select
    membership.user_id,
    coalesce(user_account.email, ''),
    membership.role,
    member_override.device_limit,
    coalesce(
      member_override.device_limit,
      tenant_policy.device_limit,
      settings.platform_device_limit
    ),
    case
      when member_override.device_limit is not null then 'account_override'
      when tenant_policy.device_limit is not null then 'tenant_policy'
      else 'platform_default'
    end,
    (
      select pg_catalog.count(distinct device_session.installation_id)
      from public.device_sessions as device_session
      where device_session.tenant_id = membership.tenant_id
        and device_session.user_id = membership.user_id
        and device_session.status = 'active'
        and device_session.last_activity_at >= pg_catalog.now()
          - pg_catalog.make_interval(days => v_stale_session_days)
    )
  from public.tenant_memberships as membership
  join auth.users as user_account on user_account.id = membership.user_id
  join public.device_session_settings as settings
    on settings.singleton_id = 1
  join public.tenant_device_session_policies as tenant_policy
    on tenant_policy.tenant_id = membership.tenant_id
  left join public.tenant_member_device_session_overrides as member_override
    on member_override.tenant_id = membership.tenant_id
    and member_override.user_id = membership.user_id
  where membership.tenant_id = p_tenant_id
  order by membership.role, user_account.email, membership.user_id;
end;
$$;

create or replace function public.list_tenant_device_sessions(
  p_tenant_id uuid
)
returns table (
  user_id uuid,
  email text,
  installation_id uuid,
  active_session_count integer,
  last_activity_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can view tenant device sessions.';
  end if;

  if not exists (
    select 1 from public.tenants as tenant where tenant.id = p_tenant_id
  ) then
    raise exception using
      errcode = 'P0002',
      message = 'The tenant could not be found.';
  end if;

  return query
  select
    device_session.user_id,
    coalesce(user_account.email, ''),
    device_session.installation_id,
    pg_catalog.count(*)::integer,
    pg_catalog.max(device_session.last_activity_at)
  from public.device_sessions as device_session
  join auth.users as user_account on user_account.id = device_session.user_id
  join public.device_session_settings as settings
    on settings.singleton_id = 1
  where device_session.tenant_id = p_tenant_id
    and device_session.status = 'active'
    and device_session.last_activity_at >= pg_catalog.now()
      - pg_catalog.make_interval(days => settings.stale_session_days)
  group by
    device_session.user_id,
    user_account.email,
    device_session.installation_id
  order by user_account.email, pg_catalog.max(device_session.last_activity_at) desc;
end;
$$;

create or replace function public.revoke_tenant_device_installation(
  p_tenant_id uuid,
  p_user_id uuid,
  p_installation_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_user_id uuid := (select auth.uid());
  v_revoked_count integer;
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can revoke tenant device sessions.';
  end if;

  if p_tenant_id is null
    or p_user_id is null
    or p_installation_id is null
  then
    raise exception using
      errcode = '22023',
      message = 'A tenant, user, and installation ID are required.';
  end if;

  with revoked_sessions as (
    update public.device_sessions as device_session
    set
      status = 'revoked',
      ended_at = pg_catalog.clock_timestamp(),
      ended_by = v_actor_user_id,
      end_reason = 'revoked_by_admin'
    where device_session.tenant_id = p_tenant_id
      and device_session.user_id = p_user_id
      and device_session.installation_id = p_installation_id
      and device_session.status = 'active'
    returning
      device_session.tenant_id,
      device_session.user_id,
      device_session.auth_session_id,
      device_session.installation_id
  ),
  audit_events as (
    insert into public.device_session_audit_events (
      tenant_id,
      actor_user_id,
      subject_user_id,
      auth_session_id,
      installation_id,
      action
    )
    select
      revoked_sessions.tenant_id,
      v_actor_user_id,
      revoked_sessions.user_id,
      revoked_sessions.auth_session_id,
      revoked_sessions.installation_id,
      'session_revoked_by_admin'
    from revoked_sessions
    returning 1
  )
  select pg_catalog.count(*)::integer
  into v_revoked_count
  from audit_events;

  return v_revoked_count;
end;
$$;

create or replace function public.list_device_session_audit_events()
returns table (
  tenant_id uuid,
  tenant_name text,
  actor_email text,
  subject_email text,
  action text,
  details jsonb,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can view device-session audit events.';
  end if;

  return query
  select
    audit_event.tenant_id,
    tenant.name,
    coalesce(actor.email, ''),
    coalesce(subject.email, ''),
    audit_event.action,
    audit_event.details,
    audit_event.created_at
  from public.device_session_audit_events as audit_event
  left join public.tenants as tenant on tenant.id = audit_event.tenant_id
  left join auth.users as actor on actor.id = audit_event.actor_user_id
  left join auth.users as subject on subject.id = audit_event.subject_user_id
  order by audit_event.created_at desc
  limit 100;
end;
$$;

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_auth_session_id uuid;
  v_authentication_method text;
  v_updated_sessions integer;
  v_stale_session_days integer;
begin
  if pg_catalog.jsonb_typeof(event -> 'claims') <> 'object'
    or nullif(event ->> 'user_id', '') is null
  then
    return pg_catalog.jsonb_build_object(
      'error',
      pg_catalog.jsonb_build_object(
        'http_code',
        400,
        'message',
        'The Auth session payload is invalid.'
      )
    );
  end if;

  v_authentication_method := event ->> 'authentication_method';
  if v_authentication_method <> 'token_refresh' then
    return pg_catalog.jsonb_build_object('claims', event -> 'claims');
  end if;

  v_user_id := (event ->> 'user_id')::uuid;
  v_auth_session_id :=
    nullif(event -> 'claims' ->> 'session_id', '')::uuid;

  if v_auth_session_id is null then
    return pg_catalog.jsonb_build_object(
      'error',
      pg_catalog.jsonb_build_object(
        'http_code',
        403,
        'message',
        'This device session is not active. Sign in again.'
      )
    );
  end if;

  if exists (
    select 1
    from public.super_admins as super_admin
    where super_admin.user_id = v_user_id
      and coalesce(
        event -> 'claims' -> 'app_metadata'
          ->> 'parking_temporary_password_reset_required',
        'false'
      ) <> 'true'
  ) then
    return pg_catalog.jsonb_build_object('claims', event -> 'claims');
  end if;

  select settings.stale_session_days
  into v_stale_session_days
  from public.device_session_settings as settings
  where settings.singleton_id = 1;

  if v_stale_session_days is null then
    return pg_catalog.jsonb_build_object(
      'error',
      pg_catalog.jsonb_build_object(
        'http_code',
        503,
        'message',
        'Device-session settings are unavailable.'
      )
    );
  end if;

  update public.device_sessions as device_session
  set last_activity_at = pg_catalog.clock_timestamp()
  where device_session.user_id = v_user_id
    and device_session.auth_session_id = v_auth_session_id
    and device_session.status = 'active'
    and device_session.last_activity_at >= pg_catalog.now()
      - pg_catalog.make_interval(days => v_stale_session_days);

  get diagnostics v_updated_sessions = row_count;
  if v_updated_sessions = 0 then
    return pg_catalog.jsonb_build_object(
      'error',
      pg_catalog.jsonb_build_object(
        'http_code',
        403,
        'message',
        'This device session is not active. Sign in again.'
      )
    );
  end if;

  return pg_catalog.jsonb_build_object('claims', event -> 'claims');
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant select on public.device_session_settings, public.super_admins
  to supabase_auth_admin;
grant select on public.device_sessions to supabase_auth_admin;
grant update (last_activity_at)
  on public.device_sessions to supabase_auth_admin;

create policy "Supabase Auth can inspect device session settings"
on public.device_session_settings
for select
to supabase_auth_admin
using (true);

create policy "Supabase Auth can inspect Super Admin exemptions"
on public.super_admins
for select
to supabase_auth_admin
using (true);

create policy "Supabase Auth can validate registered device sessions"
on public.device_sessions
for select
to supabase_auth_admin
using (true);

create policy "Supabase Auth can refresh registered device sessions"
on public.device_sessions
for update
to supabase_auth_admin
using (true)
with check (true);

revoke all on function public.list_my_device_session_tenant_choices()
  from public, anon;
revoke all on function public.register_device_session(uuid, uuid)
  from public, anon;
revoke all on function public.release_current_device_sessions()
  from public, anon;
revoke all on function public.list_my_device_sessions()
  from public, anon;
revoke all on function public.revoke_my_device_installation(uuid, uuid)
  from public, anon;
revoke all on function public.set_platform_device_session_policy(integer, integer)
  from public, anon;
revoke all on function public.get_platform_device_session_policy()
  from public, anon;
revoke all on function public.set_tenant_device_session_limit(uuid, integer)
  from public, anon;
revoke all on function public.set_tenant_member_device_session_limit(
  uuid, uuid, integer
) from public, anon;
revoke all on function public.get_tenant_device_session_policy(uuid)
  from public, anon;
revoke all on function public.list_tenant_member_device_session_policies(uuid)
  from public, anon;
revoke all on function public.list_tenant_device_sessions(uuid)
  from public, anon;
revoke all on function public.revoke_tenant_device_installation(uuid, uuid, uuid)
  from public, anon;
revoke all on function public.list_device_session_audit_events()
  from public, anon;
revoke all on function public.custom_access_token_hook(jsonb)
  from public, anon, authenticated;

grant execute on function public.list_my_device_session_tenant_choices()
  to authenticated;
grant execute on function public.register_device_session(uuid, uuid)
  to authenticated;
grant execute on function public.release_current_device_sessions()
  to authenticated;
grant execute on function public.list_my_device_sessions()
  to authenticated;
grant execute on function public.revoke_my_device_installation(uuid, uuid)
  to authenticated;
grant execute on function public.set_platform_device_session_policy(integer, integer)
  to authenticated;
grant execute on function public.get_platform_device_session_policy()
  to authenticated;
grant execute on function public.set_tenant_device_session_limit(uuid, integer)
  to authenticated;
grant execute on function public.set_tenant_member_device_session_limit(
  uuid, uuid, integer
) to authenticated;
grant execute on function public.get_tenant_device_session_policy(uuid)
  to authenticated;
grant execute on function public.list_tenant_member_device_session_policies(uuid)
  to authenticated;
grant execute on function public.list_tenant_device_sessions(uuid)
  to authenticated;
grant execute on function public.revoke_tenant_device_installation(uuid, uuid, uuid)
  to authenticated;
grant execute on function public.list_device_session_audit_events()
  to authenticated;
grant execute on function public.custom_access_token_hook(jsonb)
  to supabase_auth_admin;

create or replace function public.is_tenant_member(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not (select public.is_temporary_password_reset_required())
    and exists (
      select 1
      from public.tenant_memberships as membership
      join public.tenants as tenant on tenant.id = membership.tenant_id
      join public.device_session_settings as settings
        on settings.singleton_id = 1
      where membership.tenant_id = p_tenant_id
        and membership.user_id = (select auth.uid())
        and tenant.archived_at is null
        and tenant.valid_until >=
          (pg_catalog.now() at time zone 'Asia/Kolkata')::date
        and exists (
          select 1
          from public.device_sessions as device_session
          where device_session.tenant_id = membership.tenant_id
            and device_session.user_id = membership.user_id
            and device_session.auth_session_id =
              nullif((select auth.jwt() ->> 'session_id'), '')::uuid
            and device_session.status = 'active'
            and device_session.last_activity_at >= pg_catalog.now()
              - pg_catalog.make_interval(days => settings.stale_session_days)
        )
    );
$$;

revoke all on function public.is_tenant_member(uuid) from public, anon;
grant execute on function public.is_tenant_member(uuid) to authenticated;

commit;
