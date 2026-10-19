begin;

alter table public.tenants
  add column archived_at timestamptz;

create or replace function public.is_tenant_member(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.tenant_memberships as membership
    join public.tenants as tenant on tenant.id = membership.tenant_id
    where membership.tenant_id = p_tenant_id
      and membership.user_id = (select auth.uid())
      and tenant.archived_at is null
  );
$$;

drop policy if exists "Users can view their own tenant memberships"
  on public.tenant_memberships;

create policy "Members and Super Admins can view tenant memberships"
on public.tenant_memberships
for select
to authenticated
using (
  (select public.is_super_admin())
  or (
    user_id = (select auth.uid())
    and (select public.is_tenant_member(tenant_id))
  )
);

create or replace function public.update_tenant(
  p_tenant_id uuid,
  p_name text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := pg_catalog.btrim(p_name);
  v_tenant public.tenants;
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can update tenants.';
  end if;

  if v_name is null
    or pg_catalog.char_length(v_name) not between 1 and 120
  then
    raise exception using
      errcode = '22023',
      message = 'Tenant name must be between 1 and 120 characters.';
  end if;

  update public.tenants as tenant
  set name = v_name
  where tenant.id = p_tenant_id
  returning tenant.* into v_tenant;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Tenant not found.';
  end if;

  return pg_catalog.jsonb_build_object(
    'id', v_tenant.id,
    'name', v_tenant.name,
    'slug', v_tenant.slug,
    'archived_at', v_tenant.archived_at
  );
end;
$$;

create or replace function public.archive_tenant(p_tenant_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can archive tenants.';
  end if;

  update public.tenants
  set archived_at = coalesce(archived_at, pg_catalog.now())
  where id = p_tenant_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Tenant not found.';
  end if;
end;
$$;

create or replace function public.restore_tenant(p_tenant_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can restore tenants.';
  end if;

  update public.tenants
  set archived_at = null
  where id = p_tenant_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Tenant not found.';
  end if;
end;
$$;

create or replace function public.list_tenant_members(p_tenant_id uuid)
returns table (
  user_id uuid,
  email text,
  role text
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
      message = 'Only a Super Admin can manage tenant members.';
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
    coalesce(user_account.email, ''),
    membership.role
  from public.tenant_memberships as membership
  join auth.users as user_account on user_account.id = membership.user_id
  where membership.tenant_id = p_tenant_id
  order by membership.role, user_account.email, membership.user_id;
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
  v_current_role text;
  v_owner_count bigint;
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can manage tenant members.';
  end if;

  if p_role is null or p_role not in ('owner', 'member') then
    raise exception using
      errcode = '22023',
      message = 'Tenant role must be owner or member.';
  end if;

  select tenant.archived_at
  into v_archived_at
  from public.tenants as tenant
  where tenant.id = p_tenant_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Tenant not found.';
  end if;

  if v_archived_at is not null then
    raise exception using
      errcode = '55000',
      message = 'Restore the tenant before adding members.';
  end if;

  select user_account.id
  into v_user_id
  from auth.users as user_account
  where pg_catalog.lower(user_account.email) = v_email
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
    and membership.user_id = v_user_id;

  if found and v_current_role = 'owner' and p_role <> 'owner' then
    select pg_catalog.count(*)
    into v_owner_count
    from public.tenant_memberships as membership
    where membership.tenant_id = p_tenant_id
      and membership.role = 'owner';

    if v_owner_count <= 1 then
      raise exception using
        errcode = '23514',
        message = 'A tenant must keep at least one owner.';
    end if;
  end if;

  insert into public.tenant_memberships (tenant_id, user_id, role)
  values (p_tenant_id, v_user_id, p_role)
  on conflict (tenant_id, user_id)
  do update set role = excluded.role;

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
  v_owner_count bigint;
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can manage tenant members.';
  end if;

  if p_role is null or p_role not in ('owner', 'member') then
    raise exception using
      errcode = '22023',
      message = 'Tenant role must be owner or member.';
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

  select membership.role
  into v_current_role
  from public.tenant_memberships as membership
  where membership.tenant_id = p_tenant_id
    and membership.user_id = p_user_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Tenant member not found.';
  end if;

  if v_current_role = 'owner' and p_role <> 'owner' then
    select pg_catalog.count(*)
    into v_owner_count
    from public.tenant_memberships as membership
    where membership.tenant_id = p_tenant_id
      and membership.role = 'owner';

    if v_owner_count <= 1 then
      raise exception using
        errcode = '23514',
        message = 'A tenant must keep at least one owner.';
    end if;
  end if;

  update public.tenant_memberships
  set role = p_role
  where tenant_id = p_tenant_id
    and user_id = p_user_id;
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
  v_owner_count bigint;
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can manage tenant members.';
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

  select membership.role
  into v_role
  from public.tenant_memberships as membership
  where membership.tenant_id = p_tenant_id
    and membership.user_id = p_user_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Tenant member not found.';
  end if;

  if v_role = 'owner' then
    select pg_catalog.count(*)
    into v_owner_count
    from public.tenant_memberships as membership
    where membership.tenant_id = p_tenant_id
      and membership.role = 'owner';

    if v_owner_count <= 1 then
      raise exception using
        errcode = '23514',
        message = 'A tenant must keep at least one owner.';
    end if;
  end if;

  delete from public.tenant_memberships
  where tenant_id = p_tenant_id
    and user_id = p_user_id;
end;
$$;

revoke all on function public.update_tenant(uuid, text) from public, anon;
revoke all on function public.archive_tenant(uuid) from public, anon;
revoke all on function public.restore_tenant(uuid) from public, anon;
revoke all on function public.list_tenant_members(uuid) from public, anon;
revoke all on function public.add_tenant_member(uuid, text, text)
  from public, anon;
revoke all on function public.update_tenant_member_role(uuid, uuid, text)
  from public, anon;
revoke all on function public.remove_tenant_member(uuid, uuid)
  from public, anon;

grant execute on function public.update_tenant(uuid, text) to authenticated;
grant execute on function public.archive_tenant(uuid) to authenticated;
grant execute on function public.restore_tenant(uuid) to authenticated;
grant execute on function public.list_tenant_members(uuid) to authenticated;
grant execute on function public.add_tenant_member(uuid, text, text)
  to authenticated;
grant execute on function public.update_tenant_member_role(uuid, uuid, text)
  to authenticated;
grant execute on function public.remove_tenant_member(uuid, uuid)
  to authenticated;

commit;
