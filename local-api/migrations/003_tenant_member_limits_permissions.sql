begin;

alter table core.tenants
  add column if not exists member_limit integer not null default 1;

alter table core.tenants
  drop constraint if exists tenants_member_limit_check;
alter table core.tenants
  add constraint tenants_member_limit_check
    check (member_limit between 1 and 50);

alter table core.tenant_memberships
  add column if not exists can_view_entries boolean not null default true,
  add column if not exists can_add_entries boolean not null default true,
  add column if not exists can_edit_entries boolean not null default true,
  add column if not exists can_delete_entries boolean not null default true;

alter table core.tenant_memberships
  alter column can_view_entries set default true,
  alter column can_add_entries set default false,
  alter column can_edit_entries set default false,
  alter column can_delete_entries set default false;

create index if not exists tenant_memberships_tenant_role_idx
  on core.tenant_memberships (tenant_id, role);

alter table core.parking_sessions
  add column if not exists photo_upload_pending boolean not null default false;

create table if not exists core.tenant_member_audit_events (
  id bigint generated always as identity primary key,
  tenant_id uuid not null references core.tenants(id) on delete cascade,
  actor_user_id uuid references core.users(id) on delete set null,
  subject_user_id uuid references core.users(id) on delete set null,
  action text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
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

create index if not exists tenant_member_audit_events_tenant_created_idx
  on core.tenant_member_audit_events (tenant_id, created_at desc, id desc);

commit;
