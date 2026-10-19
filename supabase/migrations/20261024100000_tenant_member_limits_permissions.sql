begin;

alter table public.tenants
  add column member_limit integer not null default 1,
  add constraint tenants_member_limit_check
    check (member_limit between 1 and 50);

alter table public.tenant_memberships
  add column can_view_entries boolean not null default true,
  add column can_add_entries boolean not null default true,
  add column can_edit_entries boolean not null default true,
  add column can_delete_entries boolean not null default true;

alter table public.tenant_memberships
  alter column can_view_entries set default true,
  alter column can_add_entries set default false,
  alter column can_edit_entries set default false,
  alter column can_delete_entries set default false;

create index tenant_memberships_tenant_role_idx
  on public.tenant_memberships (tenant_id, role);

alter table public.parking_sessions
  add column photo_upload_pending boolean not null default false;

create table public.tenant_member_audit_events (
  id bigint generated always as identity primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  subject_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default pg_catalog.now(),
  constraint tenant_member_audit_events_action_check
    check (
      action in (
        'member_added',
        'member_removed',
        'member_role_changed',
        'member_permissions_changed',
        'member_limit_changed'
      )
    )
);

create index tenant_member_audit_events_tenant_created_idx
  on public.tenant_member_audit_events (tenant_id, created_at desc, id desc);

alter table public.tenant_member_audit_events enable row level security;

revoke all on table public.tenant_member_audit_events
  from public, anon, authenticated;
grant select on table public.tenant_member_audit_events to authenticated;

create or replace function public.is_tenant_owner(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_tenant_member(p_tenant_id)
    and exists (
      select 1
      from public.tenant_memberships as membership
      where membership.tenant_id = p_tenant_id
        and membership.user_id = (select auth.uid())
        and membership.role = 'owner'
    );
$$;

create or replace function public.can_manage_tenant_members(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_super_admin()
    or public.is_tenant_owner(p_tenant_id);
$$;

create or replace function public.can_view_tenant_entries(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_super_admin()
    or (
      public.is_tenant_member(p_tenant_id)
      and exists (
        select 1
        from public.tenant_memberships as membership
        where membership.tenant_id = p_tenant_id
          and membership.user_id = (select auth.uid())
          and (membership.role = 'owner' or membership.can_view_entries)
      )
    );
$$;

create or replace function public.can_add_tenant_entries(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_super_admin()
    or (
      public.is_tenant_member(p_tenant_id)
      and exists (
        select 1
        from public.tenant_memberships as membership
        where membership.tenant_id = p_tenant_id
          and membership.user_id = (select auth.uid())
          and (membership.role = 'owner' or membership.can_add_entries)
      )
    );
$$;

create or replace function public.can_edit_tenant_entries(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_super_admin()
    or (
      public.is_tenant_member(p_tenant_id)
      and exists (
        select 1
        from public.tenant_memberships as membership
        where membership.tenant_id = p_tenant_id
          and membership.user_id = (select auth.uid())
          and (membership.role = 'owner' or membership.can_edit_entries)
      )
    );
$$;

create or replace function public.can_delete_tenant_entries(
  p_tenant_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_super_admin()
    or (
      public.is_tenant_member(p_tenant_id)
      and exists (
        select 1
        from public.tenant_memberships as membership
        where membership.tenant_id = p_tenant_id
          and membership.user_id = (select auth.uid())
          and (membership.role = 'owner' or membership.can_delete_entries)
      )
    );
$$;

create or replace function public.record_tenant_member_audit_event(
  p_tenant_id uuid,
  p_subject_user_id uuid,
  p_action text,
  p_details jsonb
)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  insert into public.tenant_member_audit_events (
    tenant_id,
    actor_user_id,
    subject_user_id,
    action,
    details
  )
  values (
    p_tenant_id,
    (select auth.uid()),
    p_subject_user_id,
    p_action,
    coalesce(p_details, '{}'::jsonb)
  );
$$;

revoke all on function public.is_tenant_owner(uuid)
  from public, anon;
revoke all on function public.can_manage_tenant_members(uuid)
  from public, anon;
revoke all on function public.can_view_tenant_entries(uuid)
  from public, anon;
revoke all on function public.can_add_tenant_entries(uuid)
  from public, anon;
revoke all on function public.can_edit_tenant_entries(uuid)
  from public, anon;
revoke all on function public.can_delete_tenant_entries(uuid)
  from public, anon;
revoke all on function public.record_tenant_member_audit_event(
  uuid, uuid, text, jsonb
) from public, anon, authenticated;

grant execute on function public.is_tenant_owner(uuid) to authenticated;
grant execute on function public.can_manage_tenant_members(uuid)
  to authenticated;
grant execute on function public.can_view_tenant_entries(uuid)
  to authenticated;
grant execute on function public.can_add_tenant_entries(uuid)
  to authenticated;
grant execute on function public.can_edit_tenant_entries(uuid)
  to authenticated;
grant execute on function public.can_delete_tenant_entries(uuid)
  to authenticated;

create policy "Tenant owners and Super Admins can view member audit"
on public.tenant_member_audit_events
for select
to authenticated
using (public.can_manage_tenant_members(tenant_id));

create or replace function public.get_tenant_member_capacity(
  p_tenant_id uuid
)
returns table (
  member_limit integer,
  active_member_count integer,
  remaining_member_count integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_manage_tenant_members(p_tenant_id) then
    raise exception using
      errcode = '42501',
      message = 'Only the tenant owner or a Super Admin can view member usage.';
  end if;

  return query
  select
    tenant.member_limit,
    pg_catalog.count(membership.user_id)
      filter (where membership.role = 'member')::integer,
    greatest(
      0,
      tenant.member_limit
        - pg_catalog.count(membership.user_id)
            filter (where membership.role = 'member')::integer
    )
  from public.tenants as tenant
  left join public.tenant_memberships as membership
    on membership.tenant_id = tenant.id
  where tenant.id = p_tenant_id
  group by tenant.id, tenant.member_limit;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Tenant not found.';
  end if;
end;
$$;

create or replace function public.list_tenant_member_capacities()
returns table (
  tenant_id uuid,
  member_limit integer,
  active_member_count integer,
  remaining_member_count integer
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
      message = 'Only a Super Admin can view member usage for all tenants.';
  end if;

  return query
  select
    tenant.id,
    tenant.member_limit,
    pg_catalog.count(membership.user_id)
      filter (where membership.role = 'member')::integer,
    greatest(
      0,
      tenant.member_limit
        - pg_catalog.count(membership.user_id)
            filter (where membership.role = 'member')::integer
    )
  from public.tenants as tenant
  left join public.tenant_memberships as membership
    on membership.tenant_id = tenant.id
  group by tenant.id, tenant.member_limit
  order by tenant.name, tenant.id;
end;
$$;

drop function public.list_tenant_members(uuid);

create function public.list_tenant_members(p_tenant_id uuid)
returns table (
  user_id uuid,
  email text,
  role text,
  created_at timestamptz,
  can_view_entries boolean,
  can_add_entries boolean,
  can_edit_entries boolean,
  can_delete_entries boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_manage_tenant_members(p_tenant_id) then
    raise exception using
      errcode = '42501',
      message = 'Only the tenant owner or a Super Admin can manage members.';
  end if;

  if not exists (
    select 1
    from public.tenants as tenant
    where tenant.id = p_tenant_id
  ) then
    raise exception using
      errcode = 'P0002',
      message = 'Tenant not found.';
  end if;

  return query
  select
    membership.user_id,
    coalesce(user_account.email::text, ''),
    membership.role,
    membership.created_at,
    membership.can_view_entries,
    membership.can_add_entries,
    membership.can_edit_entries,
    membership.can_delete_entries
  from public.tenant_memberships as membership
  join auth.users as user_account on user_account.id = membership.user_id
  where membership.tenant_id = p_tenant_id
  order by membership.role, user_account.email, membership.user_id;
end;
$$;

create or replace function public.set_tenant_member_limit(
  p_tenant_id uuid,
  p_member_limit integer
)
returns table (
  member_limit integer,
  active_member_count integer,
  remaining_member_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_previous_limit integer;
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can change the member limit.';
  end if;

  if p_member_limit is null or p_member_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'The member limit must be an integer from 1 to 50.';
  end if;

  select tenant.member_limit
  into v_previous_limit
  from public.tenants as tenant
  where tenant.id = p_tenant_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Tenant not found.';
  end if;

  if v_previous_limit is distinct from p_member_limit then
    update public.tenants
    set member_limit = p_member_limit
    where id = p_tenant_id;

    perform public.record_tenant_member_audit_event(
      p_tenant_id,
      null,
      'member_limit_changed',
      pg_catalog.jsonb_build_object(
        'oldLimit', v_previous_limit,
        'newLimit', p_member_limit
      )
    );
  end if;

  return query
  select *
  from public.get_tenant_member_capacity(p_tenant_id);
end;
$$;

create or replace function public.add_tenant_member(
  p_tenant_id uuid,
  p_email text,
  p_role text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := pg_catalog.lower(pg_catalog.btrim(p_email));
  v_user_id uuid;
  v_archived_at timestamptz;
  v_member_limit integer;
  v_member_count integer;
  v_current_role text;
begin
  if p_tenant_id is null
    or v_email is null
    or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    or p_role is null
    or p_role not in ('owner', 'member')
  then
    raise exception using
      errcode = '22023',
      message = 'Enter a valid email and tenant role.';
  end if;

  select tenant.archived_at, tenant.member_limit
  into v_archived_at, v_member_limit
  from public.tenants as tenant
  where tenant.id = p_tenant_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Tenant not found.';
  end if;

  if not public.can_manage_tenant_members(p_tenant_id) then
    raise exception using
      errcode = '42501',
      message = 'Only the tenant owner or a Super Admin can manage members.';
  end if;

  if v_archived_at is not null then
    raise exception using
      errcode = '55000',
      message = 'Restore the tenant before adding members.';
  end if;

  if not public.is_super_admin() and p_role <> 'member' then
    raise exception using
      errcode = '42501',
      message = 'Tenant owners can add member-role accounts only.';
  end if;

  select user_account.id
  into v_user_id
  from auth.users as user_account
  where pg_catalog.lower(user_account.email::text) = v_email
  limit 1;

  if v_user_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'Member account not found.';
  end if;

  select membership.role
  into v_current_role
  from public.tenant_memberships as membership
  where membership.tenant_id = p_tenant_id
    and membership.user_id = v_user_id
  for update;

  if not found then
    if p_role = 'member' then
      select pg_catalog.count(*)::integer
      into v_member_count
      from public.tenant_memberships as membership
      where membership.tenant_id = p_tenant_id
        and membership.role = 'member';

      if v_member_count >= v_member_limit then
        raise exception using
          errcode = 'P0001',
          message = 'MEMBER_LIMIT_REACHED',
          detail = pg_catalog.jsonb_build_object(
            'memberLimit', v_member_limit,
            'activeMemberCount', v_member_count,
            'remainingMemberCount',
              greatest(0, v_member_limit - v_member_count)
          )::text;
      end if;
    end if;

    insert into public.tenant_memberships (tenant_id, user_id, role)
    values (p_tenant_id, v_user_id, p_role);

    perform public.record_tenant_member_audit_event(
      p_tenant_id,
      v_user_id,
      'member_added',
      pg_catalog.jsonb_build_object('role', p_role)
    );
  elsif v_current_role is distinct from p_role then
    if not public.is_super_admin() then
      raise exception using
        errcode = '42501',
        message = 'Tenant owners cannot change member roles.';
    end if;

    if v_current_role = 'owner' and p_role = 'member' then
      if (
        select pg_catalog.count(*)
        from public.tenant_memberships as membership
        where membership.tenant_id = p_tenant_id
          and membership.role = 'owner'
      ) <= 1 then
        raise exception using
          errcode = '23514',
          message = 'A tenant must keep at least one owner.';
      end if;

      select pg_catalog.count(*)::integer
      into v_member_count
      from public.tenant_memberships as membership
      where membership.tenant_id = p_tenant_id
        and membership.role = 'member';

      if v_member_count >= v_member_limit then
        raise exception using
          errcode = 'P0001',
          message = 'MEMBER_LIMIT_REACHED',
          detail = pg_catalog.jsonb_build_object(
            'memberLimit', v_member_limit,
            'activeMemberCount', v_member_count,
            'remainingMemberCount',
              greatest(0, v_member_limit - v_member_count)
          )::text;
      end if;
    end if;

    update public.tenant_memberships
    set role = p_role
    where tenant_id = p_tenant_id
      and user_id = v_user_id;

    perform public.record_tenant_member_audit_event(
      p_tenant_id,
      v_user_id,
      'member_role_changed',
      pg_catalog.jsonb_build_object(
        'oldRole', v_current_role,
        'newRole', p_role
      )
    );
  end if;

  return pg_catalog.jsonb_build_object(
    'user_id', v_user_id,
    'email', v_email,
    'role', p_role
  );
end;
$$;

create or replace function public.update_tenant_member_role(
  p_tenant_id uuid,
  p_user_id uuid,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current_role text;
  v_member_limit integer;
  v_member_count integer;
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can change tenant member roles.';
  end if;

  if p_tenant_id is null
    or p_user_id is null
    or p_role is null
    or p_role not in ('owner', 'member')
  then
    raise exception using
      errcode = '22023',
      message = 'Choose a valid tenant member role.';
  end if;

  select tenant.member_limit
  into v_member_limit
  from public.tenants as tenant
  where tenant.id = p_tenant_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Tenant not found.';
  end if;

  select membership.role
  into v_current_role
  from public.tenant_memberships as membership
  where membership.tenant_id = p_tenant_id
    and membership.user_id = p_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Tenant member not found.';
  end if;

  if v_current_role = p_role then
    return;
  end if;

  if v_current_role = 'owner' and p_role = 'member' then
    if (
      select pg_catalog.count(*)
      from public.tenant_memberships as membership
      where membership.tenant_id = p_tenant_id
        and membership.role = 'owner'
    ) <= 1 then
      raise exception using
        errcode = '23514',
        message = 'A tenant must keep at least one owner.';
    end if;

    select pg_catalog.count(*)::integer
    into v_member_count
    from public.tenant_memberships as membership
    where membership.tenant_id = p_tenant_id
      and membership.role = 'member';

    if v_member_count >= v_member_limit then
      raise exception using
        errcode = 'P0001',
        message = 'MEMBER_LIMIT_REACHED',
        detail = pg_catalog.jsonb_build_object(
          'memberLimit', v_member_limit,
          'activeMemberCount', v_member_count,
          'remainingMemberCount',
            greatest(0, v_member_limit - v_member_count)
        )::text;
    end if;
  end if;

  update public.tenant_memberships
  set role = p_role
  where tenant_id = p_tenant_id
    and user_id = p_user_id;

  perform public.record_tenant_member_audit_event(
    p_tenant_id,
    p_user_id,
    'member_role_changed',
    pg_catalog.jsonb_build_object(
      'oldRole', v_current_role,
      'newRole', p_role
    )
  );
end;
$$;

create or replace function public.set_tenant_member_permissions(
  p_tenant_id uuid,
  p_user_id uuid,
  p_can_view_entries boolean,
  p_can_add_entries boolean,
  p_can_edit_entries boolean,
  p_can_delete_entries boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_old_permissions jsonb;
  v_new_permissions jsonb;
begin
  if p_tenant_id is null
    or p_user_id is null
    or p_can_view_entries is null
    or p_can_add_entries is null
    or p_can_edit_entries is null
    or p_can_delete_entries is null
  then
    raise exception using
      errcode = '22023',
      message = 'Choose a tenant member and all four entry permissions.';
  end if;

  if not public.can_manage_tenant_members(p_tenant_id) then
    raise exception using
      errcode = '42501',
      message = 'Only the tenant owner or a Super Admin can change permissions.';
  end if;

  select
    membership.role,
    pg_catalog.jsonb_build_object(
      'view', membership.can_view_entries,
      'add', membership.can_add_entries,
      'edit', membership.can_edit_entries,
      'delete', membership.can_delete_entries
    )
  into v_role, v_old_permissions
  from public.tenant_memberships as membership
  where membership.tenant_id = p_tenant_id
    and membership.user_id = p_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Tenant member not found.';
  end if;

  if v_role <> 'member' then
    raise exception using
      errcode = '22023',
      message = 'Entry permissions can be assigned to member-role accounts only.';
  end if;

  v_new_permissions := pg_catalog.jsonb_build_object(
    'view', p_can_view_entries,
    'add', p_can_add_entries,
    'edit', p_can_edit_entries,
    'delete', p_can_delete_entries
  );

  if v_old_permissions is distinct from v_new_permissions then
    update public.tenant_memberships
    set
      can_view_entries = p_can_view_entries,
      can_add_entries = p_can_add_entries,
      can_edit_entries = p_can_edit_entries,
      can_delete_entries = p_can_delete_entries
    where tenant_id = p_tenant_id
      and user_id = p_user_id;

    perform public.record_tenant_member_audit_event(
      p_tenant_id,
      p_user_id,
      'member_permissions_changed',
      pg_catalog.jsonb_build_object(
        'oldPermissions', v_old_permissions,
        'newPermissions', v_new_permissions
      )
    );
  end if;
end;
$$;

create or replace function public.remove_tenant_member(
  p_tenant_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text;
begin
  if p_tenant_id is null or p_user_id is null then
    raise exception using
      errcode = '22023',
      message = 'Select a tenant member to remove.';
  end if;

  perform 1
  from public.tenants as tenant
  where tenant.id = p_tenant_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Tenant not found.';
  end if;

  if not public.can_manage_tenant_members(p_tenant_id) then
    raise exception using
      errcode = '42501',
      message = 'Only the tenant owner or a Super Admin can remove members.';
  end if;

  select membership.role
  into v_role
  from public.tenant_memberships as membership
  where membership.tenant_id = p_tenant_id
    and membership.user_id = p_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Tenant member not found.';
  end if;

  if v_role = 'owner' then
    if not public.is_super_admin() then
      raise exception using
        errcode = '42501',
        message = 'Tenant owners can remove member-role accounts only.';
    end if;

    if (
      select pg_catalog.count(*)
      from public.tenant_memberships as membership
      where membership.tenant_id = p_tenant_id
        and membership.role = 'owner'
    ) <= 1 then
      raise exception using
        errcode = '23514',
        message = 'A tenant must keep at least one owner.';
    end if;
  end if;

  perform public.record_tenant_member_audit_event(
    p_tenant_id,
    p_user_id,
    'member_removed',
    pg_catalog.jsonb_build_object('role', v_role)
  );

  delete from public.tenant_memberships
  where tenant_id = p_tenant_id
    and user_id = p_user_id;
end;
$$;

create or replace function public.list_tenant_member_audit_events(
  p_tenant_id uuid,
  p_limit integer
)
returns table (
  id bigint,
  action text,
  details jsonb,
  actor_email text,
  subject_email text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_limit is null or p_limit not between 1 and 200 then
    raise exception using
      errcode = '22023',
      message = 'The audit page size must be from 1 to 200.';
  end if;

  if not public.can_manage_tenant_members(p_tenant_id) then
    raise exception using
      errcode = '42501',
      message = 'Only the tenant owner or a Super Admin can view member audit.';
  end if;

  return query
  select
    audit_event.id,
    audit_event.action,
    audit_event.details,
    actor.email::text,
    subject.email::text,
    audit_event.created_at
  from public.tenant_member_audit_events as audit_event
  left join auth.users as actor on actor.id = audit_event.actor_user_id
  left join auth.users as subject on subject.id = audit_event.subject_user_id
  where audit_event.tenant_id = p_tenant_id
  order by audit_event.created_at desc, audit_event.id desc
  limit p_limit;
end;
$$;

drop function public.list_my_device_session_tenant_choices();

create function public.list_my_device_session_tenant_choices()
returns table (
  tenant_id uuid,
  tenant_name text,
  tenant_slug text,
  role text,
  archived_at timestamptz,
  valid_until date,
  can_view_entries boolean,
  can_add_entries boolean,
  can_edit_entries boolean,
  can_delete_entries boolean
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
    tenant.valid_until,
    membership.can_view_entries,
    membership.can_add_entries,
    membership.can_edit_entries,
    membership.can_delete_entries
  from public.tenant_memberships as membership
  join public.tenants as tenant on tenant.id = membership.tenant_id
  where membership.user_id = v_user_id
    and tenant.archived_at is null
    and tenant.valid_until >=
      (pg_catalog.now() at time zone 'Asia/Kolkata')::date
  order by tenant.name, tenant.id;
end;
$$;

create or replace function public.create_parking_session(
  p_tenant_id uuid,
  p_plate_number text,
  p_entry_time timestamptz,
  p_allowed_duration_value integer,
  p_allowed_duration_unit text,
  p_expires_at timestamptz,
  p_total_charge numeric,
  p_paid_amount numeric,
  p_has_photo boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_session_id uuid;
  v_plate_number text := pg_catalog.upper(pg_catalog.btrim(p_plate_number));
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;

  if p_tenant_id is null
    or v_plate_number is null
    or pg_catalog.char_length(v_plate_number) not between 1 and 64
    or p_entry_time is null
    or p_allowed_duration_value is null
    or p_allowed_duration_value <= 0
    or p_allowed_duration_unit not in ('minutes', 'hours', 'days', 'months')
    or p_expires_at is null
    or p_expires_at <= p_entry_time
    or p_total_charge is null
    or p_total_charge < 0
    or p_paid_amount is null
    or p_paid_amount < 0
    or p_paid_amount > p_total_charge
    or p_has_photo is null
  then
    raise exception using
      errcode = '22023',
      message = 'The parking-session values are invalid.';
  end if;

  if not public.can_add_tenant_entries(p_tenant_id) then
    raise exception using
      errcode = '42501',
      message = 'You do not have permission to add parking entries.';
  end if;

  insert into public.parking_sessions (
    tenant_id,
    plate_number,
    entry_time,
    allowed_duration_value,
    allowed_duration_unit,
    expires_at,
    created_by,
    total_charge,
    paid_amount,
    photo_upload_pending
  )
  values (
    p_tenant_id,
    v_plate_number,
    p_entry_time,
    p_allowed_duration_value,
    p_allowed_duration_unit,
    p_expires_at,
    v_user_id,
    p_total_charge,
    p_paid_amount,
    p_has_photo
  )
  returning id into v_session_id;

  return v_session_id;
end;
$$;

create or replace function public.set_new_parking_session_photo_path(
  p_session_id uuid,
  p_photo_path text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.parking_sessions;
  v_expected_prefix text;
begin
  if p_session_id is null or p_photo_path is null then
    raise exception using
      errcode = '22023',
      message = 'A parking session and photo path are required.';
  end if;

  select session.*
  into v_session
  from public.parking_sessions as session
  where session.id = p_session_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Parking session not found.';
  end if;

  v_expected_prefix := v_session.created_by::text || '/'
    || v_session.id::text || '/';

  if v_session.created_by <> (select auth.uid())
    or not v_session.photo_upload_pending
    or v_session.photo_path is not null
    or pg_catalog.left(p_photo_path, pg_catalog.length(v_expected_prefix))
      <> v_expected_prefix
    or pg_catalog.length(p_photo_path) > 512
    or position('/' in pg_catalog.substr(
      p_photo_path,
      pg_catalog.length(v_expected_prefix) + 1
    )) > 0
    or not public.can_add_tenant_entries(v_session.tenant_id)
  then
    raise exception using
      errcode = '42501',
      message = 'You cannot attach this photo to the parking session.';
  end if;

  update public.parking_sessions
  set photo_path = p_photo_path
  where id = p_session_id;
end;
$$;

create or replace function public.complete_parking_session_photo_upload(
  p_session_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.parking_sessions;
begin
  if p_session_id is null then
    raise exception using
      errcode = '22023',
      message = 'A parking session is required.';
  end if;

  select session.*
  into v_session
  from public.parking_sessions as session
  where session.id = p_session_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Parking session not found.';
  end if;

  if v_session.created_by <> (select auth.uid())
    or v_session.photo_path is null
    or not public.can_add_tenant_entries(v_session.tenant_id)
  then
    raise exception using
      errcode = '42501',
      message = 'You cannot complete this photo upload.';
  end if;

  update public.parking_sessions
  set photo_upload_pending = false
  where id = p_session_id
    and photo_upload_pending;
end;
$$;

create or replace function public.can_read_vehicle_photo(p_photo_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.parking_sessions as session
    where session.id::text = (storage.foldername(p_photo_path))[2]
      and session.created_by::text = (storage.foldername(p_photo_path))[1]
      and session.photo_path = p_photo_path
      and public.can_view_tenant_entries(session.tenant_id)
  );
$$;

create or replace function public.can_upload_vehicle_photo(p_photo_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.parking_sessions as session
    where session.id::text = (storage.foldername(p_photo_path))[2]
      and session.created_by::text = (storage.foldername(p_photo_path))[1]
      and session.photo_path = p_photo_path
      and (
        public.can_edit_tenant_entries(session.tenant_id)
        or (
          session.created_by = (select auth.uid())
          and session.photo_upload_pending
          and session.photo_path = p_photo_path
          and public.can_add_tenant_entries(session.tenant_id)
        )
      )
  );
$$;

create or replace function public.can_update_vehicle_photo(p_photo_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.parking_sessions as session
    where session.id::text = (storage.foldername(p_photo_path))[2]
      and session.created_by::text = (storage.foldername(p_photo_path))[1]
      and session.photo_path = p_photo_path
      and public.can_edit_tenant_entries(session.tenant_id)
  );
$$;

create or replace function public.can_delete_vehicle_photo(p_photo_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.parking_sessions as session
    where session.id::text = (storage.foldername(p_photo_path))[2]
      and session.created_by::text = (storage.foldername(p_photo_path))[1]
      and session.photo_path = p_photo_path
      and (
        public.can_edit_tenant_entries(session.tenant_id)
        or public.can_delete_tenant_entries(session.tenant_id)
        or (
          session.created_by = (select auth.uid())
          and session.photo_upload_pending
          and session.photo_path = p_photo_path
          and public.can_add_tenant_entries(session.tenant_id)
        )
      )
  );
$$;

drop policy if exists
  "Tenant members and Super Admins can view parking sessions"
  on public.parking_sessions;
drop policy if exists
  "Tenant members and Super Admins can create parking sessions"
  on public.parking_sessions;
drop policy if exists
  "Tenant members and Super Admins can update parking sessions"
  on public.parking_sessions;
drop policy if exists
  "Tenant members and Super Admins can delete parking sessions"
  on public.parking_sessions;

create policy "Authorized tenant users can view parking sessions"
on public.parking_sessions
for select
to authenticated
using (public.can_view_tenant_entries(tenant_id));

create policy "Authorized tenant users can add parking sessions"
on public.parking_sessions
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and public.can_add_tenant_entries(tenant_id)
  and photo_path is null
  and not photo_upload_pending
);

create policy "Authorized tenant users can edit parking sessions"
on public.parking_sessions
for update
to authenticated
using (public.can_edit_tenant_entries(tenant_id))
with check (public.can_edit_tenant_entries(tenant_id));

create policy "Authorized tenant users can delete parking sessions"
on public.parking_sessions
for delete
to authenticated
using (
  public.can_delete_tenant_entries(tenant_id)
  or (
    public.can_add_tenant_entries(tenant_id)
    and created_by = (select auth.uid())
    and photo_upload_pending
  )
);

drop policy if exists "Tenant members and Super Admins can read vehicle photos"
  on storage.objects;
drop policy if exists
  "Tenant members and Super Admins can upload vehicle photos"
  on storage.objects;
drop policy if exists
  "Tenant members and Super Admins can update vehicle photos"
  on storage.objects;
drop policy if exists
  "Tenant members and Super Admins can delete vehicle photos"
  on storage.objects;

create policy "Authorized tenant users can read vehicle photos"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'vehicle-photos'
  and public.can_read_vehicle_photo(name)
);

create policy "Authorized tenant users can upload vehicle photos"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'vehicle-photos'
  and public.can_upload_vehicle_photo(name)
);

create policy "Authorized tenant users can update vehicle photos"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'vehicle-photos'
  and public.can_update_vehicle_photo(name)
)
with check (
  bucket_id = 'vehicle-photos'
  and public.can_update_vehicle_photo(name)
);

create policy "Authorized tenant users can delete vehicle photos"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'vehicle-photos'
  and public.can_delete_vehicle_photo(name)
);

revoke all on function public.get_tenant_member_capacity(uuid)
  from public, anon;
revoke all on function public.list_tenant_member_capacities()
  from public, anon;
revoke all on function public.list_tenant_members(uuid)
  from public, anon;
revoke all on function public.set_tenant_member_limit(uuid, integer)
  from public, anon;
revoke all on function public.add_tenant_member(uuid, text, text)
  from public, anon;
revoke all on function public.update_tenant_member_role(uuid, uuid, text)
  from public, anon;
revoke all on function public.set_tenant_member_permissions(
  uuid, uuid, boolean, boolean, boolean, boolean
) from public, anon;
revoke all on function public.remove_tenant_member(uuid, uuid)
  from public, anon;
revoke all on function public.list_tenant_member_audit_events(uuid, integer)
  from public, anon;
revoke all on function public.list_my_device_session_tenant_choices()
  from public, anon;
revoke all on function public.create_parking_session(
  uuid, text, timestamptz, integer, text, timestamptz, numeric, numeric, boolean
) from public, anon;
revoke all on function public.set_new_parking_session_photo_path(uuid, text)
  from public, anon;
revoke all on function public.complete_parking_session_photo_upload(uuid)
  from public, anon;
revoke all on function public.can_read_vehicle_photo(text)
  from public, anon;
revoke all on function public.can_upload_vehicle_photo(text)
  from public, anon;
revoke all on function public.can_update_vehicle_photo(text)
  from public, anon;
revoke all on function public.can_delete_vehicle_photo(text)
  from public, anon;

grant execute on function public.get_tenant_member_capacity(uuid)
  to authenticated;
grant execute on function public.list_tenant_member_capacities()
  to authenticated;
grant execute on function public.list_tenant_members(uuid)
  to authenticated;
grant execute on function public.set_tenant_member_limit(uuid, integer)
  to authenticated;
grant execute on function public.add_tenant_member(uuid, text, text)
  to authenticated;
grant execute on function public.update_tenant_member_role(uuid, uuid, text)
  to authenticated;
grant execute on function public.set_tenant_member_permissions(
  uuid, uuid, boolean, boolean, boolean, boolean
) to authenticated;
grant execute on function public.remove_tenant_member(uuid, uuid)
  to authenticated;
grant execute on function public.list_tenant_member_audit_events(uuid, integer)
  to authenticated;
grant execute on function public.list_my_device_session_tenant_choices()
  to authenticated;
grant execute on function public.create_parking_session(
  uuid, text, timestamptz, integer, text, timestamptz, numeric, numeric, boolean
) to authenticated;
grant execute on function public.set_new_parking_session_photo_path(uuid, text)
  to authenticated;
grant execute on function public.complete_parking_session_photo_upload(uuid)
  to authenticated;
grant execute on function public.can_read_vehicle_photo(text)
  to authenticated;
grant execute on function public.can_upload_vehicle_photo(text)
  to authenticated;
grant execute on function public.can_update_vehicle_photo(text)
  to authenticated;
grant execute on function public.can_delete_vehicle_photo(text)
  to authenticated;

commit;
