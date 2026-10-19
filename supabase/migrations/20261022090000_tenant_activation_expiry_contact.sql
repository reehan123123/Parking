begin;

-- Reuses the existing public.tenants.archived_at column as the Active /
-- Inactive status (archived_at is null => Active, set => Inactive) instead
-- of introducing a duplicate status column.
alter table public.tenants
  add column valid_until date,
  add column contact_name text,
  add column contact_mobile text,
  add column contact_email text;

alter table public.tenants
  add constraint tenants_contact_name_check
    check (contact_name is null or char_length(btrim(contact_name)) between 1 and 120),
  add constraint tenants_contact_mobile_check
    check (contact_mobile is null or contact_mobile ~ '^\+91[6-9][0-9]{9}$'),
  add constraint tenants_contact_email_check
    check (
      contact_email is null
      or contact_email ~ '^[^\s@]+@[^\s@]+\.[^\s@]+$'
    );

-- Safe default for pre-existing tenants: preserve their current (implicitly
-- unlimited) access instead of retroactively locking anyone out. The
-- business timezone used for all validity-date comparisons is Asia/Kolkata,
-- the application's primary locale.
update public.tenants
set valid_until = ((now() at time zone 'Asia/Kolkata')::date + interval '3650 days')::date
where valid_until is null;

alter table public.tenants
  alter column valid_until set not null;

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
        and tenant.valid_until >= (now() at time zone 'Asia/Kolkata')::date
    );
$$;

create or replace function public.create_tenant(
  p_name text,
  p_owner_email text,
  p_valid_until date,
  p_is_active boolean default true,
  p_contact_name text default null,
  p_contact_mobile text default null,
  p_contact_email text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := pg_catalog.btrim(p_name);
  v_owner_email text := pg_catalog.lower(pg_catalog.btrim(p_owner_email));
  v_contact_name text := nullif(pg_catalog.btrim(p_contact_name), '');
  v_contact_mobile text := nullif(pg_catalog.btrim(p_contact_mobile), '');
  v_contact_email text :=
    nullif(pg_catalog.lower(pg_catalog.btrim(p_contact_email)), '');
  v_owner_id uuid;
  v_tenant_id uuid;
  v_slug_base text;
  v_slug text;
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can create tenants.';
  end if;

  if v_name is null or pg_catalog.char_length(v_name) not between 1 and 120 then
    raise exception using
      errcode = '22023',
      message = 'Tenant name must be between 1 and 120 characters.';
  end if;

  if v_owner_email is null or v_owner_email = '' then
    raise exception using
      errcode = '22023',
      message = 'An existing owner email is required.';
  end if;

  if p_valid_until is null then
    raise exception using
      errcode = '22023',
      message = 'A tenant validity end date is required.';
  end if;

  if v_contact_mobile is not null and v_contact_mobile !~ '^\+91[6-9][0-9]{9}$' then
    raise exception using
      errcode = '22023',
      message = 'Enter a valid 10-digit Indian mobile number.';
  end if;

  if v_contact_email is not null and v_contact_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' then
    raise exception using
      errcode = '22023',
      message = 'Enter a valid contact email address.';
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

  v_slug_base := pg_catalog.btrim(
    pg_catalog.regexp_replace(pg_catalog.lower(v_name), '[^a-z0-9]+', '-', 'g'),
    '-'
  );
  if v_slug_base = '' then
    v_slug_base := 'workspace';
  end if;
  v_slug := pg_catalog.left(v_slug_base, 60)
    || '-'
    || pg_catalog.left(
      pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', ''),
      8
    );

  insert into public.tenants (
    name,
    slug,
    created_by,
    archived_at,
    valid_until,
    contact_name,
    contact_mobile,
    contact_email
  )
  values (
    v_name,
    v_slug,
    (select auth.uid()),
    case when p_is_active then null else pg_catalog.now() end,
    p_valid_until,
    v_contact_name,
    v_contact_mobile,
    v_contact_email
  )
  returning id into v_tenant_id;

  insert into public.tenant_memberships (tenant_id, user_id, role)
  values (v_tenant_id, v_owner_id, 'owner');

  return pg_catalog.jsonb_build_object(
    'id', v_tenant_id,
    'name', v_name,
    'slug', v_slug
  );
end;
$$;

revoke all on function public.create_tenant(
  text, text, date, boolean, text, text, text
) from public, anon;
grant execute on function public.create_tenant(
  text, text, date, boolean, text, text, text
) to authenticated;

create or replace function public.create_tenant_for_request(
  p_name text,
  p_owner_email text,
  p_request_id uuid,
  p_valid_until date,
  p_is_active boolean default true,
  p_contact_name text default null,
  p_contact_mobile text default null,
  p_contact_email text default null
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
    or p_valid_until is null
  then
    raise exception using
      errcode = '22023',
      message = 'Tenant name, owner email, validity date, and request ID are required.';
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

  v_tenant := public.create_tenant(
    v_name,
    v_owner_email,
    p_valid_until,
    p_is_active,
    p_contact_name,
    p_contact_mobile,
    p_contact_email
  );
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

revoke all on function public.create_tenant_for_request(
  text, text, uuid, date, boolean, text, text, text
) from public, anon;
grant execute on function public.create_tenant_for_request(
  text, text, uuid, date, boolean, text, text, text
) to authenticated;

drop function if exists public.update_tenant(uuid, text);

create or replace function public.update_tenant(
  p_tenant_id uuid,
  p_name text,
  p_valid_until date,
  p_contact_name text default null,
  p_contact_mobile text default null,
  p_contact_email text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := pg_catalog.btrim(p_name);
  v_contact_name text := nullif(pg_catalog.btrim(p_contact_name), '');
  v_contact_mobile text := nullif(pg_catalog.btrim(p_contact_mobile), '');
  v_contact_email text :=
    nullif(pg_catalog.lower(pg_catalog.btrim(p_contact_email)), '');
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

  if p_valid_until is null then
    raise exception using
      errcode = '22023',
      message = 'A tenant validity end date is required.';
  end if;

  if v_contact_mobile is not null and v_contact_mobile !~ '^\+91[6-9][0-9]{9}$' then
    raise exception using
      errcode = '22023',
      message = 'Enter a valid 10-digit Indian mobile number.';
  end if;

  if v_contact_email is not null and v_contact_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' then
    raise exception using
      errcode = '22023',
      message = 'Enter a valid contact email address.';
  end if;

  -- Status (archived_at) is intentionally left untouched here so editing
  -- unrelated fields can never silently reactivate an inactive/expired
  -- tenant. Use archive_tenant / restore_tenant to change status.
  update public.tenants as tenant
  set
    name = v_name,
    valid_until = p_valid_until,
    contact_name = v_contact_name,
    contact_mobile = v_contact_mobile,
    contact_email = v_contact_email
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
    'archived_at', v_tenant.archived_at,
    'valid_until', v_tenant.valid_until,
    'contact_name', v_tenant.contact_name,
    'contact_mobile', v_tenant.contact_mobile,
    'contact_email', v_tenant.contact_email
  );
end;
$$;

revoke all on function public.update_tenant(uuid, text, date, text, text, text)
  from public, anon;
grant execute on function public.update_tenant(uuid, text, date, text, text, text)
  to authenticated;

-- Add a validated contact number to parking sessions. Nullable at the
-- database level to avoid breaking historical rows; the application layer
-- requires it for newly created sessions.
alter table public.parking_sessions
  add column contact_number text;

alter table public.parking_sessions
  add constraint parking_sessions_contact_number_check
    check (contact_number is null or contact_number ~ '^\+91[6-9][0-9]{9}$');

commit;
