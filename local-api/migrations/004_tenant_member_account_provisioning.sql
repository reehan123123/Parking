begin;

create table if not exists core.tenant_member_creation_requests (
  request_id uuid primary key,
  requested_by uuid not null references core.users(id) on delete cascade,
  tenant_id uuid not null references core.tenants(id) on delete cascade,
  member_user_id uuid not null references core.users(id) on delete cascade,
  email text not null,
  created_at timestamptz not null default now(),
  constraint tenant_member_creation_requests_email_check
    check (
      char_length(btrim(email)) between 3 and 254
      and position('@' in email) > 1
    )
);

create index if not exists tenant_member_creation_requests_tenant_member_idx
  on core.tenant_member_creation_requests (tenant_id, member_user_id);

commit;
