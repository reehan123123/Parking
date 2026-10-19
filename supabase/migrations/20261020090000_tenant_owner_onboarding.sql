begin;

create table public.tenant_creation_requests (
  request_id uuid primary key,
  requested_by uuid not null references auth.users(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  tenant_name text not null,
  created_at timestamptz not null default now(),
  constraint tenant_creation_requests_name_check
    check (char_length(btrim(tenant_name)) between 1 and 120)
);

alter table public.tenant_creation_requests enable row level security;
revoke all on table public.tenant_creation_requests
  from public, anon, authenticated;

create or replace function public.is_temporary_password_reset_required()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select auth.jwt() -> 'app_metadata'
      ->> 'parking_temporary_password_reset_required') = 'true',
    false
  );
$$;

revoke all on function public.is_temporary_password_reset_required()
  from public, anon;
grant execute on function public.is_temporary_password_reset_required()
  to authenticated;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not (select public.is_temporary_password_reset_required())
    and exists (
      select 1
      from public.super_admins as super_admin
      where super_admin.user_id = (select auth.uid())
    );
$$;

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
      where membership.tenant_id = p_tenant_id
        and membership.user_id = (select auth.uid())
        and tenant.archived_at is null
    );
$$;

drop policy if exists "Users can view their own tenant memberships"
  on public.tenant_memberships;
drop policy if exists "Members and Super Admins can view tenant memberships"
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

create or replace function public.tenant_owner_onboarding_state(p_email text)
returns table (
  user_id uuid,
  temporary_password_reset_required boolean,
  tenant_owner_onboarding_pending boolean,
  tenant_owner_onboarding_request_id uuid
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    user_account.id,
    coalesce(
      user_account.raw_app_meta_data
        ->> 'parking_temporary_password_reset_required',
      'false'
    ) = 'true',
    coalesce(
      user_account.raw_app_meta_data
        ->> 'parking_tenant_owner_onboarding_pending',
      'false'
    ) = 'true',
    nullif(
      user_account.raw_app_meta_data
        ->> 'parking_tenant_owner_onboarding_request_id',
      ''
    )::uuid
  from auth.users as user_account
  where pg_catalog.lower(user_account.email)
    = pg_catalog.lower(pg_catalog.btrim(p_email))
  limit 1;
$$;

revoke all on function public.tenant_owner_onboarding_state(text)
  from public, anon, authenticated;
grant execute on function public.tenant_owner_onboarding_state(text)
  to service_role;

create or replace function public.create_tenant_for_request(
  p_name text,
  p_owner_email text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := pg_catalog.btrim(p_name);
  v_owner_email text := pg_catalog.lower(pg_catalog.btrim(p_owner_email));
  v_owner_id uuid;
  v_tenant_id uuid;
  v_tenant_name text;
  v_slug text;
  v_tenant jsonb;
  v_existing public.tenant_creation_requests;
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can create tenants.';
  end if;

  if v_name is null
    or pg_catalog.char_length(v_name) not between 1 and 120
    or v_owner_email is null
    or v_owner_email = ''
    or p_request_id is null
  then
    raise exception using
      errcode = '22023',
      message = 'Tenant name, owner email, and request ID are required.';
  end if;

  select user_account.id
  into v_owner_id
  from auth.users as user_account
  where pg_catalog.lower(user_account.email) = v_owner_email
  limit 1;

  if v_owner_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'Owner account not found.';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_request_id::text, 0::bigint)
  );

  select request.*
  into v_existing
  from public.tenant_creation_requests as request
  where request.request_id = p_request_id;

  if found then
    if v_existing.requested_by is distinct from (select auth.uid())
      or v_existing.owner_user_id is distinct from v_owner_id
      or v_existing.tenant_name is distinct from v_name
    then
      raise exception using
        errcode = '22023',
        message = 'The request ID was already used for different tenant data.';
    end if;

    select tenant.id, tenant.name, tenant.slug
    into v_tenant_id, v_tenant_name, v_slug
    from public.tenants as tenant
    where tenant.id = v_existing.tenant_id;

    if not found then
      raise exception using
        errcode = 'P0002',
        message = 'The tenant for this request could not be found.';
    end if;

    return pg_catalog.jsonb_build_object(
      'id', v_tenant_id,
      'name', v_tenant_name,
      'slug', v_slug,
      'reused_request', true
    );
  end if;

  v_tenant := public.create_tenant(v_name, v_owner_email);
  v_tenant_id := (v_tenant ->> 'id')::uuid;

  insert into public.tenant_creation_requests (
    request_id,
    requested_by,
    tenant_id,
    owner_user_id,
    tenant_name
  )
  values (
    p_request_id,
    (select auth.uid()),
    v_tenant_id,
    v_owner_id,
    v_name
  );

  return v_tenant || pg_catalog.jsonb_build_object(
    'reused_request',
    false
  );
end;
$$;

revoke all on function public.create_tenant_for_request(text, text, uuid)
  from public, anon;
grant execute on function public.create_tenant_for_request(text, text, uuid)
  to authenticated;

commit;
