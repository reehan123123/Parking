begin;

select plan(19);

insert into auth.users (id, email, raw_app_meta_data)
values
  (
    '44444444-4444-4444-4444-444444444444',
    'temporary-owner@example.com',
    '{
      "parking_temporary_password_reset_required": true,
      "parking_tenant_owner_onboarding_pending": true,
      "parking_tenant_owner_onboarding_request_id":
        "e6e5b36d-1890-4fc5-9a0c-47eeacb44119"
    }'::jsonb
  ),
  (
    '55555555-5555-5555-5555-555555555555',
    'regular-owner@example.com',
    '{}'::jsonb
  ),
  (
    '66666666-6666-6666-6666-666666666666',
    'admin@example.com',
    '{}'::jsonb
  );

insert into public.tenants (id, name, slug, created_by)
values
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    'Temporary owner workspace',
    'temporary-owner-workspace',
    '66666666-6666-6666-6666-666666666666'
  ),
  (
    'ffffffff-ffff-ffff-ffff-ffffffffffff',
    'Regular owner workspace',
    'regular-owner-workspace',
    '66666666-6666-6666-6666-666666666666'
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
    '55555555-5555-5555-5555-555555555555',
    'owner'
  );

insert into public.device_sessions (
  tenant_id,
  user_id,
  auth_session_id,
  installation_id
)
values (
  'ffffffff-ffff-ffff-ffff-ffffffffffff',
  '55555555-5555-5555-5555-555555555555',
  '99999999-9999-9999-9999-999999999991',
  '99999999-9999-9999-9999-999999999992'
);

insert into public.super_admins (user_id)
values
  ('44444444-4444-4444-4444-444444444444'),
  ('66666666-6666-6666-6666-666666666666');

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
    '77777777-7777-7777-7777-777777777777',
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    'TEMP-1',
    '2026-01-01 10:00:00+00',
    30,
    'minutes',
    '2026-01-01 10:30:00+00',
    '44444444-4444-4444-4444-444444444444'
  ),
  (
    '88888888-8888-8888-8888-888888888888',
    'ffffffff-ffff-ffff-ffff-ffffffffffff',
    'REG-1',
    '2026-01-01 10:00:00+00',
    30,
    'minutes',
    '2026-01-01 10:30:00+00',
    '55555555-5555-5555-5555-555555555555'
  );

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
    "app_metadata": {
      "parking_temporary_password_reset_required": true
    }
  }',
  true
);

select ok(
  public.is_temporary_password_reset_required(),
  'the server-set temporary-password flag is recognized'
);
select ok(
  not public.is_super_admin(),
  'the temporary-password flag suppresses Super Admin access'
);
select ok(
  not public.is_tenant_member('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'),
  'the temporary-password flag suppresses tenant membership access'
);
select is(
  (select count(*) from public.tenants),
  0::bigint,
  'a temporary-password user cannot read tenant rows'
);
select is(
  (select count(*) from public.tenant_memberships),
  0::bigint,
  'a temporary-password user cannot read membership rows'
);
select is(
  (select count(*) from public.parking_sessions),
  0::bigint,
  'a temporary-password user cannot read parking sessions'
);

select set_config(
  'request.jwt.claim.sub',
  '55555555-5555-5555-5555-555555555555',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "55555555-5555-5555-5555-555555555555",
    "role": "authenticated",
    "session_id": "99999999-9999-9999-9999-999999999991",
    "app_metadata": {}
  }',
  true
);

select ok(
  not public.is_temporary_password_reset_required(),
  'an account without the flag retains normal access'
);
select ok(
  public.is_tenant_member('ffffffff-ffff-ffff-ffff-ffffffffffff'),
  'an ordinary active member retains tenant access'
);
select is(
  (select count(*) from public.parking_sessions),
  1::bigint,
  'an ordinary member can still read its tenant parking sessions'
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
    "app_metadata": {}
  }',
  true
);
select ok(
  public.is_super_admin(),
  'an unflagged database-provisioned Super Admin retains access'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.tenant_owner_onboarding_state(text)',
    'EXECUTE'
  ),
  'anonymous callers cannot inspect Auth onboarding state'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.tenant_owner_onboarding_state(text)',
    'EXECUTE'
  ),
  'authenticated callers cannot inspect Auth onboarding state'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.tenant_owner_onboarding_state(text)',
    'EXECUTE'
  ),
  'the server-side service role can inspect Auth onboarding state'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.tenant_creation_requests',
    'SELECT'
  ),
  'authenticated clients cannot read the tenant request ledger directly'
);

set local role service_role;
select results_eq(
  $$
    select
      user_id::text,
      temporary_password_reset_required,
      tenant_owner_onboarding_pending,
      tenant_owner_onboarding_request_id::text
    from public.tenant_owner_onboarding_state('temporary-owner@example.com')
  $$,
  $$
    values (
      '44444444-4444-4444-4444-444444444444'::text,
      true,
      true,
      'e6e5b36d-1890-4fc5-9a0c-47eeacb44119'::text
    )
  $$,
  'the server lookup returns only the required onboarding state'
);

reset role;
set local role authenticated;
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
    "app_metadata": {}
  }',
  true
);

select lives_ok(
  $$
    select public.create_tenant_for_request(
      'Idempotent workspace',
      'regular-owner@example.com',
      'f18e7a04-8c19-4e11-b23c-104e0399d03e'
    )
  $$,
  'a Super Admin can create a tenant with a request ID'
);
select lives_ok(
  $$
    select public.create_tenant_for_request(
      'Idempotent workspace',
      'regular-owner@example.com',
      'f18e7a04-8c19-4e11-b23c-104e0399d03e'
    )
  $$,
  'a retry with the same request ID succeeds'
);
select is(
  (
    select count(*)
    from public.tenants
    where name = 'Idempotent workspace'
  ),
  1::bigint,
  'a repeated request does not create a duplicate tenant'
);
select throws_ok(
  $$
    select public.create_tenant_for_request(
      'Different workspace',
      'regular-owner@example.com',
      'f18e7a04-8c19-4e11-b23c-104e0399d03e'
    )
  $$,
  '22023',
  null,
  'a request ID cannot be reused with different tenant data'
);

select * from finish();
rollback;
