begin;

create or replace function public.claim_due_parking_notification_events(
  p_now timestamptz default pg_catalog.now()
)
returns table (
  event_id uuid,
  session_id uuid,
  tenant_id uuid,
  claim_token uuid,
  idempotency_key uuid,
  attempt_count smallint
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_now is null then
    raise exception using
      errcode = '22023',
      message = 'The notification claim time is required.';
  end if;

  update public.parking_notification_events as notification_event
  set
    dispatch_status = 'failed',
    claim_token = null,
    claimed_at = null,
    next_attempt_at = p_now,
    last_error_code = 'dispatch_interrupted'
  where notification_event.notification_type = 'expired'
    and notification_event.dispatch_status = 'sending'
    and notification_event.claimed_at < p_now - interval '10 minutes';

  update public.parking_in_app_notifications as notification
  set resolved_at = p_now
  from public.parking_sessions as session
  join public.tenants as tenant on tenant.id = session.tenant_id
  where notification.session_id = session.id
    and notification.tenant_id = session.tenant_id
    and notification.resolved_at is null
    and (
      session.expires_at > p_now
      or session.expires_at <= session.entry_time
      or session.total_charge <= session.paid_amount
      or tenant.archived_at is not null
      or tenant.valid_until <
        (p_now at time zone 'Asia/Kolkata')::date
      or not exists (
        select 1
        from public.tenant_memberships as membership
        where membership.tenant_id = notification.tenant_id
          and membership.user_id = notification.recipient_user_id
          and (membership.role = 'owner' or membership.can_view_entries)
      )
    );

  update public.parking_notification_events as notification_event
  set
    dispatch_status = 'resolved',
    claim_token = null,
    claimed_at = null,
    next_attempt_at = null,
    idempotency_key = null,
    attempt_count = 0,
    last_error_code = null
  from public.parking_sessions as session
  join public.tenants as tenant on tenant.id = session.tenant_id
  where notification_event.session_id = session.id
    and notification_event.notification_type = 'expired'
    and notification_event.dispatch_status <> 'resolved'
    and (
      session.expires_at > p_now
      or session.expires_at <= session.entry_time
      or session.total_charge <= session.paid_amount
      or tenant.archived_at is not null
      or tenant.valid_until <
        (p_now at time zone 'Asia/Kolkata')::date
    );

  update public.parking_notification_events as notification_event
  set
    dispatch_status = 'pending',
    next_reminder_at = p_now,
    next_attempt_at = null,
    attempt_count = 0,
    claim_token = null,
    claimed_at = null,
    idempotency_key = null,
    last_http_status = null,
    last_error_code = null,
    last_message_id = null
  from public.parking_sessions as session
  join public.tenants as tenant on tenant.id = session.tenant_id
  where notification_event.session_id = session.id
    and notification_event.notification_type = 'expired'
    and notification_event.dispatch_status = 'resolved'
    and session.expires_at <= p_now
    and session.expires_at > session.entry_time
    and session.total_charge > session.paid_amount
    and tenant.archived_at is null
    and tenant.valid_until >=
      (p_now at time zone 'Asia/Kolkata')::date;

  insert into public.parking_notification_events (
    session_id,
    notification_type,
    due_at,
    next_reminder_at
  )
  select
    session.id,
    'expired',
    session.expires_at,
    session.expires_at
  from public.parking_sessions as session
  join public.tenants as tenant on tenant.id = session.tenant_id
  where session.expires_at <= p_now
    and session.expires_at > session.entry_time
    and session.total_charge > session.paid_amount
    and tenant.archived_at is null
    and tenant.valid_until >=
      (p_now at time zone 'Asia/Kolkata')::date
  on conflict on constraint parking_notification_events_session_type_key
    do nothing;

  return query
  with due_events as (
    select
      notification_event.id,
      notification_event.session_id,
      session.tenant_id,
      notification_event.dispatch_status = 'failed'
        and notification_event.attempt_count < 3 as is_retry
    from public.parking_notification_events as notification_event
    join public.parking_sessions as session
      on session.id = notification_event.session_id
    join public.tenants as tenant
      on tenant.id = session.tenant_id
    where notification_event.notification_type = 'expired'
      and session.expires_at <= p_now
      and session.expires_at > session.entry_time
      and session.total_charge > session.paid_amount
      and tenant.archived_at is null
      and tenant.valid_until >=
        (p_now at time zone 'Asia/Kolkata')::date
      and (
        (
          notification_event.dispatch_status in ('pending', 'sent')
          and notification_event.next_reminder_at <= p_now
        )
        or (
          notification_event.dispatch_status = 'failed'
          and notification_event.attempt_count < 3
          and coalesce(
            notification_event.next_attempt_at,
            notification_event.next_reminder_at
          ) <= p_now
        )
        or (
          notification_event.dispatch_status = 'failed'
          and notification_event.attempt_count >= 3
          and notification_event.next_reminder_at <= p_now
        )
      )
      and exists (
        select 1
        from public.tenant_memberships as membership
        where membership.tenant_id = session.tenant_id
          and (membership.role = 'owner' or membership.can_view_entries)
      )
    order by
      coalesce(
        notification_event.next_attempt_at,
        notification_event.next_reminder_at
      ),
      notification_event.id
    limit 20
    for update of notification_event skip locked
  ),
  claimed_events as (
    update public.parking_notification_events as notification_event
    set
      dispatch_status = 'sending',
      claim_token = pg_catalog.gen_random_uuid(),
      claimed_at = p_now,
      last_attempt_at = p_now,
      idempotency_key = case
        when due_events.is_retry then notification_event.idempotency_key
        else pg_catalog.gen_random_uuid()
      end,
      attempt_count = case
        when due_events.is_retry then notification_event.attempt_count + 1
        else 1
      end,
      next_attempt_at = null,
      last_http_status = null,
      last_error_code = null,
      last_message_id = null
    from due_events
    where notification_event.id = due_events.id
    returning
      notification_event.id,
      notification_event.session_id,
      due_events.tenant_id,
      notification_event.next_reminder_at,
      notification_event.claim_token,
      notification_event.idempotency_key,
      notification_event.attempt_count
  ),
  upserted_notifications as (
    insert into public.parking_in_app_notifications as existing_notification (
      tenant_id,
      recipient_user_id,
      session_id,
      notification_type,
      created_at,
      last_reminded_at,
      reminder_interval_at
    )
    select
      claimed_event.tenant_id,
      membership.user_id,
      claimed_event.session_id,
      'expired',
      p_now,
      p_now,
      claimed_event.next_reminder_at
    from claimed_events as claimed_event
    join public.tenant_memberships as membership
      on membership.tenant_id = claimed_event.tenant_id
     and (membership.role = 'owner' or membership.can_view_entries)
    on conflict on constraint
      parking_in_app_notifications_recipient_session_type_key
    do update
    set
      last_reminded_at = case
        when existing_notification.resolved_at is not null
          or existing_notification.reminder_interval_at
            is distinct from excluded.reminder_interval_at
          then excluded.last_reminded_at
        else existing_notification.last_reminded_at
      end,
      reminder_interval_at = excluded.reminder_interval_at,
      read_at = case
        when existing_notification.resolved_at is not null
          or existing_notification.reminder_interval_at
            is distinct from excluded.reminder_interval_at
          then null
        else existing_notification.read_at
      end,
      resolved_at = null
    returning existing_notification.id
  )
  select
    claimed_event.id,
    claimed_event.session_id,
    claimed_event.tenant_id,
    claimed_event.claim_token,
    claimed_event.idempotency_key,
    claimed_event.attempt_count
  from claimed_events as claimed_event;
end;
$$;

revoke all on function public.claim_due_parking_notification_events(
  timestamptz
) from public, anon, authenticated;
grant execute on function public.claim_due_parking_notification_events(
  timestamptz
) to service_role;

commit;
