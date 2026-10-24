begin;

alter table public.parking_notification_events
  add column dispatch_status text not null default 'pending',
  add column next_reminder_at timestamptz,
  add column next_attempt_at timestamptz,
  add column attempt_count smallint not null default 0,
  add column claim_token uuid,
  add column claimed_at timestamptz,
  add column last_attempt_at timestamptz,
  add column last_sent_at timestamptz,
  add column idempotency_key uuid,
  add column last_http_status integer,
  add column last_error_code text,
  add column last_message_id text,
  add constraint parking_notification_events_dispatch_status_check
    check (
      dispatch_status in ('pending', 'sending', 'sent', 'failed', 'resolved')
    ),
  add constraint parking_notification_events_attempt_count_check
    check (attempt_count between 0 and 3),
  add constraint parking_notification_events_http_status_check
    check (last_http_status is null or last_http_status between 100 and 599);

with last_vapid_delivery as (
  select
    delivery.event_id,
    max(coalesce(delivery.delivered_at, delivery.attempted_at)) as sent_at
  from public.parking_notification_deliveries as delivery
  where delivery.status = 'sent'
  group by delivery.event_id
)
update public.parking_notification_events as notification_event
set
  dispatch_status = 'sent',
  last_sent_at = last_vapid_delivery.sent_at,
  next_reminder_at = last_vapid_delivery.sent_at + interval '5 minutes'
from last_vapid_delivery
where notification_event.id = last_vapid_delivery.event_id
  and notification_event.notification_type = 'expired';

update public.parking_notification_events as notification_event
set next_reminder_at = notification_event.due_at
where notification_event.notification_type = 'expired'
  and notification_event.next_reminder_at is null;

create index parking_notification_events_dispatch_due_idx
  on public.parking_notification_events (
    next_attempt_at,
    next_reminder_at,
    id
  )
  where notification_type = 'expired'
    and dispatch_status in ('pending', 'sent', 'failed');

create index parking_sessions_expired_unpaid_idx
  on public.parking_sessions (expires_at, tenant_id, id)
  where total_charge > paid_amount;

create table public.parking_in_app_notifications (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  tenant_id uuid not null
    references public.tenants(id) on delete cascade,
  recipient_user_id uuid not null
    references auth.users(id) on delete cascade,
  session_id uuid not null
    references public.parking_sessions(id) on delete cascade,
  notification_type text not null default 'expired',
  created_at timestamptz not null default pg_catalog.now(),
  last_reminded_at timestamptz not null,
  reminder_interval_at timestamptz not null,
  read_at timestamptz,
  resolved_at timestamptz,
  constraint parking_in_app_notifications_type_check
    check (notification_type = 'expired'),
  constraint parking_in_app_notifications_recipient_session_type_key
    unique (session_id, recipient_user_id, notification_type)
);

create index parking_in_app_notifications_active_recipient_idx
  on public.parking_in_app_notifications (
    tenant_id,
    recipient_user_id,
    last_reminded_at desc,
    id
  )
  where resolved_at is null;

alter table public.parking_in_app_notifications enable row level security;
revoke all on table public.parking_in_app_notifications
  from public, anon, authenticated;
grant select on table public.parking_in_app_notifications to authenticated;
grant all on table public.parking_in_app_notifications to service_role;

create policy "Recipients can view authorized active parking notifications"
on public.parking_in_app_notifications
for select
to authenticated
using (
  recipient_user_id = (select auth.uid())
  and resolved_at is null
  and public.can_view_tenant_entries(tenant_id)
);

drop policy if exists "Users manage their own push subscriptions"
  on public.parking_push_subscriptions;
revoke all on table public.parking_push_subscriptions
  from public, anon, authenticated;

drop function if exists public.register_parking_push_subscription(
  text, text, text, text
);
drop function if exists public.claim_due_parking_notification_deliveries(
  timestamptz
);
drop function if exists public.mark_parking_session_fully_paid(uuid);

create or replace function public.mark_parking_in_app_notification_read(
  p_notification_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_updated_count integer;
begin
  if v_user_id is null then
    raise exception using
      errcode = '28000',
      message = 'An authenticated user is required.';
  end if;

  if p_notification_id is null then
    raise exception using
      errcode = '22023',
      message = 'A parking notification id is required.';
  end if;

  update public.parking_in_app_notifications as notification
  set read_at = coalesce(notification.read_at, pg_catalog.now())
  where notification.id = p_notification_id
    and notification.recipient_user_id = v_user_id
    and notification.resolved_at is null
    and public.can_view_tenant_entries(notification.tenant_id);

  get diagnostics v_updated_count = row_count;
  return v_updated_count > 0;
end;
$$;

revoke all on function public.mark_parking_in_app_notification_read(uuid)
  from public, anon;
grant execute on function public.mark_parking_in_app_notification_read(uuid)
  to authenticated;

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
  on conflict (session_id, notification_type) do nothing;

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

create or replace function public.get_parking_notification_dispatch_target(
  p_event_id uuid,
  p_claim_token uuid,
  p_now timestamptz default pg_catalog.now()
)
returns table (
  event_id uuid,
  session_id uuid,
  tenant_id uuid,
  idempotency_key uuid,
  recipient_external_ids uuid[]
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session_id uuid;
  v_tenant_id uuid;
  v_recipient_ids uuid[];
begin
  if p_event_id is null or p_claim_token is null or p_now is null then
    raise exception using
      errcode = '22023',
      message = 'A valid notification claim is required.';
  end if;

  select session.id, session.tenant_id
  into v_session_id, v_tenant_id
  from public.parking_notification_events as notification_event
  join public.parking_sessions as session
    on session.id = notification_event.session_id
  where notification_event.id = p_event_id
    and notification_event.notification_type = 'expired'
    and notification_event.dispatch_status = 'sending'
    and notification_event.claim_token = p_claim_token
  for update of notification_event;

  if v_session_id is null then
    return;
  end if;

  if not exists (
    select 1
    from public.parking_sessions as session
    join public.tenants as tenant on tenant.id = session.tenant_id
    where session.id = v_session_id
      and session.expires_at <= p_now
      and session.expires_at > session.entry_time
      and session.total_charge > session.paid_amount
      and tenant.archived_at is null
      and tenant.valid_until >=
        (p_now at time zone 'Asia/Kolkata')::date
  ) then
    update public.parking_notification_events as notification_event
    set
      dispatch_status = 'resolved',
      claim_token = null,
      claimed_at = null,
      next_attempt_at = null,
      idempotency_key = null,
      attempt_count = 0,
      last_error_code = null
    where notification_event.id = p_event_id
      and notification_event.claim_token = p_claim_token;

    update public.parking_in_app_notifications as notification
    set resolved_at = p_now
    where notification.session_id = v_session_id
      and notification.resolved_at is null;

    return;
  end if;

  select pg_catalog.array_agg(
    distinct membership.user_id order by membership.user_id
  )
  into v_recipient_ids
  from public.tenant_memberships as membership
  where membership.tenant_id = v_tenant_id
    and (membership.role = 'owner' or membership.can_view_entries);

  if v_recipient_ids is null or pg_catalog.cardinality(v_recipient_ids) = 0 then
    update public.parking_notification_events as notification_event
    set
      dispatch_status = 'pending',
      claim_token = null,
      claimed_at = null,
      next_attempt_at = null,
      last_error_code = 'no_authorized_recipients'
    where notification_event.id = p_event_id
      and notification_event.claim_token = p_claim_token;

    update public.parking_in_app_notifications as notification
    set resolved_at = p_now
    where notification.session_id = v_session_id
      and notification.resolved_at is null
      and not exists (
        select 1
        from public.tenant_memberships as membership
        where membership.tenant_id = notification.tenant_id
          and membership.user_id = notification.recipient_user_id
          and (membership.role = 'owner' or membership.can_view_entries)
      );

    return;
  end if;

  return query
  select
    notification_event.id,
    notification_event.session_id,
    v_tenant_id,
    notification_event.idempotency_key,
    v_recipient_ids
  from public.parking_notification_events as notification_event
  where notification_event.id = p_event_id
    and notification_event.dispatch_status = 'sending'
    and notification_event.claim_token = p_claim_token;
end;
$$;

revoke all on function public.get_parking_notification_dispatch_target(
  uuid, uuid, timestamptz
) from public, anon, authenticated;
grant execute on function public.get_parking_notification_dispatch_target(
  uuid, uuid, timestamptz
) to service_role;

create or replace function public.complete_parking_notification_dispatch(
  p_event_id uuid,
  p_claim_token uuid,
  p_delivered boolean,
  p_http_status integer,
  p_message_id text,
  p_error_code text,
  p_retry_after timestamptz,
  p_now timestamptz default pg_catalog.now()
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempt_count smallint;
  v_updated_count integer;
  v_message_id text;
begin
  if p_event_id is null
    or p_claim_token is null
    or p_delivered is null
    or p_now is null
    or (p_http_status is not null and p_http_status not between 100 and 599)
  then
    raise exception using
      errcode = '22023',
      message = 'The notification result is invalid.';
  end if;

  if p_delivered and (p_http_status is null or p_http_status not between 200 and 299) then
    raise exception using
      errcode = '22023',
      message = 'A successful notification requires a successful HTTP status.';
  end if;

  select notification_event.attempt_count
  into v_attempt_count
  from public.parking_notification_events as notification_event
  where notification_event.id = p_event_id
    and notification_event.notification_type = 'expired'
    and notification_event.dispatch_status = 'sending'
    and notification_event.claim_token = p_claim_token
  for update;

  if v_attempt_count is null then
    return false;
  end if;

  v_message_id := case
    when p_message_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      then p_message_id
    else null
  end;

  update public.parking_notification_events as notification_event
  set
    dispatch_status = case when p_delivered then 'sent' else 'failed' end,
    claim_token = null,
    claimed_at = null,
    last_http_status = p_http_status,
    last_error_code = case
      when p_delivered then null
      when p_error_code in (
        'rate_limited',
        'upstream_5xx',
        'upstream_4xx',
        'invalid_response',
        'network_error',
        'recipient_limit',
        'configuration_error',
        'delivery_failed'
      ) then p_error_code
      else 'delivery_failed'
    end,
    last_message_id = case when p_delivered then v_message_id else null end,
    last_sent_at = case
      when p_delivered then p_now
      else notification_event.last_sent_at
    end,
    next_reminder_at = case
      when p_delivered or v_attempt_count >= 3
        then p_now + interval '5 minutes'
      else notification_event.next_reminder_at
    end,
    next_attempt_at = case
      when p_delivered or v_attempt_count >= 3 then null
      else greatest(
        coalesce(p_retry_after, p_now),
        p_now + interval '5 minutes'
      )
    end
  where notification_event.id = p_event_id
    and notification_event.dispatch_status = 'sending'
    and notification_event.claim_token = p_claim_token;

  get diagnostics v_updated_count = row_count;
  return v_updated_count > 0;
end;
$$;

revoke all on function public.complete_parking_notification_dispatch(
  uuid, uuid, boolean, integer, text, text, timestamptz, timestamptz
) from public, anon, authenticated;
grant execute on function public.complete_parking_notification_dispatch(
  uuid, uuid, boolean, integer, text, text, timestamptz, timestamptz
) to service_role;

do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select job.jobid
    from cron.job as job
    where job.jobname in (
      'parking-push-dispatch',
      'parking-notification-dispatch'
    )
  loop
    perform cron.unschedule(v_job_id);
  end loop;
end;
$$;

select cron.schedule(
  'parking-notification-dispatch',
  '*/5 * * * *',
  $cron$
    select net.http_post(
      url := project_url.decrypted_secret
        || '/functions/v1/dispatch-parking-notifications',
      headers := jsonb_build_object(
        'Content-Type',
        'application/json',
        'x-parking-notification-secret',
        cron_secret.decrypted_secret
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 45000
    )
    from vault.decrypted_secrets as project_url
    cross join vault.decrypted_secrets as cron_secret
    where project_url.name = 'parking_notifications_project_url'
      and cron_secret.name = 'parking_notifications_cron_secret';
  $cron$
);

commit;
