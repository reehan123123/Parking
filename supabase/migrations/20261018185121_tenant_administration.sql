begin;

create table public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint tenants_name_check
    check (char_length(btrim(name)) between 1 and 120),
  constraint tenants_slug_check
    check (char_length(btrim(slug)) between 1 and 80)
);

create table public.tenant_memberships (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null,
  created_at timestamptz not null default now(),
  constraint tenant_memberships_role_check
    check (role in ('owner', 'member')),
  primary key (tenant_id, user_id)
);

create index tenant_memberships_user_id_idx
  on public.tenant_memberships (user_id, tenant_id);

create table public.super_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.parking_sessions
  add column tenant_id uuid references public.tenants(id) on delete restrict;

insert into public.tenants (name, slug, created_by)
select
  'Personal workspace',
  'personal-' || replace(user_account.id::text, '-', ''),
  user_account.id
from auth.users as user_account
on conflict (slug) do nothing;

insert into public.tenant_memberships (tenant_id, user_id, role)
select tenant.id, tenant.created_by, 'owner'
from public.tenants as tenant
where tenant.slug like 'personal-%'
  and tenant.created_by is not null
on conflict (tenant_id, user_id) do nothing;

update public.parking_sessions as session
set tenant_id = tenant.id
from public.tenants as tenant
where tenant.created_by = session.created_by
  and tenant.slug =
    'personal-' || replace(session.created_by::text, '-', '');

alter table public.parking_sessions
  alter column tenant_id set not null;

create index parking_sessions_tenant_entry_idx
  on public.parking_sessions (tenant_id, entry_time desc, id desc);
create index parking_sessions_tenant_expires_idx
  on public.parking_sessions (tenant_id, expires_at);

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.super_admins as super_admin
    where super_admin.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_super_admin() from public, anon;
grant execute on function public.is_super_admin() to authenticated;

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
    where membership.tenant_id = p_tenant_id
      and membership.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_tenant_member(uuid) from public, anon;
grant execute on function public.is_tenant_member(uuid) to authenticated;

create or replace function public.create_tenant(
  p_name text,
  p_owner_email text
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

  insert into public.tenants (name, slug, created_by)
  values (v_name, v_slug, (select auth.uid()))
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

revoke all on function public.create_tenant(text, text) from public, anon;
grant execute on function public.create_tenant(text, text) to authenticated;

alter table public.tenants enable row level security;
alter table public.tenant_memberships enable row level security;
alter table public.super_admins enable row level security;

revoke all on table public.tenants from public, anon, authenticated;
revoke all on table public.tenant_memberships from public, anon, authenticated;
revoke all on table public.super_admins from public, anon, authenticated;
grant select on table public.tenants, public.tenant_memberships to authenticated;

create policy "Members and Super Admins can view tenants"
on public.tenants
for select
to authenticated
using (
  (select public.is_super_admin())
  or (select public.is_tenant_member(id))
);

create policy "Users can view their own tenant memberships"
on public.tenant_memberships
for select
to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_super_admin())
);

create or replace function public.prevent_parking_session_tenant_transfer()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not (select public.is_super_admin())
    and (
      new.tenant_id is distinct from old.tenant_id
      or new.created_by is distinct from old.created_by
    )
  then
    raise exception using
      errcode = '42501',
      message = 'Parking session ownership cannot be changed.';
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_parking_session_tenant_transfer
  on public.parking_sessions;

create trigger prevent_parking_session_tenant_transfer
before update on public.parking_sessions
for each row
execute function public.prevent_parking_session_tenant_transfer();

drop policy if exists "Users can view their own parking sessions"
  on public.parking_sessions;
drop policy if exists "Users can create their own parking sessions"
  on public.parking_sessions;
drop policy if exists "Users can update their own parking sessions"
  on public.parking_sessions;
drop policy if exists "Users can delete their own parking sessions"
  on public.parking_sessions;

create policy "Tenant members and Super Admins can view parking sessions"
on public.parking_sessions
for select
to authenticated
using (
  (select public.is_super_admin())
  or (select public.is_tenant_member(tenant_id))
);

create policy "Tenant members and Super Admins can create parking sessions"
on public.parking_sessions
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and (
    (select public.is_super_admin())
    or (select public.is_tenant_member(tenant_id))
  )
);

create policy "Tenant members and Super Admins can update parking sessions"
on public.parking_sessions
for update
to authenticated
using (
  (select public.is_super_admin())
  or (select public.is_tenant_member(tenant_id))
)
with check (
  (select public.is_super_admin())
  or (select public.is_tenant_member(tenant_id))
);

create policy "Tenant members and Super Admins can delete parking sessions"
on public.parking_sessions
for delete
to authenticated
using (
  (select public.is_super_admin())
  or (select public.is_tenant_member(tenant_id))
);

drop policy if exists "Users can read their own vehicle photos"
  on storage.objects;
drop policy if exists "Users can upload their own vehicle photos"
  on storage.objects;
drop policy if exists "Users can update their own vehicle photos"
  on storage.objects;
drop policy if exists "Users can delete their own vehicle photos"
  on storage.objects;

create policy "Tenant members and Super Admins can read vehicle photos"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'vehicle-photos'
  and exists (
    select 1
    from public.parking_sessions as session
    where session.id::text = (storage.foldername(name))[2]
      and session.created_by::text = (storage.foldername(name))[1]
      and (
        (select public.is_super_admin())
        or (select public.is_tenant_member(session.tenant_id))
      )
  )
);

create policy "Tenant members and Super Admins can upload vehicle photos"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'vehicle-photos'
  and exists (
    select 1
    from public.parking_sessions as session
    where session.id::text = (storage.foldername(name))[2]
      and session.created_by::text = (storage.foldername(name))[1]
      and (
        (select public.is_super_admin())
        or (select public.is_tenant_member(session.tenant_id))
      )
  )
);

create policy "Tenant members and Super Admins can update vehicle photos"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'vehicle-photos'
  and exists (
    select 1
    from public.parking_sessions as session
    where session.id::text = (storage.foldername(name))[2]
      and session.created_by::text = (storage.foldername(name))[1]
      and (
        (select public.is_super_admin())
        or (select public.is_tenant_member(session.tenant_id))
      )
  )
)
with check (
  bucket_id = 'vehicle-photos'
  and exists (
    select 1
    from public.parking_sessions as session
    where session.id::text = (storage.foldername(name))[2]
      and session.created_by::text = (storage.foldername(name))[1]
      and (
        (select public.is_super_admin())
        or (select public.is_tenant_member(session.tenant_id))
      )
  )
);

create policy "Tenant members and Super Admins can delete vehicle photos"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'vehicle-photos'
  and exists (
    select 1
    from public.parking_sessions as session
    where session.id::text = (storage.foldername(name))[2]
      and session.created_by::text = (storage.foldername(name))[1]
      and (
        (select public.is_super_admin())
        or (select public.is_tenant_member(session.tenant_id))
      )
  )
);

commit;
