begin;

select no_plan();

insert into auth.users (id, email)
values
  ('71111111-1111-4111-8111-111111111111', 'notification-owner@example.com'),
  ('72222222-2222-4222-8222-222222222222', 'notification-viewer@example.com'),
  ('73333333-3333-4333-8333-333333333333', 'notification-editor@example.com'),
  ('74444444-4444-4444-8444-444444444444', 'notification-no-view@example.com'),
  ('75555555-5555-4555-8555-555555555555', 'notification-other-owner@example.com');

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
    'Notification tenant one',
    'notification-tenant-one',
    '71111111-1111-4111-8111-111111111111',
    '9999-12-31',
    null
  ),
  (
    'a2222222-2222-4222-8222-222222222222',
    'Notification tenant two',
    'notification-tenant-two',
    '75555555-5555-4555-8555-555555555555',
    '9999-12-31',
    null
  ),
  (
    'a3333333-3333-4333-8333-333333333333',
    'Archived notification tenant',
    'notification-tenant-archived',
    '75555555-5555-4555-8555-555555555555',
    '9999-12-31',
    '2026-10-25 00:00:00+00'
  ),
  (
    'a4444444-4444-4444-8444-444444444444',
    'Expired notification tenant',
    'notification-tenant-expired',
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
    'a1111111-1111-4111-8111-111111111111',
    '74444444-4444-4444-8444-444444444444',
    'member',
    false,
    false
  ),
  (
    'a2222222-2222-4222-8222-222222222222',
    '75555555-5555-4555-8555-555555555555',
    'owner',
    true,
    true
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
  ),
  (
    'a2222222-2222-4222-8222-222222222222',
    '75555555-5555-4555-8555-555555555555',
    '85555555-5555-4555-8555-555555555555',
    '95555555-5555-4555-8555-555555555555'
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
    'REMINDER-PARTIAL',
    '2026-10-25 10:00:00+00',
    10,
    'minutes',
    '2026-10-25 10:10:00+00',
    '71111111-1111-4111-8111-111111111111',
    100,
    25
  ),
  (
    'c2222222-2222-4222-8222-222222222222',
    'a1111111-1111-4111-8111-111111111111',
    'REMINDER-PAID',
    '2026-10-25 09:00:00+00',
    1,
    'hours',
    '2026-10-25 10:00:00+00',
    '71111111-1111-4111-8111-111111111111',
    30,
    30
  ),
  (
    'c3333333-3333-4333-8333-333333333333',
    'a2222222-2222-4222-8222-222222222222',
    'REMINDER-OTHER-TENANT',
    '2026-10-25 10:00:00+00',
    10,
    'minutes',
    '2026-10-25 10:10:00+00',
    '75555555-5555-4555-8555-555555555555',
    40,
    0
  ),
  (
    'c4444444-4444-4444-8444-444444444444',
    'a3333333-3333-4333-8333-333333333333',
    'REMINDER-ARCHIVED',
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
    'a4444444-4444-4444-8444-444444444444',
    'REMINDER-TENANT-EXPIRED',
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
    'a1111111-1111-4111-8111-111111111111',
    'REMINDER-NOT-EXPIRED',
    '2026-10-25 10:00:00+00',
    11,
    'minutes',
    '2026-10-25 10:11:00+00',
    '71111111-1111-4111-8111-111111111111',
    40,
    0
  ),
  (
    'c7777777-7777-4777-8777-777777777777',
    'a1111111-1111-4111-8111-111111111111',
    'REMINDER-RECHECK',
    '2026-10-25 09:00:00+00',
    70,
    'minutes',
    '2026-10-25 10:10:00+00',
    '71111111-1111-4111-8111-111111111111',
    50,
    0
  );

create temporary table first_notification_claims on commit drop as
select *
from public.claim_due_parking_notification_events(
  '2026-10-25 10:10:00.250+00'
);

select is(
  (select count(*) from first_notification_claims),
  3::bigint,
  'only expired unpaid sessions in active tenants are claimed'
);
select is(
  (
    select count(*)
    from public.parking_notification_events as notification_event
    where notification_event.notification_type = 'expired'
      and notification_event.session_id in (
        'c1111111-1111-4111-8111-111111111111',
        'c3333333-3333-4333-8333-333333333333',
        'c7777777-7777-4777-8777-777777777777'
      )
  ),
  3::bigint,
  'the initial expiry creates one event row per eligible session'
);
select is(
  (
    select count(*)
    from first_notification_claims
    where idempotency_key is not null
      and attempt_count = 1
  ),
  3::bigint,
  'each claimed reminder interval receives one idempotency key'
);
select is(
  (
    select count(*)
    from public.parking_in_app_notifications
    where session_id = 'c1111111-1111-4111-8111-111111111111'
  ),
  3::bigint,
  'owners and View-eligible members receive one mutable alert each'
);
select is(
  (
    select count(*)
    from public.parking_in_app_notifications
    where recipient_user_id = '74444444-4444-4444-8444-444444444444'
  ),
  0::bigint,
  'members without View permission receive no notification'
);
select is(
  (
    select count(*)
    from public.parking_notification_events
    where session_id in (
      'c2222222-2222-4222-8222-222222222222',
      'c4444444-4444-4444-8444-444444444444',
      'c5555555-5555-4555-8555-555555555555',
      'c6666666-6666-4666-8666-666666666666'
    )
  ),
  0::bigint,
  'paid, archived, expired-tenant, and not-yet-expired sessions are excluded'
);

create temporary table notification_test_ids on commit drop as
select id, session_id, recipient_user_id
from public.parking_in_app_notifications;
grant select on notification_test_ids to authenticated;

select is(
  (
    select recipient_external_ids
    from public.get_parking_notification_dispatch_target(
      (
        select event_id
        from first_notification_claims
        where session_id = 'c1111111-1111-4111-8111-111111111111'
      ),
      (
        select claim_token
        from first_notification_claims
        where session_id = 'c1111111-1111-4111-8111-111111111111'
      ),
      '2026-10-25 10:10:00+00'
    )
  ),
  array[
    '71111111-1111-4111-8111-111111111111'::uuid,
    '72222222-2222-4222-8222-222222222222'::uuid,
    '73333333-3333-4333-8333-333333333333'::uuid
  ],
  'the dispatcher resolves only the current tenant owner and View members'
);

select is(
  (
    select plate_number
    from public.get_parking_notification_dispatch_target(
      (
        select event_id
        from first_notification_claims
        where session_id = 'c1111111-1111-4111-8111-111111111111'
      ),
      (
        select claim_token
        from first_notification_claims
        where session_id = 'c1111111-1111-4111-8111-111111111111'
      ),
      '2026-10-25 10:10:00+00'
    )
  ),
  'REMINDER-PARTIAL',
  'the authorized server dispatch target includes the vehicle registration'
);

select is(
  (
    select recipient_external_ids
    from public.get_parking_notification_dispatch_target(
      (
        select event_id
        from first_notification_claims
        where session_id = 'c3333333-3333-4333-8333-333333333333'
      ),
      (
        select claim_token
        from first_notification_claims
        where session_id = 'c3333333-3333-4333-8333-333333333333'
      ),
      '2026-10-25 10:10:00+00'
    )
  ),
  array['75555555-5555-4555-8555-555555555555'::uuid],
  'the dispatcher never targets another tenant''s members'
);

select is(
  public.complete_parking_notification_dispatch(
    (
      select event_id
      from first_notification_claims
      where session_id = 'c3333333-3333-4333-8333-333333333333'
    ),
    (
      select claim_token
      from first_notification_claims
      where session_id = 'c3333333-3333-4333-8333-333333333333'
    ),
    false,
    503,
    null,
    'upstream_5xx',
    null,
    '2026-10-25 10:10:03+00'
  ),
  true,
  'a transient failure preserves the claimed event for a bounded retry'
);

select is(
  public.complete_parking_notification_dispatch(
    (
      select event_id
      from first_notification_claims
      where session_id = 'c1111111-1111-4111-8111-111111111111'
    ),
    (
      select claim_token
      from first_notification_claims
      where session_id = 'c1111111-1111-4111-8111-111111111111'
    ),
    true,
    200,
    '55555555-5555-4555-8555-555555555555',
    null,
    null,
    '2026-10-25 10:10:03+00'
  ),
  true,
  'a successful push anchors the next interval to the scheduler claim'
);
select is(
  (
    select notification_event.next_reminder_at
    from public.parking_notification_events as notification_event
    where notification_event.session_id =
      'c1111111-1111-4111-8111-111111111111'
      and notification_event.notification_type = 'expired'
  ),
  '2026-10-25 10:15:00+00'::timestamptz,
  'a delayed send completion does not drift the five-minute reminder schedule'
);

update public.parking_sessions
set paid_amount = total_charge
where id = 'c7777777-7777-4777-8777-777777777777';
select is(
  (
    select count(*)
    from public.get_parking_notification_dispatch_target(
      (
        select event_id
        from first_notification_claims
        where session_id = 'c7777777-7777-4777-8777-777777777777'
      ),
      (
        select claim_token
        from first_notification_claims
        where session_id = 'c7777777-7777-4777-8777-777777777777'
      ),
      '2026-10-25 10:10:01+00'
    )
  ),
  0::bigint,
  'the dispatch target rechecks balance and skips a session paid after claim'
);
select is(
  (
    select dispatch_status
    from public.parking_notification_events
    where session_id = 'c7777777-7777-4777-8777-777777777777'
      and notification_type = 'expired'
  ),
  'resolved',
  'a fully paid session is resolved before a push is sent'
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
select is(
  (
    select count(*)
    from public.parking_in_app_notifications
  ),
  1::bigint,
  'RLS exposes only the current users active notification'
);
select ok(
  not exists (
    select 1
    from public.parking_in_app_notifications
    where session_id = 'c3333333-3333-4333-8333-333333333333'
  ),
  'RLS hides notifications for sessions in another tenant'
);
select is(
  public.mark_all_parking_in_app_notifications_read(
    'a1111111-1111-4111-8111-111111111111'
  ),
  1,
  'a user can clear all unread notifications in the selected tenant'
);
select is(
  (
    select count(*)
    from public.parking_in_app_notifications
    where read_at is null
  ),
  0::bigint,
  'clearing all marks the current user''s visible alerts as read'
);
select is(
  public.mark_parking_in_app_notification_read(
    (
      select id
      from notification_test_ids
      where session_id = 'c1111111-1111-4111-8111-111111111111'
        and recipient_user_id = '71111111-1111-4111-8111-111111111111'
    )
  ),
  true,
  'a notification recipient can mark their own alert read'
);
select is(
  public.mark_parking_in_app_notification_read(
    (
      select id
      from notification_test_ids
      where session_id = 'c1111111-1111-4111-8111-111111111111'
        and recipient_user_id = '72222222-2222-4222-8222-222222222222'
    )
  ),
  false,
  'a user cannot mark another recipients alert read'
);
select throws_ok(
  $$update public.parking_in_app_notifications
    set read_at = null
    where recipient_user_id = '71111111-1111-4111-8111-111111111111'$$,
  '42501',
  null,
  'authenticated clients cannot directly update notification state'
);
reset role;

select is(
  (
    select count(*)
    from public.parking_in_app_notifications
    where session_id = 'c1111111-1111-4111-8111-111111111111'
      and recipient_user_id = '72222222-2222-4222-8222-222222222222'
      and read_at is null
  ),
  1::bigint,
  'clearing all does not change another authorized recipient''s alerts'
);

select is(
  (
    select count(*)
    from public.claim_due_parking_notification_events(
      '2026-10-25 10:14:59+00'
    )
  ),
  0::bigint,
  'the scheduler does not repeat a reminder before five minutes'
);
create temporary table repeated_notification_claims on commit drop as
select *
from public.claim_due_parking_notification_events(
  '2026-10-25 10:15:00+00'
);
select is(
  (select count(*) from repeated_notification_claims),
  2::bigint,
  'partial payment and a due retry remain eligible at the next interval'
);
select is(
  (
    select count(distinct event_id)
    from repeated_notification_claims
  ),
  2::bigint,
  'each due reminder reuses its original event row'
);
select is(
  (
    select idempotency_key
    from repeated_notification_claims
    where session_id = 'c3333333-3333-4333-8333-333333333333'
  ),
  (
    select idempotency_key
    from first_notification_claims
    where session_id = 'c3333333-3333-4333-8333-333333333333'
  ),
  'a retry reuses the same OneSignal idempotency key'
);
select is(
  (
    select count(*)
    from public.parking_in_app_notifications
    where session_id = 'c1111111-1111-4111-8111-111111111111'
  ),
  3::bigint,
  'repeated reminders update the same per-recipient alert rows'
);
select is(
  (
    select count(*)
    from public.parking_in_app_notifications
    where session_id = 'c1111111-1111-4111-8111-111111111111'
      and read_at is null
  ),
  3::bigint,
  'a new reminder interval reopens previously read alerts'
);
select is(
  (
    select count(*)
    from public.claim_due_parking_notification_events(
      '2026-10-25 10:15:00+00'
    )
  ),
  0::bigint,
  'a repeated or overlapping claim does not duplicate a sending interval'
);

select is(
  public.complete_parking_notification_dispatch(
    (
      select event_id
      from repeated_notification_claims
      where session_id = 'c1111111-1111-4111-8111-111111111111'
    ),
    (
      select claim_token
      from repeated_notification_claims
      where session_id = 'c1111111-1111-4111-8111-111111111111'
    ),
    true,
    200,
    '66666666-6666-4666-8666-666666666666',
    null,
    null,
    '2026-10-25 10:15:00+00'
  ),
  true,
  'the next reminder interval can be completed successfully'
);

select is(
  public.complete_parking_notification_dispatch(
    (
      select event_id
      from repeated_notification_claims
      where session_id = 'c3333333-3333-4333-8333-333333333333'
    ),
    (
      select claim_token
      from repeated_notification_claims
      where session_id = 'c3333333-3333-4333-8333-333333333333'
    ),
    true,
    200,
    '77777777-7777-4777-8777-777777777777',
    null,
    null,
    '2026-10-25 10:15:00+00'
  ),
  true,
  'a retry can succeed without creating another event row'
);

update public.parking_sessions
set paid_amount = total_charge
where id = 'c3333333-3333-4333-8333-333333333333';

update public.parking_sessions
set paid_amount = total_charge
where id = 'c1111111-1111-4111-8111-111111111111';
select is(
  (
    select count(*)
    from public.claim_due_parking_notification_events(
      '2026-10-25 10:20:00+00'
    )
  ),
  0::bigint,
  'fully paid sessions receive no further reminders'
);
select is(
  (
    select count(*)
    from public.parking_notification_events
    where session_id = 'c1111111-1111-4111-8111-111111111111'
      and dispatch_status = 'resolved'
  ),
  1::bigint,
  'full payment resolves the session dispatch state'
);
select is(
  (
    select count(*)
    from public.parking_in_app_notifications
    where session_id = 'c1111111-1111-4111-8111-111111111111'
      and resolved_at is not null
  ),
  3::bigint,
  'full payment resolves every in-app alert for the session'
);

update public.parking_sessions
set paid_amount = 40
where id = 'c1111111-1111-4111-8111-111111111111';
create temporary table reversal_notification_claims on commit drop as
select *
from public.claim_due_parking_notification_events(
  '2026-10-25 10:25:00+00'
);
select is(
  (select count(*) from reversal_notification_claims),
  1::bigint,
  'a payment reversal resumes reminders for the still-expired session'
);
select is(
  (
    select count(*)
    from public.parking_in_app_notifications
    where session_id = 'c1111111-1111-4111-8111-111111111111'
      and resolved_at is null
      and read_at is null
  ),
  3::bigint,
  'a payment reversal reactivates the existing unread alert rows'
);
select is(
  (
    select count(*)
    from (
      select id
      from public.parking_notification_events
      where session_id = 'c1111111-1111-4111-8111-111111111111'
        and notification_type = 'expired'
      group by id
    ) as session_events
  ),
  1::bigint,
  'payment changes never create duplicate event-history rows'
);

select is(
  (
    select count(*)
    from cron.job
    where jobname = 'parking-notification-dispatch'
      and schedule = '*/5 * * * *'
  ),
  1::bigint,
  'exactly one five-minute notification scheduler is configured'
);
select is(
  (
    select count(*)
    from cron.job
    where jobname = 'parking-push-dispatch'
  ),
  0::bigint,
  'the former Web Push scheduler is no longer active'
);
select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and indexname = 'parking_notification_events_dispatch_due_idx'
  ),
  'a partial index supports bounded dispatch claims'
);
select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and indexname = 'parking_in_app_notifications_active_recipient_idx'
  ),
  'an index supports recipient-scoped active alert reads'
);

select * from finish();
rollback;
