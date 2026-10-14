begin;

select plan(9);

insert into auth.users (id, email)
values
  ('11111111-1111-1111-1111-111111111111', 'owner@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'other@example.com');

insert into public.parking_sessions (
  id,
  plate_number,
  entry_time,
  allowed_duration_value,
  allowed_duration_unit,
  expires_at,
  created_by
)
values
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'OWNER-1',
    '2026-01-01 10:00:00+00',
    30,
    'minutes',
    '2026-01-01 10:30:00+00',
    '11111111-1111-1111-1111-111111111111'
  ),
  (
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
      plate_number,
      entry_time,
      allowed_duration_value,
      allowed_duration_unit,
      expires_at,
      created_by
    )
    values (
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

select results_eq(
  $$select plate_number
    from public.parking_sessions
    order by plate_number$$,
  $$values ('OWNER-1')$$,
  'an owner can read only their own parking session'
);

select is(
  (
    select count(*)
    from public.parking_sessions
    where created_by = '22222222-2222-2222-2222-222222222222'
  ),
  0::bigint,
  'an owner cannot see another users parking session'
);

select lives_ok(
  $$insert into public.parking_sessions (
      plate_number,
      entry_time,
      allowed_duration_value,
      allowed_duration_unit,
      expires_at,
      created_by
    )
    values (
      'OWNER-2',
      now(),
      1,
      'hours',
      now() + interval '1 hour',
      '11111111-1111-1111-1111-111111111111'
    )$$,
  'an owner can create their own parking session'
);

select throws_ok(
  $$insert into public.parking_sessions (
      plate_number,
      entry_time,
      allowed_duration_value,
      allowed_duration_unit,
      expires_at,
      created_by
    )
    values (
      'OTHER-2',
      now(),
      1,
      'hours',
      now() + interval '1 hour',
      '22222222-2222-2222-2222-222222222222'
    )$$,
  '42501',
  null,
  'an owner cannot create a session for another user'
);

select throws_ok(
  $$update public.parking_sessions
    set created_by = '22222222-2222-2222-2222-222222222222'
    where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  '42501',
  null,
  'an owner cannot transfer session ownership'
);

select lives_ok(
  $$delete from public.parking_sessions
    where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  'an owner can delete their own parking session'
);

select is(
  (
    select count(*)
    from public.parking_sessions
    where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
  ),
  0::bigint,
  'the other users session remains invisible'
);

select * from finish();
rollback;
