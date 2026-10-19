begin;

select plan(18);

insert into auth.users (id, email)
values
  ('44444444-4444-4444-4444-444444444444', 'owner@example.com'),
  ('55555555-5555-5555-5555-555555555555', 'member@example.com'),
  ('66666666-6666-6666-6666-666666666666', 'admin@example.com');

insert into public.tenants (id, name, slug, created_by, archived_at)
values
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    'Active workspace',
    'active-workspace',
    '44444444-4444-4444-4444-444444444444',
    null
  ),
  (
    'ffffffff-ffff-ffff-ffff-ffffffffffff',
    'Archived workspace',
    'archived-workspace',
    '44444444-4444-4444-4444-444444444444',
    now()
  );

insert into public.tenant_memberships (tenant_id, user_id, role)
values
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    '44444444-4444-4444-4444-444444444444',
    'owner'
  ),
  (
    'ffffffff-ffff-ffff-ffff-ffffffffffff',
    '44444444-4444-4444-4444-444444444444',
    'owner'
  );

insert into public.device_sessions (
  tenant_id,
  user_id,
  auth_session_id,
  installation_id
)
values (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  '44444444-4444-4444-4444-444444444444',
  '99999999-9999-9999-9999-999999999991',
  '99999999-9999-9999-9999-999999999992'
);

insert into public.parking_sessions (
  id,
  tenant_id,
  plate_number,
  entry_time,
  allowed_duration_value,
  allowed_duration_unit,
  expires_at,
  created_by
)
values (
  '77777777-7777-7777-7777-777777777777',
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  'ARCHIVE-1',
  '2026-01-01 10:00:00+00',
  30,
  'minutes',
  '2026-01-01 10:30:00+00',
  '44444444-4444-4444-4444-444444444444'
);

insert into public.super_admins (user_id)
values ('66666666-6666-6666-6666-666666666666');

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '44444444-4444-4444-4444-444444444444',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "44444444-4444-4444-4444-444444444444",
    "role": "authenticated",
    "session_id": "99999999-9999-9999-9999-999999999991",
    "app_metadata": {}
  }',
  true
);

select ok(
  public.is_tenant_member('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'),
  'active tenant owners retain membership access'
);
select ok(
  not public.is_tenant_member('ffffffff-ffff-ffff-ffff-ffffffffffff'),
  'archived tenants suspend member access'
);
select throws_ok(
  $$select public.update_tenant(
      'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
      'Unauthorized rename'
    )$$,
  '42501',
  null,
  'tenant members cannot manage tenants'
);

select set_config(
  'request.jwt.claim.sub',
  '66666666-6666-6666-6666-666666666666',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "66666666-6666-6666-6666-666666666666",
    "role": "authenticated",
    "session_id": "99999999-9999-9999-9999-999999999993",
    "app_metadata": {}
  }',
  true
);

select ok(public.is_super_admin(), 'the database-backed role is recognized');
select is(
  (select count(*) from public.tenants),
  2::bigint,
  'Super Admin can view active and archived tenants'
);
select lives_ok(
  $$select public.update_tenant(
      'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
      'Updated workspace'
    )$$,
  'Super Admin can rename a tenant'
);
select is(
  (
    select name
    from public.tenants
    where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
  ),
  'Updated workspace',
  'tenant rename is persisted'
);
select lives_ok(
  $$select public.archive_tenant(
      'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
    )$$,
  'Super Admin can archive a tenant'
);
select ok(
  (
    select archived_at is not null
    from public.tenants
    where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
  ),
  'archiving retains the tenant row'
);
select ok(
  not public.is_tenant_member('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'),
  'archived tenant membership is suspended'
);
select is(
  (
    select count(*)
    from public.parking_sessions
    where id = '77777777-7777-7777-7777-777777777777'
  ),
  1::bigint,
  'Super Admin can still access retained parking records'
);
select lives_ok(
  $$select public.restore_tenant(
      'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
    )$$,
  'Super Admin can restore an archived tenant'
);
select ok(
  public.is_tenant_member('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'),
  'restoring the tenant restores member access'
);
select lives_ok(
  $$select public.add_tenant_member(
      'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
      'member@example.com',
      'member'
    )$$,
  'Super Admin can add an existing Auth account'
);
select results_eq(
  $$select email, role
    from public.list_tenant_members(
      'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
    )
    order by email$$,
  $$values
      ('member@example.com'::text, 'member'::text),
      ('owner@example.com'::text, 'owner'::text)$$,
  'only Super Admin can retrieve tenant member details'
);
select lives_ok(
  $$select public.update_tenant_member_role(
      'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
      '55555555-5555-5555-5555-555555555555',
      'owner'
    )$$,
  'Super Admin can change a tenant role'
);
select lives_ok(
  $$select public.remove_tenant_member(
      'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
      '44444444-4444-4444-4444-444444444444'
    )$$,
  'Super Admin can remove a member while another owner remains'
);
select throws_ok(
  $$select public.update_tenant_member_role(
      'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
      '55555555-5555-5555-5555-555555555555',
      'member'
    )$$,
  '23514',
  null,
  'a tenant must retain at least one owner'
);

select * from finish();
rollback;
