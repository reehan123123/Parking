begin;

select plan(17);

insert into auth.users (id, email)
values
  ('11111111-1111-1111-1111-111111111111', 'owner@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'other@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'admin@example.com');

insert into public.tenants (id, name, slug, created_by)
values
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Owner workspace',
    'owner-workspace',
    '11111111-1111-1111-1111-111111111111'
  ),
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Other workspace',
    'other-workspace',
    '22222222-2222-2222-2222-222222222222'
  );

insert into public.tenant_memberships (tenant_id, user_id, role)
values
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '11111111-1111-1111-1111-111111111111',
    'owner'
  ),
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '22222222-2222-2222-2222-222222222222',
    'owner'
  );

insert into public.device_sessions (
  tenant_id,
  user_id,
  auth_session_id,
  installation_id
)
values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '11111111-1111-1111-1111-111111111111',
  '99999999-9999-9999-9999-999999999991',
  '99999999-9999-9999-9999-999999999992'
);

insert into public.super_admins (user_id)
values ('33333333-3333-3333-3333-333333333333');

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
values
  (
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'OWNER-1',
    '2026-01-01 10:00:00+00',
    30,
    'minutes',
    '2026-01-01 10:30:00+00',
    '11111111-1111-1111-1111-111111111111'
  ),
  (
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'OTHER-1',
    '2026-01-01 11:00:00+00',
    1,
    'days',
    '2026-01-02 11:00:00+00',
    '22222222-2222-2222-2222-222222222222'
  );

set local role anon;

select throws_ok(
  $$select * from public.parking_sessions$$,
  '42501',
  null,
  'anonymous users cannot read parking sessions'
);

select throws_ok(
  $$insert into public.parking_sessions (
      tenant_id,
      plate_number,
      entry_time,
      allowed_duration_value,
      allowed_duration_unit,
      expires_at,
      created_by
    )
    values (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'ANON-1',
      now(),
      1,
      'hours',
      now() + interval '1 hour',
      '11111111-1111-1111-1111-111111111111'
    )$$,
  '42501',
  null,
  'anonymous users cannot create parking sessions'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '11111111-1111-1111-1111-111111111111',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "11111111-1111-1111-1111-111111111111",
    "role": "authenticated",
    "session_id": "99999999-9999-9999-9999-999999999991",
    "app_metadata": {}
  }',
  true
);

select results_eq(
  $$select plate_number
    from public.parking_sessions
    order by plate_number$$,
  $$values ('OWNER-1'::text)$$,
  'a tenant owner can read only their own tenant sessions'
);

select is(
  (
    select count(*)
    from public.parking_sessions
    where tenant_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
  ),
  0::bigint,
  'a tenant owner cannot see another tenants sessions'
);

select ok(
  not public.is_super_admin(),
  'a tenant owner is not a Super Admin'
);

select lives_ok(
  $$insert into public.parking_sessions (
      tenant_id,
      plate_number,
      entry_time,
      allowed_duration_value,
      allowed_duration_unit,
      expires_at,
      created_by
    )
    values (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'OWNER-2',
      now(),
      1,
      'hours',
      now() + interval '1 hour',
      '11111111-1111-1111-1111-111111111111'
    )$$,
  'a tenant owner can create a session in their workspace'
);

select throws_ok(
  $$insert into public.parking_sessions (
      tenant_id,
      plate_number,
      entry_time,
      allowed_duration_value,
      allowed_duration_unit,
      expires_at,
      created_by
    )
    values (
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'OTHER-2',
      now(),
      1,
      'hours',
      now() + interval '1 hour',
      '11111111-1111-1111-1111-111111111111'
    )$$,
  '42501',
  null,
  'a tenant owner cannot create a session in another workspace'
);

select throws_ok(
  $$insert into public.parking_sessions (
      tenant_id,
      plate_number,
      entry_time,
      allowed_duration_value,
      allowed_duration_unit,
      expires_at,
      created_by
    )
    values (
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'OTHER-3',
      now(),
      1,
      'hours',
      now() + interval '1 hour',
      '22222222-2222-2222-2222-222222222222'
    )$$,
  '42501',
  null,
  'a tenant owner cannot create a session for another user'
);

select throws_ok(
  $$update public.parking_sessions
    set tenant_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
    where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'$$,
  '42501',
  null,
  'a tenant owner cannot transfer a session to another tenant'
);

select throws_ok(
  $$insert into public.super_admins (user_id)
    values ('11111111-1111-1111-1111-111111111111')$$,
  '42501',
  null,
  'a tenant owner cannot grant themselves Super Admin'
);

select throws_ok(
  $$select public.create_tenant('Unauthorized', 'owner@example.com')$$,
  '42501',
  null,
  'a tenant owner cannot create platform tenants'
);

select lives_ok(
  $$delete from public.parking_sessions
    where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'$$,
  'a tenant owner can delete a session in their workspace'
);

select is(
  (
    select count(*)
    from public.parking_sessions
    where id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
  ),
  0::bigint,
  'the other tenants session remains invisible'
);

select set_config(
  'request.jwt.claim.sub',
  '33333333-3333-3333-3333-333333333333',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "33333333-3333-3333-3333-333333333333",
    "role": "authenticated",
    "session_id": "99999999-9999-9999-9999-999999999993",
    "app_metadata": {}
  }',
  true
);

select ok(public.is_super_admin(), 'the provisioned Super Admin is recognized');

select results_eq(
  $$select plate_number
    from public.parking_sessions
    order by plate_number$$,
  $$values ('OTHER-1'::text), ('OWNER-2'::text)$$,
  'a Super Admin can read sessions across tenants'
);

select lives_ok(
  $$select public.create_tenant('Airport Parking', 'other@example.com')$$,
  'a Super Admin can create a tenant for an existing Auth account'
);

select is(
  (
    select count(*)
    from public.tenant_memberships
    where user_id = '22222222-2222-2222-2222-222222222222'
  ),
  2::bigint,
  'tenant creation assigns the existing owner to the new tenant'
);

select * from finish();
rollback;
