begin;

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
    coalesce(user_account.email::text, ''),
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
    coalesce(user_account.email::text, ''),
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
    coalesce(actor.email::text, ''),
    coalesce(subject.email::text, ''),
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

commit;
