begin;

create index parking_notification_deliveries_repeat_sent_idx
  on public.parking_notification_deliveries (delivered_at, event_id)
  where status = 'sent';

create index parking_notification_deliveries_repeat_failed_idx
  on public.parking_notification_deliveries (attempted_at, event_id)
  where status = 'failed';

create or replace function public.claim_due_parking_notification_deliveries(
  p_now timestamptz default pg_catalog.now()
)
returns table (
  delivery_id uuid,
  subscription_id uuid,
  session_id uuid,
  tenant_id uuid,
  notification_type text,
  endpoint text,
  p256dh_key text,
  auth_key text,
  locale text,
  can_mark_paid boolean,
  remaining_balance numeric
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

  update public.parking_notification_deliveries as delivery
  set
    status = 'failed',
    error_code = 'dispatch_interrupted'
  where delivery.status = 'sending'
    and delivery.attempted_at < p_now - interval '10 minutes';

  update public.parking_notification_deliveries as delivery
  set
    status = 'pending',
    error_code = null
  from public.parking_notification_events as notification_event,
       public.parking_sessions as session
  where delivery.event_id = notification_event.id
    and session.id = notification_event.session_id
    and notification_event.notification_type = 'expired'
    and session.total_charge > session.paid_amount
    and (
      (
        delivery.status = 'sent'
        and delivery.delivered_at <= p_now - interval '5 minutes'
      )
      or (
        delivery.status = 'failed'
        and delivery.attempted_at <= p_now - interval '5 minutes'
      )
    );

  with due_events as (
    select
      session.id as session_id,
      'ninety_percent'::text as notification_type,
      session.entry_time
        + (session.expires_at - session.entry_time) * 0.9 as due_at
    from public.parking_sessions as session
    join public.tenants as tenant on tenant.id = session.tenant_id
    where session.expires_at > session.entry_time
      and session.total_charge > session.paid_amount
      and tenant.archived_at is null
      and tenant.valid_until >=
        (p_now at time zone 'Asia/Kolkata')::date
      and p_now >= session.entry_time
        + (session.expires_at - session.entry_time) * 0.9
      and p_now < session.expires_at

    union all

    select
      session.id as session_id,
      'expired'::text as notification_type,
      session.expires_at as due_at
    from public.parking_sessions as session
    join public.tenants as tenant on tenant.id = session.tenant_id
    where session.expires_at > session.entry_time
      and session.total_charge > session.paid_amount
      and tenant.archived_at is null
      and tenant.valid_until >=
        (p_now at time zone 'Asia/Kolkata')::date
      and p_now >= session.expires_at
  ),
  inserted_events as (
    insert into public.parking_notification_events as inserted_event (
      session_id,
      notification_type,
      due_at
    )
    select
      due_events.session_id,
      due_events.notification_type,
      due_events.due_at
    from due_events
    on conflict on constraint parking_notification_events_session_type_key
      do nothing
    returning inserted_event.id, inserted_event.session_id
  )
  insert into public.parking_notification_deliveries (
    event_id,
    subscription_id
  )
  select
    inserted_events.id,
    subscription.id
  from inserted_events
  join public.parking_sessions as session
    on session.id = inserted_events.session_id
  join public.tenants as tenant
    on tenant.id = session.tenant_id
   and tenant.archived_at is null
   and tenant.valid_until >=
     (p_now at time zone 'Asia/Kolkata')::date
  join public.tenant_memberships as membership
    on membership.tenant_id = session.tenant_id
   and (membership.role = 'owner' or membership.can_view_entries)
  join public.parking_push_subscriptions as subscription
    on subscription.user_id = membership.user_id
  on conflict on constraint parking_notification_deliveries_event_subscription_key
    do nothing;

  update public.parking_notification_deliveries as delivery
  set
    status = 'skipped',
    error_code = 'notification_no_longer_eligible'
  from public.parking_notification_events as notification_event,
       public.parking_sessions as session,
       public.parking_push_subscriptions as subscription,
       public.tenants as tenant
  where delivery.event_id = notification_event.id
    and session.id = notification_event.session_id
    and subscription.id = delivery.subscription_id
    and tenant.id = session.tenant_id
    and delivery.status = 'pending'
    and (
      session.total_charge <= session.paid_amount
      or tenant.archived_at is not null
      or tenant.valid_until <
        (p_now at time zone 'Asia/Kolkata')::date
      or not exists (
        select 1
        from public.tenant_memberships as membership
        where membership.tenant_id = session.tenant_id
          and membership.user_id = subscription.user_id
          and (membership.role = 'owner' or membership.can_view_entries)
      )
    );

  return query
  with eligible_deliveries as (
    select
      delivery.id as delivery_id,
      subscription.id as subscription_id,
      session.id as session_id,
      session.tenant_id,
      notification_event.notification_type,
      subscription.endpoint,
      subscription.p256dh_key,
      subscription.auth_key,
      subscription.locale,
      (membership.role = 'owner' or membership.can_edit_entries)
        as can_mark_paid,
      session.total_charge - session.paid_amount as remaining_balance,
      notification_event.due_at
    from public.parking_notification_deliveries as delivery
    join public.parking_notification_events as notification_event
      on notification_event.id = delivery.event_id
    join public.parking_sessions as session
      on session.id = notification_event.session_id
    join public.tenants as tenant
      on tenant.id = session.tenant_id
    join public.parking_push_subscriptions as subscription
      on subscription.id = delivery.subscription_id
    join public.tenant_memberships as membership
      on membership.tenant_id = session.tenant_id
     and membership.user_id = subscription.user_id
     and (membership.role = 'owner' or membership.can_view_entries)
    where delivery.status = 'pending'
      and session.total_charge > session.paid_amount
      and tenant.archived_at is null
      and tenant.valid_until >=
        (p_now at time zone 'Asia/Kolkata')::date
    order by notification_event.due_at, delivery.id
    for update of delivery skip locked
    limit 200
  ),
  claimed_deliveries as (
    update public.parking_notification_deliveries as delivery
    set
      status = 'sending',
      attempted_at = p_now
    from eligible_deliveries as eligible
    where delivery.id = eligible.delivery_id
    returning delivery.id
  )
  select
    eligible.delivery_id,
    eligible.subscription_id,
    eligible.session_id,
    eligible.tenant_id,
    eligible.notification_type,
    eligible.endpoint,
    eligible.p256dh_key,
    eligible.auth_key,
    eligible.locale,
    eligible.can_mark_paid,
    eligible.remaining_balance
  from eligible_deliveries as eligible
  join claimed_deliveries
    on claimed_deliveries.id = eligible.delivery_id;
end;
$$;

revoke all on function public.claim_due_parking_notification_deliveries(
  timestamptz
) from public, anon, authenticated;
grant execute on function public.claim_due_parking_notification_deliveries(
  timestamptz
) to service_role;

commit;
