begin;

select plan(11);

insert into auth.users (id, email)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'maintenance-member@example.com'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'maintenance-admin@example.com');

insert into public.super_admins (user_id)
values ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');

update public.platform_maintenance_settings
set maintenance_until = pg_catalog.statement_timestamp() - interval '1 minute'
where singleton is true;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    "role": "authenticated",
    "app_metadata": {}
  }',
  true
);

select is(
  (
    select caller_is_super_admin
    from public.get_platform_maintenance_mode()
  ),
  false,
  'ordinary users are not recognized as Super Admins'
);
select is(
  (
    select maintenance_active
    from public.get_platform_maintenance_mode()
  ),
  false,
  'expired maintenance is inactive without a scheduled cleanup job'
);
select throws_ok(
  $$select * from public.platform_maintenance_settings$$,
  '42501',
  null,
  'authenticated users cannot read the settings table directly'
);
select throws_ok(
  $$select * from public.set_platform_maintenance_mode(null)$$,
  '42501',
  null,
  'ordinary users cannot change maintenance mode'
);

select set_config(
  'request.jwt.claim.sub',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
    "role": "authenticated",
    "app_metadata": {}
  }',
  true
);

select ok(public.is_super_admin(), 'the database-backed Super Admin is recognized');
select is(
  (
    select maintenance_active
    from public.set_platform_maintenance_mode(
      pg_catalog.statement_timestamp() + interval '10 minutes'
    )
  ),
  true,
  'Super Admins can enable maintenance until a future time'
);

select set_config(
  'request.jwt.claim.sub',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    "role": "authenticated",
    "app_metadata": {}
  }',
  true
);
select is(
  (
    select maintenance_active
    from public.get_platform_maintenance_mode()
  ),
  true,
  'all authenticated users can read the active global state'
);

select set_config(
  'request.jwt.claim.sub',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
    "role": "authenticated",
    "app_metadata": {}
  }',
  true
);
select is(
  (
    select maintenance_active
    from public.set_platform_maintenance_mode(null)
  ),
  false,
  'Super Admins can disable maintenance immediately'
);
select is(
  (
    select maintenance_active
    from public.get_platform_maintenance_mode()
  ),
  false,
  'disabled maintenance is inactive for subsequent readers'
);
select throws_ok(
  $$select * from public.set_platform_maintenance_mode(
      pg_catalog.statement_timestamp() - interval '1 minute'
    )$$,
  '22023',
  null,
  'Super Admins cannot set an end time in the past'
);

reset role;
set local role anon;
select throws_ok(
  $$select * from public.get_platform_maintenance_mode()$$,
  '42501',
  null,
  'anonymous users cannot read authenticated maintenance status'
);

select * from finish();
rollback;
