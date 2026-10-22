begin;

select no_plan();

insert into auth.users (id, email)
values
  ('71111111-1111-4111-8111-111111111111', 'push-owner@example.com'),
  ('72222222-2222-4222-8222-222222222222', 'push-viewer@example.com'),
  ('73333333-3333-4333-8333-333333333333', 'push-editor@example.com'),
  ('74444444-4444-4444-8444-444444444444', 'push-no-view@example.com'),
  ('75555555-5555-4555-8555-555555555555', 'push-other-owner@example.com'),
  ('76666666-6666-4666-8666-666666666666', 'push-cap@example.com');

insert into public.tenants (
  id,
  name,
  slug,
  created_by,
  valid_until,
  archived_at
)
values
  (
    'a1111111-1111-4111-8111-111111111111',
    'Push tenant one',
    'push-tenant-one',
    '71111111-1111-4111-8111-111111111111',
    '9999-12-31',
    null
  ),
  (
    'a2222222-2222-4222-8222-222222222222',
    'Push tenant two',
    'push-tenant-two',
    '75555555-5555-4555-8555-555555555555',
    '9999-12-31',
    null
  ),
  (
    'a3333333-3333-4333-8333-333333333333',
    'Archived push tenant',
    'archived-push-tenant',
    '75555555-5555-4555-8555-555555555555',
    '9999-12-31',
    '2026-10-25 00:00:00+00'
  ),
  (
    'a4444444-4444-4444-8444-444444444444',
    'Expired push tenant',
    'expired-push-tenant',
    '75555555-5555-4555-8555-555555555555',
    '2020-01-01',
    null
  );

insert into public.tenant_memberships (
  tenant_id,
  user_id,
  role,
  can_view_entries,
  can_edit_entries
)
values
  (
    'a1111111-1111-4111-8111-111111111111',
    '71111111-1111-4111-8111-111111111111',
    'owner',
    true,
    true
  ),
  (
    'a1111111-1111-4111-8111-111111111111',
    '72222222-2222-4222-8222-222222222222',
    'member',
    true,
    false
  ),
  (
    'a1111111-1111-4111-8111-111111111111',
    '73333333-3333-4333-8333-333333333333',
    'member',
    true,
    true
  ),
  (
    'a2222222-2222-4222-8222-222222222222',
    '75555555-5555-4555-8555-555555555555',
    'owner',
    true,
    true
  ),
  (
    'a2222222-2222-4222-8222-222222222222',
    '74444444-4444-4444-8444-444444444444',
    'member',
    false,
    false
  ),
  (
    'a3333333-3333-4333-8333-333333333333',
    '75555555-5555-4555-8555-555555555555',
    'owner',
    true,
    true
  ),
  (
    'a4444444-4444-4444-8444-444444444444',
    '75555555-5555-4555-8555-555555555555',
    'owner',
    true,
    true
  );

insert into public.device_sessions (
  tenant_id,
  user_id,
  auth_session_id,
  installation_id
)
values
  (
    'a1111111-1111-4111-8111-111111111111',
    '71111111-1111-4111-8111-111111111111',
    '81111111-1111-4111-8111-111111111111',
    '91111111-1111-4111-8111-111111111111'
  ),
  (
    'a1111111-1111-4111-8111-111111111111',
    '72222222-2222-4222-8222-222222222222',
    '82222222-2222-4222-8222-222222222222',
    '92222222-2222-4222-8222-222222222222'
  ),
  (
    'a1111111-1111-4111-8111-111111111111',
    '73333333-3333-4333-8333-333333333333',
    '83333333-3333-4333-8333-333333333333',
    '93333333-3333-4333-8333-333333333333'
  );

insert into public.parking_sessions (
  id,
  tenant_id,
  plate_number,
  entry_time,
  allowed_duration_value,
  allowed_duration_unit,
  expires_at,
  created_by,
  total_charge,
  paid_amount
)
values
  (
    'c1111111-1111-4111-8111-111111111111',
    'a1111111-1111-4111-8111-111111111111',
    'PUSH-90',
    '2026-10-25 10:00:00+00',
    10,
    'minutes',
    '2026-10-25 10:10:00+00',
    '71111111-1111-4111-8111-111111111111',
    100,
    25
  ),
  (
    'c3333333-3333-4333-8333-333333333333',
    'a1111111-1111-4111-8111-111111111111',
    'PUSH-PAID',
    '2026-10-25 09:00:00+00',
    1,
    'hours',
    '2026-10-25 10:00:00+00',
    '71111111-1111-4111-8111-111111111111',
    30,
    30
  ),
  (
    'c4444444-4444-4444-8444-444444444444',
    'a2222222-2222-4222-8222-222222222222',
    'PUSH-TENANT-ISOLATION',
    '2026-10-25 10:00:00+00',
    10,
    'minutes',
    '2026-10-25 10:10:00+00',
    '75555555-5555-4555-8555-555555555555',
    40,
    0
  ),
  (
    'c5555555-5555-4555-8555-555555555555',
    'a3333333-3333-4333-8333-333333333333',
    'PUSH-ARCHIVED',
    '2026-10-25 10:00:00+00',
    10,
    'minutes',
    '2026-10-25 10:10:00+00',
    '75555555-5555-4555-8555-555555555555',
    40,
    0
  ),
  (
    'c6666666-6666-4666-8666-666666666666',
    'a4444444-4444-4444-8444-444444444444',
    'PUSH-TENANT-EXPIRED',
    '2026-10-25 10:00:00+00',
    10,
    'minutes',
    '2026-10-25 10:10:00+00',
    '75555555-5555-4555-8555-555555555555',
    40,
    0
  );

insert into public.parking_push_subscriptions (
  user_id,
  endpoint,
  p256dh_key,
  auth_key
)
values
  (
    '72222222-2222-4222-8222-222222222222',
    'https://fcm.googleapis.com/fcm/send/push-viewer',
    repeat('A', 87),
    repeat('B', 22)
  ),
  (
    '73333333-3333-4333-8333-333333333333',
    'https://fcm.googleapis.com/fcm/send/push-editor',
    repeat('A', 87),
    repeat('B', 22)
  ),
  (
    '74444444-4444-4444-8444-444444444444',
    'https://fcm.googleapis.com/fcm/send/push-no-view',
    repeat('A', 87),
    repeat('B', 22)
  ),
  (
    '75555555-5555-4555-8555-555555555555',
    'https://fcm.googleapis.com/fcm/send/push-other-owner',
    repeat('A', 87),
    repeat('B', 22)
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '71111111-1111-4111-8111-111111111111',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "71111111-1111-4111-8111-111111111111",
    "role": "authenticated",
    "session_id": "81111111-1111-4111-8111-111111111111",
    "app_metadata": {}
  }',
  true
);

select lives_ok(
  $$select public.register_parking_push_subscription(
      'https://fcm.googleapis.com/fcm/send/push-rpc-owner',
      repeat('C', 87),
      repeat('D', 22),
      'en'
    )$$,
  'authenticated users can register an approved Web Push endpoint'
);
select is(
  (select count(*) from public.parking_push_subscriptions),
  1::bigint,
  'users can read only their own push subscriptions'
);
select throws_ok(
  $$insert into public.parking_push_subscriptions (
      user_id,
      endpoint,
      p256dh_key,
      auth_key
    )
    values (
      '71111111-1111-4111-8111-111111111111',
      'https://fcm.googleapis.com/fcm/send/direct-insert',
      repeat('A', 87),
      repeat('B', 22)
    )$$,
  '42501',
  null,
  'authenticated clients cannot write subscription rows directly'
);
select throws_ok(
  $$select public.register_parking_push_subscription(
      'https://example.com/push/endpoint',
      repeat('A', 87),
      repeat('B', 22),
      'en'
    )$$,
  '22023',
  null,
  'the registration RPC rejects non-provider endpoints'
);
select throws_ok(
  $$select public.register_parking_push_subscription(
      'https://fcm.googleapis.com/fcm/send/push-other-owner',
      repeat('A', 87),
      repeat('B', 22),
      'en'
    )$$,
  '42501',
  'PUSH_ENDPOINT_IN_USE',
  'a browser endpoint cannot be reassigned across accounts'
);

select set_config(
  'request.jwt.claim.sub',
  '76666666-6666-4666-8666-666666666666',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "76666666-6666-4666-8666-666666666666",
    "role": "authenticated",
    "session_id": "86666666-6666-4666-8666-666666666666",
    "app_metadata": {}
  }',
  true
);
select lives_ok(
  $sql$
    do $block$
    begin
      for endpoint_number in 1..10 loop
        perform public.register_parking_push_subscription(
          'https://fcm.googleapis.com/fcm/send/push-cap-'
            || endpoint_number::text,
          repeat('A', 87),
          repeat('B', 22),
          'en'
        );
      end loop;
    end;
    $block$;
  $sql$,
  'an account can register at most ten push endpoints'
);
select throws_ok(
  $$select public.register_parking_push_subscription(
      'https://fcm.googleapis.com/fcm/send/push-cap-eleven',
      repeat('A', 87),
      repeat('B', 22),
      'en'
    )$$,
  '23514',
  'PUSH_SUBSCRIPTION_LIMIT_REACHED',
  'the subscription cap is enforced on the server'
);

reset role;
create temporary table first_push_claims on commit drop as
select *
from public.claim_due_parking_notification_deliveries(
  '2026-10-25 10:09:30+00'
);

select is(
  (select count(*) from first_push_claims),
  4::bigint,
  'the 90-percent event is delivered only to View-eligible subscriptions'
);
select is(
  (
    select remaining_balance
    from first_push_claims as claimed
    join public.parking_push_subscriptions as subscription
      on subscription.id = claimed.subscription_id
    where claimed.session_id = 'c1111111-1111-4111-8111-111111111111'
      and subscription.user_id = '71111111-1111-4111-8111-111111111111'
  ),
  75::numeric,
  'the notification includes the current unpaid balance'
);
select ok(
  (
    select can_mark_paid
    from first_push_claims as claimed
    join public.parking_push_subscriptions as subscription
      on subscription.id = claimed.subscription_id
    where claimed.session_id = 'c1111111-1111-4111-8111-111111111111'
      and subscription.user_id = '71111111-1111-4111-8111-111111111111'
  ),
  'the service claim result retains owners edit permission data'
);
select ok(
  not (
    select can_mark_paid
    from first_push_claims as claimed
    join public.parking_push_subscriptions as subscription
      on subscription.id = claimed.subscription_id
    where claimed.session_id = 'c1111111-1111-4111-8111-111111111111'
      and subscription.user_id = '72222222-2222-4222-8222-222222222222'
  ),
  'the service claim result excludes edit access for View-only members'
);
select is(
  (
    select count(*)
    from public.parking_notification_events
    where session_id in (
      'c3333333-3333-4333-8333-333333333333',
      'c5555555-5555-4555-8555-555555555555',
      'c6666666-6666-4666-8666-666666666666'
    )
  ),
  0::bigint,
  'paid sessions and inactive tenants create no notification events'
);
select is(
  (
    select count(*)
    from public.claim_due_parking_notification_deliveries(
      '2026-10-25 10:09:30+00'
    )
  ),
  0::bigint,
  'repeated scheduler runs do not claim duplicate deliveries'
);

create temporary table expiry_push_claims on commit drop as
select *
from public.claim_due_parking_notification_deliveries(
  '2026-10-25 10:10:00+00'
);

select is(
  (select count(*) from expiry_push_claims),
  4::bigint,
  'expiry events are created once for unpaid sessions in active tenants'
);
select is(
  (
    select count(*)
    from public.parking_notification_deliveries as delivery
    join public.parking_notification_events as notification_event
      on notification_event.id = delivery.event_id
    join public.parking_push_subscriptions as subscription
      on subscription.id = delivery.subscription_id
    where notification_event.session_id = 'c4444444-4444-4444-8444-444444444444'
      and subscription.user_id = '74444444-4444-4444-8444-444444444444'
  ),
  0::bigint,
  'a member without View permission receives no tenant notifications'
);
select is(
  (select count(*) from public.parking_notification_events),
  4::bigint,
  'the scheduler records one 90-percent or expiry event per session and type'
);

update public.parking_notification_deliveries as delivery
set
  status = 'sent',
  delivered_at = '2026-10-25 10:09:30+00'
from public.parking_notification_events as notification_event
where notification_event.id = delivery.event_id
  and notification_event.notification_type = 'ninety_percent'
  and delivery.status = 'sending';

update public.parking_notification_deliveries as delivery
set
  status = 'sent',
  delivered_at = '2026-10-25 10:10:00+00'
from public.parking_notification_events as notification_event
where notification_event.id = delivery.event_id
  and notification_event.notification_type = 'expired'
  and delivery.status = 'sending';

update public.parking_notification_deliveries as delivery
set
  status = 'failed',
  error_code = 'push_http_503'
from public.parking_notification_events as notification_event,
     public.parking_push_subscriptions as subscription
where notification_event.id = delivery.event_id
  and subscription.id = delivery.subscription_id
  and notification_event.session_id = 'c4444444-4444-4444-8444-444444444444'
  and notification_event.notification_type = 'expired'
  and subscription.user_id = '75555555-5555-4555-8555-555555555555';

select is(
  (
    select count(*)
    from public.claim_due_parking_notification_deliveries(
      '2026-10-25 10:14:59+00'
    )
  ),
  0::bigint,
  'expiry reminders are not repeated before five minutes have elapsed'
);

create temporary table repeated_expiry_push_claims on commit drop as
select *
from public.claim_due_parking_notification_deliveries(
  '2026-10-25 10:15:00+00'
);

select is(
  (select count(*) from repeated_expiry_push_claims),
  4::bigint,
  'sent and failed expiry deliveries are retried after five minutes'
);
select is(
  (
    select count(*)
    from repeated_expiry_push_claims
    where notification_type = 'ninety_percent'
  ),
  0::bigint,
  'the 90-percent reminder is not repeated'
);
select is(
  (
    select count(*)
    from public.parking_notification_events
  ),
  4::bigint,
  'repeated reminders reuse the original event rows'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '72222222-2222-4222-8222-222222222222',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "72222222-2222-4222-8222-222222222222",
    "role": "authenticated",
    "session_id": "82222222-2222-4222-8222-222222222222",
    "app_metadata": {}
  }',
  true
);
select throws_ok(
  $$select public.mark_parking_session_fully_paid(
      'c1111111-1111-4111-8111-111111111111'
    )$$,
  '42501',
  null,
  'View-only members cannot mark parking sessions fully paid'
);

select set_config(
  'request.jwt.claim.sub',
  '73333333-3333-4333-8333-333333333333',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "73333333-3333-4333-8333-333333333333",
    "role": "authenticated",
    "session_id": "83333333-3333-4333-8333-333333333333",
    "app_metadata": {}
  }',
  true
);
select is(
  public.mark_parking_session_fully_paid('c1111111-1111-4111-8111-111111111111'),
  true,
  'Edit members can mark the parking session fully paid'
);
select is(
  (
    select paid_amount
    from public.parking_sessions
    where id = 'c1111111-1111-4111-8111-111111111111'
  ),
  100::numeric,
  'the authorized payment action records the full charge'
);
reset role;
select is(
  (
    select count(*)
    from public.parking_notification_deliveries as delivery
    join public.parking_notification_events as notification_event
      on notification_event.id = delivery.event_id
    where notification_event.session_id = 'c1111111-1111-4111-8111-111111111111'
      and delivery.status = 'skipped'
      and delivery.error_code = 'parking_session_marked_paid'
  ),
  3::bigint,
  'marking paid skips queued expiry notifications without changing sent history'
);
select is(
  (
    select count(*)
    from public.claim_due_parking_notification_deliveries(
      '2026-10-25 10:20:00+00'
    ) as claimed
    where claimed.session_id = 'c1111111-1111-4111-8111-111111111111'
  ),
  0::bigint,
  'fully paid sessions receive no subsequent expiry reminders'
);

reset role;
select * from finish();
rollback;
