begin;

create schema if not exists core;

create table if not exists core.users (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  password_hash text not null,
  requires_password_change boolean not null default false,
  created_at timestamptz not null default now(),
  constraint users_email_check check (
    char_length(btrim(email)) between 3 and 254
    and position('@' in email) > 1
  ),
  constraint users_password_hash_check check (
    char_length(password_hash) between 1 and 256
  )
);

create unique index if not exists users_email_lower_unique
  on core.users (lower(email));

create table if not exists core.auth_sessions (
  token_hash text primary key,
  user_id uuid not null references core.users(id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint auth_sessions_token_hash_check
    check (token_hash ~ '^[0-9a-f]{64}$')
);

create index if not exists auth_sessions_expiry_idx
  on core.auth_sessions (expires_at);

create table if not exists core.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_by uuid references core.users(id) on delete set null,
  created_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint tenants_name_check
    check (char_length(btrim(name)) between 1 and 120),
  constraint tenants_slug_check
    check (char_length(btrim(slug)) between 1 and 80)
);

create table if not exists core.tenant_memberships (
  tenant_id uuid not null references core.tenants(id) on delete cascade,
  user_id uuid not null references core.users(id) on delete cascade,
  role text not null,
  created_at timestamptz not null default now(),
  constraint tenant_memberships_role_check
    check (role in ('owner', 'member')),
  primary key (tenant_id, user_id)
);

create index if not exists tenant_memberships_user_id_idx
  on core.tenant_memberships (user_id, tenant_id);

create table if not exists core.super_admins (
  user_id uuid primary key references core.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists core.parking_sessions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references core.tenants(id) on delete restrict,
  plate_number text not null,
  photo_path text,
  entry_time timestamptz not null,
  allowed_duration_value integer not null,
  allowed_duration_unit text not null,
  expires_at timestamptz not null,
  created_by uuid not null references core.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint parking_sessions_plate_number_check
    check (char_length(btrim(plate_number)) between 1 and 64),
  constraint parking_sessions_duration_value_check
    check (allowed_duration_value > 0),
  constraint parking_sessions_duration_unit_check
    check (
      allowed_duration_unit in ('minutes', 'hours', 'days', 'months')
    ),
  constraint parking_sessions_expiry_check check (expires_at > entry_time)
);

create index if not exists parking_sessions_tenant_entry_idx
  on core.parking_sessions (tenant_id, entry_time desc, id desc);

create index if not exists parking_sessions_tenant_expires_idx
  on core.parking_sessions (tenant_id, expires_at);

create table if not exists core.tenant_creation_requests (
  request_id uuid primary key,
  requested_by uuid not null references core.users(id) on delete cascade,
  tenant_id uuid not null references core.tenants(id) on delete cascade,
  owner_user_id uuid not null references core.users(id) on delete cascade,
  tenant_name text not null,
  owner_created boolean not null,
  created_at timestamptz not null default now(),
  constraint tenant_creation_requests_name_check
    check (char_length(btrim(tenant_name)) between 1 and 120)
);

create or replace function core.set_updated_at()
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
  on core.parking_sessions;

create trigger set_parking_session_updated_at
before update on core.parking_sessions
for each row
execute function core.set_updated_at();

commit;
