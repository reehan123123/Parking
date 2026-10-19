begin;

select plan(41);

insert into auth.users (id, email)
values
  ('10000000-0000-4000-8000-000000000001', 'device-owner@example.com'),
  ('20000000-0000-4000-8000-000000000001', 'device-admin@example.com');

insert into public.tenants (id, name, slug, created_by, valid_until)
values
  (
    '30000000-0000-4000-8000-000000000001',
    'Device tenant one',
    'device-tenant-one',
    '20000000-0000-4000-8000-000000000001',
    (now() at time zone 'Asia/Kolkata')::date + 3650
  ),
  (
    '30000000-0000-4000-8000-000000000002',
    'Device tenant two',
    'device-tenant-two',
    '20000000-0000-4000-8000-000000000001',
    (now() at time zone 'Asia/Kolkata')::date + 3650
  ),
  (
    '30000000-0000-4000-8000-000000000003',
    'Device tenant three',
    'device-tenant-three',
    '20000000-0000-4000-8000-000000000001',
    (now() at time zone 'Asia/Kolkata')::date + 3650
  );

insert into public.tenant_memberships (tenant_id, user_id, role)
values
  (
    '30000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    'owner'
  ),
  (
    '30000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    'member'
  );

insert into public.super_admins (user_id)
values ('20000000-0000-4000-8000-000000000001');

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
  '60000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  'DEVICE-1',
  now(),
  1,
  'hours',
  now() + interval '1 hour',
  '10000000-0000-4000-8000-000000000001'
);

select is(
  (select platform_device_limit from public.device_session_settings),
  1,
  'the initial platform device limit is one'
);
select ok(
  exists (
    select 1
    from public.tenant_device_session_policies
    where tenant_id = '30000000-0000-4000-8000-000000000001'
      and device_limit is null
  ),
  'new tenants inherit the platform default without an explicit override'
);
select is(
  (select stale_session_days from public.device_session_settings),
  30,
  'the initial stale-session expiry is thirty days'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "10000000-0000-4000-8000-000000000001",
    "role": "authenticated",
    "session_id": "40000000-0000-4000-8000-000000000001",
    "app_metadata": {}
  }',
  true
);

select is(
  public.register_device_session(
    '30000000-0000-4000-8000-000000000001',
    '50000000-0000-4000-8000-000000000001'
  ) ->> 'accepted',
  'true',
  'the first installation registers under the default limit'
);
select is(
  (select count(*) from public.parking_sessions),
  1::bigint,
  'a registered session can read its tenant parking data'
);

select set_config(
  'request.jwt.claims',
  '{
    "sub": "10000000-0000-4000-8000-000000000001",
    "role": "authenticated",
    "session_id": "40000000-0000-4000-8000-000000000002",
    "app_metadata": {}
  }',
  true
);
select is(
  public.register_device_session(
    '30000000-0000-4000-8000-000000000001',
    '50000000-0000-4000-8000-000000000002'
  ) ->> 'reason',
  'device_limit_reached',
  'a second installation is rejected at the default limit'
);
select is(
  (select count(*) from public.parking_sessions),
  0::bigint,
  'an unregistered session cannot read tenant parking data'
);

select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "20000000-0000-4000-8000-000000000001",
    "role": "authenticated",
    "session_id": "40000000-0000-4000-8000-000000000010",
    "app_metadata": {}
  }',
  true
);
select lives_ok(
  $$select public.set_tenant_device_session_limit(
      '30000000-0000-4000-8000-000000000001',
      3
    )$$,
  'a Super Admin can set a tenant limit of three'
);
select lives_ok(
  $$select public.set_tenant_device_session_limit(
      '30000000-0000-4000-8000-000000000002',
      2
    )$$,
  'a Super Admin can set an independent second tenant limit'
);
select is(
  (
    public.get_tenant_device_session_policy(
      '30000000-0000-4000-8000-000000000003'
    ) ->> 'effective_device_limit'
  )::integer,
  1,
  'a tenant without an override uses the platform default'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "10000000-0000-4000-8000-000000000001",
    "role": "authenticated",
    "session_id": "40000000-0000-4000-8000-000000000002",
    "app_metadata": {}
  }',
  true
);
select is(
  public.register_device_session(
    '30000000-0000-4000-8000-000000000001',
    '50000000-0000-4000-8000-000000000002'
  ) ->> 'accepted',
  'true',
  'a second installation is admitted after the tenant limit is raised'
);
select is(
  public.register_device_session(
    '30000000-0000-4000-8000-000000000001',
    '50000000-0000-4000-8000-000000000002'
  ) ->> 'active_device_count',
  '2',
  'registering the same Auth session again is idempotent'
);

select set_config(
  'request.jwt.claims',
  '{
    "sub": "10000000-0000-4000-8000-000000000001",
    "role": "authenticated",
    "session_id": "40000000-0000-4000-8000-000000000003",
    "app_metadata": {}
  }',
  true
);
select is(
  public.register_device_session(
    '30000000-0000-4000-8000-000000000001',
    '50000000-0000-4000-8000-000000000002'
  ) ->> 'accepted',
  'true',
  'two Auth sessions on one installation consume one device slot'
);
select is(
  public.register_device_session(
    '30000000-0000-4000-8000-000000000001',
    '50000000-0000-4000-8000-000000000003'
  ) ->> 'active_device_count',
  '3',
  'a third installation is admitted at the configured limit'
);
select is(
  public.register_device_session(
    '30000000-0000-4000-8000-000000000001',
    '50000000-0000-4000-8000-000000000004'
  ) ->> 'reason',
  'device_limit_reached',
  'a fourth installation is rejected at the configured limit of three'
);
select is(
  public.register_device_session(
    '30000000-0000-4000-8000-000000000001',
    '50000000-0000-4000-8000-000000000004'
  ) ->> 'effective_limit',
  '3',
  'the rejection reports the effective tenant limit'
);

select set_config(
  'request.jwt.claims',
  '{
    "sub": "10000000-0000-4000-8000-000000000001",
    "role": "authenticated",
    "session_id": "40000000-0000-4000-8000-000000000002",
    "app_metadata": {}
  }',
  true
);
select is(
  public.register_device_session(
    '30000000-0000-4000-8000-000000000002',
    '50000000-0000-4000-8000-000000000002'
  ) ->> 'accepted',
  'true',
  'the same Auth identity can register independently in another tenant'
);
select is(
  public.register_device_session(
    '30000000-0000-4000-8000-000000000002',
    '50000000-0000-4000-8000-000000000002'
  ) ->> 'active_device_count',
  '1',
  'device usage in one tenant does not consume another tenant allowance'
);

select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "20000000-0000-4000-8000-000000000001",
    "role": "authenticated",
    "session_id": "40000000-0000-4000-8000-000000000010",
    "app_metadata": {}
  }',
  true
);
select lives_ok(
  $$select public.set_tenant_member_device_session_limit(
      '30000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000001',
      2
    )$$,
  'a Super Admin can set an account override'
);
select results_eq(
  $$
    select effective_device_limit, policy_source
    from public.list_tenant_member_device_session_policies(
      '30000000-0000-4000-8000-000000000001'
    )
    where user_id = '10000000-0000-4000-8000-000000000001'
  $$,
  $$values (2, 'account_override'::text)$$,
  'the account override takes precedence over the tenant limit'
);
select lives_ok(
  $$select public.set_platform_device_session_policy(4, 30)$$,
  'a Super Admin can change the platform default'
);
select is(
  (
    public.get_tenant_device_session_policy(
      '30000000-0000-4000-8000-000000000001'
    ) ->> 'effective_device_limit'
  )::integer,
  2,
  'changing the platform default does not overwrite an account override'
);
select is(
  (
    public.get_tenant_device_session_policy(
      '30000000-0000-4000-8000-000000000003'
    ) ->> 'effective_device_limit'
  )::integer,
  4,
  'tenants without overrides inherit the updated platform default'
);
select is(
  (
    public.get_tenant_device_session_policy(
      '30000000-0000-4000-8000-000000000002'
    ) ->> 'effective_device_limit'
  )::integer,
  2,
  'the second tenant keeps its explicit policy after a platform change'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "10000000-0000-4000-8000-000000000001",
    "role": "authenticated",
    "session_id": "40000000-0000-4000-8000-000000000001",
    "app_metadata": {}
  }',
  true
);
select is(
  public.register_device_session(
    '30000000-0000-4000-8000-000000000001',
    '50000000-0000-4000-8000-000000000001'
  ) ->> 'accepted',
  'true',
  'an existing registered session remains valid after a lower override'
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "10000000-0000-4000-8000-000000000001",
    "role": "authenticated",
    "session_id": "40000000-0000-4000-8000-000000000007",
    "app_metadata": {}
  }',
  true
);
select is(
  public.register_device_session(
    '30000000-0000-4000-8000-000000000001',
    '50000000-0000-4000-8000-000000000007'
  ) ->> 'effective_limit',
  '2',
  'new registrations use the account override after precedence is applied'
);
select throws_ok(
  $$select public.set_tenant_device_session_limit(
      '30000000-0000-4000-8000-000000000001',
      5
    )$$,
  '42501',
  null,
  'ordinary users cannot change tenant policies'
);
select throws_ok(
  $$insert into public.device_sessions (
      tenant_id,
      user_id,
      auth_session_id,
      installation_id
    )
    values (
      '30000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000007',
      '50000000-0000-4000-8000-000000000007'
    )$$,
  '42501',
  null,
  'ordinary users cannot register sessions through direct table writes'
);
select throws_ok(
  $$select * from public.device_session_settings$$,
  '42501',
  null,
  'ordinary users cannot read platform policy tables directly'
);
select throws_ok(
  $$select * from public.device_sessions$$,
  '42501',
  null,
  'ordinary users cannot read device-session records directly'
);
select throws_ok(
  $$select public.revoke_tenant_device_installation(
      '30000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000001',
      '50000000-0000-4000-8000-000000000001'
    )$$,
  '42501',
  null,
  'ordinary users cannot invoke administrative session revocation'
);

select is(
  public.revoke_my_device_installation(
    '30000000-0000-4000-8000-000000000001',
    '50000000-0000-4000-8000-000000000001'
  ),
  1,
  'a user can revoke their own installation in one tenant'
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "10000000-0000-4000-8000-000000000001",
    "role": "authenticated",
    "session_id": "40000000-0000-4000-8000-000000000001",
    "app_metadata": {}
  }',
  true
);
select ok(
  not public.is_tenant_member('30000000-0000-4000-8000-000000000001'),
  'a revoked Auth session immediately loses tenant RLS access'
);
select is(
  public.register_device_session(
    '30000000-0000-4000-8000-000000000001',
    '50000000-0000-4000-8000-000000000001'
  ) ->> 'reason',
  'session_ended',
  'a revoked Auth session cannot register again'
);

reset role;
set local role supabase_auth_admin;
select is(
  (
    public.custom_access_token_hook(
      '{
        "user_id": "10000000-0000-4000-8000-000000000001",
        "authentication_method": "token_refresh",
        "claims": {
          "session_id": "40000000-0000-4000-8000-000000000001",
          "app_metadata": {}
        }
      }'::jsonb
    ) -> 'error' ->> 'http_code'
  ),
  '403',
  'the Auth hook rejects refresh of a revoked session'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "10000000-0000-4000-8000-000000000001",
    "role": "authenticated",
    "session_id": "40000000-0000-4000-8000-000000000002",
    "app_metadata": {}
  }',
  true
);
select lives_ok(
  $$select public.release_current_device_sessions()$$,
  'logout releases the current Auth session in all tenant registrations'
);
select is(
  (
    select count(*)
    from public.list_my_device_sessions()
    where tenant_id = '30000000-0000-4000-8000-000000000002'
  ),
  0::bigint,
  'logout frees the session slot independently in the second tenant'
);

select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "20000000-0000-4000-8000-000000000001",
    "role": "authenticated",
    "session_id": "40000000-0000-4000-8000-000000000010",
    "app_metadata": {}
  }',
  true
);
select is(
  public.revoke_tenant_device_installation(
    '30000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '50000000-0000-4000-8000-000000000003'
  ),
  1,
  'a Super Admin can revoke a selected member installation'
);
select ok(
  exists (
    select 1
    from public.list_device_session_audit_events() as audit_event
    where audit_event.action = 'session_revoked_by_admin'
  ),
  'Super Admin revocations are available in the audit trail'
);

reset role;
insert into public.device_sessions (
  tenant_id,
  user_id,
  auth_session_id,
  installation_id,
  last_activity_at
)
values (
  '30000000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000008',
  '50000000-0000-4000-8000-000000000008',
  now() - interval '31 days'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "10000000-0000-4000-8000-000000000001",
    "role": "authenticated",
    "session_id": "40000000-0000-4000-8000-000000000009",
    "app_metadata": {}
  }',
  true
);
select is(
  (
    select count(*)
    from public.list_my_device_sessions()
    where installation_id = '50000000-0000-4000-8000-000000000008'
  ),
  0::bigint,
  'stale installations are excluded after the configured expiry'
);
reset role;
select is(
  (
    select status
    from public.device_sessions
    where auth_session_id = '40000000-0000-4000-8000-000000000008'
  ),
  'expired',
  'stale session cleanup records the expired state'
);

select * from finish();
rollback;
